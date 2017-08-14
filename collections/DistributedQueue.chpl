use Collection.Queue;
use CollectionsTest;
use NQueens;

// TODO: Make most methods convoy avoidant (randomization and deferred processing)...

const FREEZE_UNFROZEN = 0;
const FREEZE_MARKED = 1;
const FREEZE_FROZEN = 2;

class DistributedQueueSlotNode {
  type eltType;
  var elt : eltType;
  var next : DistributedQueueSlotNode(eltType);
}

/*
  For each slot we maintain a two-locked queue.
*/
class DistributedQueueSlot {
  type eltType;

  // Locks are atomic to allow us to remotely contest for the lock.
  var headLock$ : sync bool;
  var tailLock$ : sync bool;

  var head : DistributedQueueSlotNode(eltType);
  var tail : DistributedQueueSlotNode(eltType);

  proc DistributedQueueSlot(type eltType) {
    head = new DistributedQueueSlotNode(eltType);
    tail = head;
  }

  proc add(elt : eltType) {
    on this {
      var node = new DistributedQueueSlotNode(eltType, elt=elt);
      local {
        tailLock$ = true;
        tail.next = node;
        tail = node;
        tailLock$;
      }
    }
  }

  // Note, this should be *only* called after we know for a fact that there is an element
  // waiting for us...
  // TODO: Check performance using an 'on' statement...
  proc remove() : eltType {
    var elt : eltType;
    on this {
      var _elt : eltType;
      headLock$ = true;
      var node = head;
      var newHead = head.next;

      if newHead == nil {
        var barrier : atomic uint;
        while newHead == nil {
          chpl_task_yield();
          barrier.fetchAdd(1);
          newHead = head.next;
        }
      }

      head = newHead;
      _elt = newHead.elt;

      headLock$;
      delete node;
      elt = _elt;
    }
    return elt;
  }

  proc ~DistributedQueueSlot() {
    on this {
      var curr = head;

      while curr != nil {
        var tmp = curr.next;
        delete curr;
        curr = tmp;
      }
    }
  }
}

/*
  An unbounded queue that is distributed across nodes.
*/
class DistributedQueue : Queue {
  var cap;
  var targetLocales;

  // Privatization id
  var pid : int;

  // Keeps track of which slot we are on...
  var globalHead : atomic uint;
  var globalTail : atomic uint;
  var queueSize : atomic int;

  // Freezing the queue consists of two phases: The 'marked' phase, where the queue
  // is marked for a state change, which prevents any new tasks for a particular state
  // from entering, followed by a 'waiting' phase where we wait any concurrent tasks
  // to find across all nodes (in case they did not notice the state change). This
  // applies to state changes to frozen and unfrozen state.
  var concurrentTasks : atomic uint;
  var frozenState : atomic int;

  // We maintain an array of slots, wherein each slot is a pointer into a node's
  // address space. To maximize parallelism, we maintain numLocales * maxTaskPar
  // to reduce the amount of contention.
  var nSlots = here.maxTaskPar * targetLocales.size;
  var slotSpace = {0..#nSlots};
  var slots : [slotSpace] DistributedQueueSlot(eltType);

  proc DistributedQueue(type eltType, cap=-1, targetLocales=Locales) {
    nSlots = here.maxTaskPar * targetLocales.size;
    slotSpace = {0..#nSlots};

    // Initialize each slot. We use a round-robin algorithm.
    var idx : atomic int;
    for 0 .. #here.maxTaskPar {
      for loc in targetLocales do on loc {
        var i = idx.fetchAdd(1);
        slots[i] = new DistributedQueueSlot(eltType);
      }
    }

    pid = _newPrivatizedClass(this);
  }

  proc DistributedQueue(other, privData, type eltType = other.eltType, cap=other.cap, targetLocales=other.targetLocales) {
    slots = other.slots;
  }

  proc dsiPrivatize(privData) {
      return new DistributedQueue(this, privData);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc add(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Enter freeze barrier...
    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() > FREEZE_UNFROZEN {
        localThis.concurrentTasks.sub(1);
        return false;
      }
    }

    // If we have a capacity of 0, then we can't really add anything anyway.
    if localThis.cap == 0 {
      local { localThis.concurrentTasks.sub(1); }
      return false;
    }

    // If we have a capacity, we must ensure that there is enough space for our
    // operation ahead of time. We take a wait-free approach by performing a
    // fetch-add on the queue size. If there is space, then we succeed within one
    // communication round-trip. If we fail, then we make attempts to fix the queue
    // size in a lock-free manner (for as long as it is over capacity). It should be
    // noted that if we see that the queue size is negative, meaning a dequeue operation
    // has over committed, we consequentially help them as well during the fetch-add loop.
    if localThis.cap > 0 {
      while true {
        var size = queueSize.fetchAdd(1);

        // Over capacity, fix before returning...
        if size >= localThis.cap {
          on this {
            var readSize = queueSize.read();
            // Attempt to fix, but yield to reduce potential contention and CPU hogging.
            while readSize > this.cap && queueSize.compareExchangeWeak(readSize, this.cap) {
              chpl_task_yield();
              readSize = queueSize.read();
            }
          }

          // Fixed, return early...
          local { localThis.concurrentTasks.sub(1); }
          return false;
        }
        // At this point, we either have a capacity and something between [0, cap],
        // or we do not have a capacity and we have something greater than 0,
        // either of which means we are safe.
        else if size >= 0 {
          break;
        }
        // If the size is negative, a dequeuer has overcommitted. Since there can
        // be an element for us, we loop again.
      }
    }
    // If we have a 'negative' capacity, we do not have one and can hold an
    // infinite amount; this gives us a more optimized code path.
    else {
      while true {
        var size = queueSize.fetchAdd(1);

        // We have reserved a spot for our operation.
        if size >= 0 {
          break;
        }
        // If the size is negative, a dequeuer has overcommitted. Since there can
        // be an element for us, we loop again.
      }
    }

    // At this point, we know we have a space for us. We find our slot based on another
    // fetch-add counter, making this wait-free as well.
    var tail = (globalTail.fetchAdd(1) % localThis.nSlots : uint) : int;
    localThis.slots[tail].add(elt);
    local { localThis.concurrentTasks.sub(1); }
    return true;
  }

  proc remove() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Enter freeze barrier...
    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() > FREEZE_UNFROZEN {
        localThis.concurrentTasks.sub(1);
        return (false, _defaultOf(eltType));
      }
    }

    // If we have a capacity of 0, then we can't really remove anything anyway.
    if localThis.cap == 0 {
      local { localThis.concurrentTasks.sub(1); }
      return (false, _defaultOf(eltType));
    }

    // Similar to enqueue, we use a wait-free method for updating the queue size,
    // using fetch-sub instead. Like enqueue, we make attempts to fix the queue
    // size in a lock-free manner (for as long as it is negative). It should be
    // noted that if we see that the queue size is over capacity, meaning an
    // enqueue operation has over committed, we consequentially help them as well
    // during the fetch-sub loop.
    while true {
      var size = queueSize.fetchSub(1);

      // Negative, fix before returning...
      if size <= 0 {
        on this {
          var readSize = queueSize.read();
          // Attempt to fix, but yield to reduce potential contention and CPU hogging.
          while readSize < 0 && queueSize.compareExchangeWeak(readSize, 0) {
            chpl_task_yield();
            readSize = queueSize.read();
          }
        }

        // Fixed, return early...
        local { localThis.concurrentTasks.sub(1); }
        return (false, _defaultOf(eltType));
      }
      // If we have a cap, then at this point, we have something between [0, cap],
      // if we do not have a cap then there is no need to 'fix' the queue size;
      // in both cases we are safe.
      else if localThis.cap < 0 || size <= localThis.cap {
        break;
      }
      // If the size is over capacity, a enqueuer has overcommitted. Since there can
      // be an element for us, we loop again.
    }

    // Find a slot we can take from; if the slot is empty, we bail as it is empty.
    var head = (globalHead.fetchAdd(1) % localThis.nSlots : uint) : int;
    var elt = localThis.slots[head].remove();
    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  proc isFrozen() : bool {
    var localThis = getPrivatizedThis;
    var state = localThis.frozenState.read();

    // Current transitioning state, wait it out...
    while state == FREEZE_MARKED {
      chpl_task_yield();
      state = localThis.frozenState.read();
    }

    return state == FREEZE_FROZEN;
  }

  proc freeze() : bool {
    var localThis = getPrivatizedThis;

    // Check if already frozen
    if localThis.frozenState.read() == FREEZE_FROZEN {
      return true;
    }

    // Mark as transient state...
    coforall loc in targetLocales do on loc {
      localThis.frozenState.write(FREEZE_MARKED);
      localThis.concurrentTasks.waitFor(0);
    }

    // Mark as frozen...
    coforall loc in targetLocales do on loc {
      localThis.frozenState.write(FREEZE_FROZEN);
    }

    return true;
  }

  proc unfreeze() : bool {
    var localThis = getPrivatizedThis;

    // Check if already unfrozen
    if localThis.frozenState.read() == FREEZE_UNFROZEN {
      return true;
    }

    // Mark as transient state...
    coforall loc in targetLocales do on loc {
      localThis.frozenState.write(FREEZE_MARKED);
      localThis.concurrentTasks.waitFor(0);
    }

    // Mark as unfrozen...
    coforall loc in targetLocales do on loc {
      localThis.frozenState.write(FREEZE_UNFROZEN);
    }

    return true;
  }

  // To clear the data structure, we must be sure to update the counter while
  // maintaining concurrent safety. The easiest way to do this is to just call remove.
  proc clear() {
    while remove()[1] do ;
  }

  /*
    Iterate in FIFO order.

    TODO: Once the issue of serial iteration leaking state is fixed, a simple
    one-way channel implementation may prove very useful here to get an item
    in a round-robin manner.
  */
  iter these() : eltType {
    if !isFrozen() {
      halt("Iteration only supported while frozen...");
    }

    var localThis = getPrivatizedThis;

    // Fill our slots to visit in FIFO order.
    var head = globalHead.read();
    var tail = globalTail.read();

    // Check if empty...
    if head >= tail {
      return;
    }

    var nElems = tail - head;
    var nSearchNodes = min(nElems, nSlots) : int;
    var nodes : [{0..#nSearchNodes}] DistributedQueueSlotNode(eltType);
    var startIdx = (head % nSlots : uint) : int;
    for offset in 0 .. #nSearchNodes {
      nodes[offset] = slots[(startIdx + offset) % nSlots].head.next;
    }

    var iterations = nElems;
    var nodeIdx = 0;
    while iterations > 0 {
      yield nodes[nodeIdx].elt;
      nodes[nodeIdx] = nodes[nodeIdx].next;
      nodeIdx = (nodeIdx + 1) % nSlots;
      iterations = iterations - 1;
    }
  }

  proc size() : int {
    return queueSize.read();
  }

  proc isEmpty() : bool {
      return size() == 0;
  }

  // TODO: Make Convoy Avoidant
  proc contains(elt : eltType) : bool {
    // Frozen lookups can be done concurrently
    if isFrozen() {
      var containsElem : atomic bool;
      forall elem in this {
        if elem == elt {
          containsElem.write(true);
        }
      }
      return containsElem.read();
    }

    // Non-frozen lookups require us to obtain the lock to ensure mutual exclusion
    var localThis = getPrivatizedThis;
    var foundItem : atomic bool;
    for slot in localThis.slots {
      on slot {
        const targetElt = elt;
        slot.headLock$ = true;
        slot.tailLock$ = true;

        var prev = slot.head;
        var node = slot.head.next;
        while node != nil {
          if node.elt == targetElt {
            foundItem.write(true);
            break;
          }
        }

        // Release...
        slot.headLock$;
        slot.tailLock$;
      }

      if foundItem.read() {
        break;
      }
    }

    return foundItem.read();
  }

  iter these(param tag : iterKind) where tag == iterKind.leader {
    if !isFrozen() {
      halt("Iteration only supported while frozen...");
    }
    coforall slot in getPrivatizedThis.slots do on slot do yield slot;
  }

  iter these(param tag : iterKind, followThis) where tag == iterKind.follower {
    var node = followThis.head.next;
    while node != nil {
      yield node.elt;
      node = node.next;
    }
  }

  proc ~DistributedQueue() {
    var localThis = getPrivatizedThis;
    for slot in localThis.slots do delete slot;
  }
}

proc main() {
  var dq = new DistributedQueue(int);

  counterTest(dq);
  doNQueens(new DistributedQueue(26 * int));
  writeln("Done tests...");
}
