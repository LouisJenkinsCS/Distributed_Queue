use CyclicDist;
use LocalAtomicObject;
use Queue;
use SyncQueue;
use Random;

/*
  A distributed FIFO queue.

  The queue makes use of a counter to cycle and to properly load-balance across
  all registered locales, where each locale has a per-locale queue. The per-locale
  queue further ensures a FIFO ordering, ensuring that any extra items enqueued
  after cycling through can be dequeued in the same order. This is because a FIFO
  of FIFOs is still a FIFO. For a useful diagram...

  Imagine there are N locales, where we denote a head at position Y as H_Y and a
  tail at position Z as T_Z.

  The Queue is empty:
    H_0, T_0 -- Note that the position just needs to be the same...

    In this case, if the head and tail are equal, then a dequeue will fail if it was read
    as such at the time, but an enqueue would be able to advance the tail.

  Enqueue:
    H_0, T_1

    In this case, the locale at position 0 mod N would end up with an enqueue.

  Dequeue:

    H_1, T_1

    There are two things that can happen: T_0 has not yet finished being enqueued,
    upon which it will spin until it has finished (I.E: by repeatedly attempting to dequeue
    if it is non-blocking), or it has finished, upon which will do a simple dequeue.
    Notice as well that while both Enqueue and Dequeue can be in progress, other tasks
    can advance the head and tail to obtain their next index. Overlapping operations are
    discussed below.

  The position can be obtained and updated in a non-blocking fashion, using the
  available atomic primitives such as Compare-And-Swap, of which is the only global
  synchronization actually needed. Since the only global synchronization is non-blocking,
  lock-free, and wait-free, this ensures scalability. To reduce communication as well,
  we perform atomically updating and obtaining the index on the locale owning the queue.
  The head and tail of the global counter denotes a sort of 'promise' that a task will,
  on enqueue add a new item, and on dequeue remove an existing item. Given that the global counter
  is linearizable, we know that the index obtained from the current counter is correct at the time
  it was retrieved, and enforcing that all tasks uphold such a promise will ensure it always remains
  correct.

  As each per-locale queue is updated on the locale it belongs to, meaning majority
  of the computation can be performed remotely, it ensures that the workload is very
  well balanced. In the cases of overlapping operations on a local queue, a non-blocking
  queue is the most optimal, as this would allow enqueues to be fully non-blocking and
  lock-free, as the counter is proven non-blocking, lock-free, and wait-free.
  While enqueues can be non-blocking (depending on queue implementation), a dequeues
  cannot be as it is possible for an enqueue to 'promise' but not finish before another
  dequeue on that node occurs. Due to this, a dequeue would need to spin as the index
  assigned to it is correct and that *one* of the enqueuers for that index has not completed
  but will eventually. In this regard, dequeue is *mostly* non-blocking.

  In terms of correctness for the per-locale queues, we know that we have a 'promise'
  to perform some task, but beyond that it is not guaranteed that the order that
  tasks that received their indices will perform them in the same order. That is
  if a task t1 obtained its indice before t2, and both t1 and t2 hash to the same index (read: locale),
  it is possible that t2 can complete its operation before t1, therefore it is non-deterministic
  in terms of order of completion. However, because overlapping concurrent operations
  are non-deterministic in nature, and that the FIFO ordering is in fact preserved on some
  level (on the per-locale queue), it is still a valid operation and transparent from the outside.
  Considering that PGAS ensures that multi-locale operations finish before continuing, we can
  verify that indeed an operation will finish in-order on a sequential task. The only way for
  operations to overlap is through overlapping tasks. Compare to a normal synchronized queue,
  and even if it is possible that t1 began its operation before t2, it is still possible for t2
  to obtain the lock before t1 in cases of unexpected delays. Therefore, the non-deterministic
  nature of the per-locale queues are nothing special, and if anything increase overall concurrency.
*/

class WaitListNode {
  // Our served queue index
  var idx : int = -1;

  // If wait is false, we spin
  // If wait is true, but completed is false, we are the new combiner thread
  // If wait is true and completed is true, we are done and can exit
  var wait : atomic bool;
  var completed : bool;

  // Next in the waitlist
  var next : WaitListNode;
}

record WaitList {
  var headWaitList : LocalAtomicObject(WaitListNode);
  var tailWaitList : LocalAtomicObject(WaitListNode);

  proc WaitList() {
    headWaitList.write(new WaitListNode());
    tailWaitList.write(new WaitListNode());
  }
}

class DistributedFIFOQueue : Queue {
  // TODO: Let user specify their own background queue...

  // Two monotonically increasing counters used in deciding which locale to choose from
  var globalHead$ : sync uint = _defaultOf(uint);
  var globalTail$ : sync uint = _defaultOf(uint);

  // per-locale data
  var perLocaleSpace = {0 .. numLocales - 1};
  var perLocaleDomain = perLocaleSpace dmapped Cyclic(startIdx=perLocaleSpace.low);
  var localQueues : [perLocaleDomain] Queue(eltType);
  var localWaitList : [perLocaleDomain] WaitList;

  // TODO: Custom Locales
  proc DistributedFIFOQueue(type eltType) {
    forall loc in Locales {
      on loc {
        localQueues[localQueues.domain.localSubdomain().first] = new SyncQueue(eltType);
      }
    }
  }

  proc getNextHeadIndex() : int {
    // We want to ensure we do not serve more than the number of tasks
    // that can potentially run on a node. This is so we don't end up serving repeated
    // requesters and get starved, and (presumably) it is large enough to serve
    // most use-cases and scenarios.
    var requestsServed = 0;

    // Create our dummy node
    var nextNode = new WaitListNode();
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node...
    var currNode = localWaitList[localWaitList.domain.localSubdomain().first].headWaitList.exchange(nextNode);
    currNode.next = nextNode;

    // Spin until we are alerted...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread. We have officially been served...
    if currNode.completed {
      var retval = currNode.idx;
      delete currNode;
      return retval;
    }

    // If we are not marked as complete, we *are* the combiner thread, so begin
    // serving everyone's request. As the combiner, it is our sole obligation to
    // contest for our global lock. Specific to the head, we must first read
    // the current tail followed by the head, which lets us know if it is safe
    // to take the next index.
    var _tail = globalTail$.readXX();
    var _head = globalHead$;
    var tmpNode = currNode;
    var tmpNodeNext : WaitListNode;
    const maxRequests = if _head <= _tail then min(here.maxTaskPar, _tail - _head) else 0;

    while (tmpNode.next != nil && requestsServed < maxRequests) {
      requestsServed = requestsServed + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      tmpNode.idx = (_head % numLocales : uint) : int;
      _head = _head + 1;

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner. As well, we must release
    // the lock and writeback the new head.
    globalHead$ = _head;
    tmpNode.wait.write(false);
    return currNode.idx;
  }

  proc getNextTailIndex() : int {
    // We want to ensure we do not serve more than the number of tasks
    // that can potentially run on a node. This is so we don't end up serving repeated
    // requesters and get starved, and (presumably) it is large enough to serve
    // most use-cases and scenarios.
    var requestsServed = 0;

    // Create our dummy node
    var nextNode = new WaitListNode();
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node...
    var currNode = localWaitList[localWaitList.domain.localSubdomain().first].tailWaitList.exchange(nextNode);
    currNode.next = nextNode;

    // Spin until we are alerted...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread. We have officially been served...
    if currNode.completed {
      var retval = currNode.idx;
      delete currNode;
      return retval;
    }

    // If we are not marked as complete, we *are* the combiner thread, so begin
    // serving everyone's request. As the combiner, it is our sole obligation to
    // contest for our global lock. Unlike the head, the tail doesn't care about
    // the state of the head, as the queue is unbounded. Interesting extension:
    // this can be made bounded by checking the distance between head and tail.
    var _tail = globalTail$;
    var tmpNode = currNode;
    var tmpNodeNext : WaitListNode;
    const maxRequests = here.maxTaskPar;

    while (tmpNode.next != nil && requestsServed < maxRequests) {
      requestsServed = requestsServed + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      tmpNode.idx = (_tail % numLocales : uint) : int;
      _tail = _tail + 1;

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner. As well, we must release
    // the lock and writeback the new head.
    globalTail$ = _tail;
    tmpNode.wait.write(false);
    return currNode.idx;
  }

  proc enqueue(elt : eltType) {
    var idx = getNextTailIndex();
    ref queue = localQueues[idx];
    on queue {
      localQueues[localQueues.domain.localSubdomain().first].enqueue(elt);
    }
  }

  proc dequeue() : (bool, eltType) {
    var (hasElem, elem) = (true, _defaultOf(eltType));
    var _head = getNextHeadIndex();
    if _head == -1 {
      return (false, _defaultOf(eltType));
    }

    // Now we get our item from the queue
    // Note that at the index given, its possible that an enqueueing task has not
    // finished yet, but we know there *should* be at least something for us, so we can
    // spin until it has what we want.
    ref queue = localQueues[_head];
    on queue do {
      var retval : (bool, eltType);
      while !retval[1] {
        retval = localQueues[localQueues.domain.localSubdomain().first].dequeue();

        if (!retval[1]) {
          writeln(here, ": Spinning... HasElem: ", hasElem, ";", "head: ", globalHead$.readXX(), ", tail: ", globalTail$.readXX());
          chpl_task_yield();
        }
      }

      (hasElem, elem) = retval;
    }
    return (hasElem, elem);
  }
}

proc main() {
  var nElems = 100000;
  writeln("Starting MPMCQueue Proof of Correctness Test ~ nElems: ", nElems);

  var queue = new DistributedFIFOQueue(int);
  var randStr = Random.makeRandomStream(int);
  for i in 1 .. nElems {
    on Locales[randStr.getNext() % numLocales] do queue.enqueue(i);
  }

  for i in 1 .. nElems {
    on Locales[randStr.getNext() % numLocales] {
      var (hasElem, elem) = queue.dequeue();
      if !hasElem || elem != i {
        halt("FAILED TEST! Expected: ", i, ", Received: ", elem, "; HasElem: ", hasElem);
      }
    }
  }

  writeln("PASSED TEST!");
}
