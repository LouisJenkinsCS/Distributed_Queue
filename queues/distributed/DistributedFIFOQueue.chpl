use CyclicDist;
use CommDiagnostics;
use Queue;
use SyncQueue;

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

class DistributedFIFOQueue : Queue {
  // TODO: Let user specify their own background queue...

  // Two monotonically increasing counters used in deciding which locale to choose from
  var head$ : sync uint = _defaultOf(uint);
  var tail : atomic uint;

  // per-locale queues
  // localQueueSpace and localQueueDomain
  // 0 based
  var localQueueSpace = {0 .. numLocales - 1};
  var localQueueDomain = localQueueSpace dmapped Cyclic(startIdx=localQueueSpace.low);
  var localQueues : [localQueueDomain] Queue(eltType);

  // TODO: Custom Locales
  proc DistributedFIFOQueue(type eltType) {
    forall loc in Locales {
      on loc {
        localQueues[localQueues.domain.localSubdomain().first] = new SyncQueue(eltType);
      }
    }
  }

  proc enqueue(elt : eltType) {
    var idx : int = (tail.fetchAdd(1) % numLocales : uint) : int;
    ref queue = localQueues[idx];
    on queue {
      localQueues[localQueues.domain.localSubdomain().first].enqueue(elt);
    }
  }

  proc dequeue() : (bool, eltType) {
    var (hasElem, elem) = (true, _defaultOf(eltType));

    // Note: By reading the current tail first, we effectively eliminate everything
    // down to two network calls; the read + lock-acquisition, and write + lock-release
    var _tail : uint = tail.read();
    var _head : uint = head$; // Full -> Empty

    // BUG: Overflow will cause undefined behavior... fix later!
    // IDEA: Since we hold the lock and can do work locally, we should use some
    // combined synchronization here so that requests on this node can have increased
    // throughput!
    if _head < _tail {
      // Increment head counter... Empty -> Full
      head$ = _head + 1;

      // Now we get our item from the queue
      // Note that at the index given, its possible that an enqueueing task has not
      // finished yet, but we know there *should* be at least something for us, so we can
      // spin until it has what we want.
      ref queue = localQueues[(_head % numLocales : uint) : int];
      on queue do {
        var retval : (bool, eltType);
        while !retval[1] {
          retval = localQueues[localQueues.domain.localSubdomain().first].dequeue();

          if (!retval[1]) {
            writeln(here, ": Spinning... HasElem: ", hasElem, ";", "head: ", _head, ", tail: ", _tail);
            chpl_task_yield();
          }
        }

        (hasElem, elem) = retval;
      }
    } else {
      // Empty, writeback current head and release... Empty -> Full
      head$ = _head;
      hasElem = false;
    }

    return (hasElem, elem);
  }
}
