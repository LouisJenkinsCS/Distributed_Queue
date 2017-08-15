use Collection;
use CollectionsTest;
use NQueens;

// TODO: Make most methods convoy avoidant (randomization and deferred processing)...
// TODO: Convert into a Deque; we perform bounds checking at the door, so head and tail
// are guaranteed to not switch sides.

/*
  Frozen states... If we are FREEZE_UNFROZEN, we are mutable. If we are FREEZE_FROZEN,
  we are immutable. If we are FREEZE_MARKED, we are in the middle of a state change.
*/
private const FREEZE_UNFROZEN = 0;
private const FREEZE_MARKED = 1;
private const FREEZE_FROZEN = 2;

class DistributedDequeSlotNode {
  type eltType;
  var elt : eltType;
  var next : DistributedDequeSlotNode(eltType);
  var prev : DistributedDequeSlotNode(eltType);
}

/*
  For each slot we maintain a two-locked queue.
*/
class DistributedDequeSlot {
  type eltType;

  // Locks are atomic to allow us to remotely contest for the lock.
  var lock$ : sync bool;

  var head : DistributedDequeSlotNode(eltType);
  var tail : DistributedDequeSlotNode(eltType);

  // The size of a segment. This is used as both a means of knowing when an element
  // gets added, as well as a barrier to prevent the head and tail from being cached.
  var size : atomic int;

  proc pushBack(elt : eltType) {
    on this {
      var node = new DistributedDequeSlotNode(eltType, elt=elt);
      lock$ = true;

      if tail != nil {
        tail.next = node;
      }
      if head == nil {
        head = node;
      }
      node.prev = tail;
      tail = node;
      size.add(1);

      lock$;
    }
  }

  proc popBack() : eltType {
    var elt : eltType;
    on this {
      while true {
        // Wait until there is an element for us...
        while size.read() == 0 do chpl_task_yield();
        lock$ = true;

        // Someone else came in and took a value, wait for the next one...
        if size.read() == 0 {
          lock$;
          continue;
        }

        var node = tail;
        if node == head {
          head = nil;
        }
        tail = node.prev;
        size.sub(1);

        lock$;
        elt = node.elt;
        delete node;
        break;
      }
    }

    return elt;
  }

  proc pushFront(elt : eltType) {
    on this {
      var node = new DistributedDequeSlotNode(eltType, elt=elt);
      lock$ = true;

      if head != nil {
        head.prev = node;
      }
      if tail == nil {
        tail = node;
      }
      node.next = head;
      head = node;
      size.add(1);

      lock$;
    }
  }

  proc popFront() : eltType {
    var elt : eltType;
    on this {
      while true {
        // Wait until there is an element for us...
        while size.read() == 0 do chpl_task_yield();
        lock$ = true;

        // Someone else came in and took a value, wait for the next one...
        if size.read() == 0 {
          lock$;
          continue;
        }

        var node = head;
        if node == tail {
          tail = nil;
        }
        head = node.next;
        size.sub(1);

        lock$;
        elt = node.elt;
        delete node;
        break;
      }
    }

    return elt;
  }

  proc ~DistributedDequeSlot() {
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
class DistributedDeque : Collection {
  var cap;
  var targetLocales;

  // Privatization id
  var pid : int;

  // Keeps track of which slot we are on...
  var globalHead : atomic int;
  var globalTail : atomic int;
  var queueSize : atomic int;

  // Freezing the queue consists of two phases: The 'marked' phase, where the queue
  // is marked for a state change, which prevents any new tasks for a particular state
  // from entering, followed by a 'waiting' phase where we wait any concurrent tasks
  // to find across all nodes (in case they did not notice the state change). This
  // applies to state changes to frozen and unfrozen state.
  var concurrentTasks : atomic int;
  var frozenState : atomic int;

  // We maintain an array of slots, wherein each slot is a pointer into a node's
  // address space. To maximize parallelism, we maintain numLocales * maxTaskPar
  // to reduce the amount of contention.
  var nSlots = here.maxTaskPar * targetLocales.size;
  var slotSpace = {0..#nSlots};
  var slots : [slotSpace] DistributedDequeSlot(eltType);

  proc DistributedDeque(type eltType, cap=-1, targetLocales=Locales) {
    nSlots = here.maxTaskPar * targetLocales.size;
    slotSpace = {0..#nSlots};

    // Initialize each slot. We use a round-robin algorithm.
    var idx : atomic int;
    for 0 .. #here.maxTaskPar {
      for loc in targetLocales do on loc {
        var i = idx.fetchAdd(1);
        slots[i] = new DistributedDequeSlot(eltType);
      }
    }

    pid = _newPrivatizedClass(this);
  }

  proc DistributedDeque(other, privData, type eltType = other.eltType, cap=other.cap, targetLocales=other.targetLocales) {
    slots = other.slots;
  }

  proc dsiPrivatize(privData) {
      return new DistributedDeque(this, privData);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  inline proc enterRemoveBarrier(localThis) {
    // Enter freeze barrier...
    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() > FREEZE_UNFROZEN {
        localThis.concurrentTasks.sub(1);
        return false;
      }
    }

    // If we have a capacity of 0, then we can't really remove anything anyway.
    if localThis.cap == 0 {
      local { localThis.concurrentTasks.sub(1); }
      return false;
    }

    // Similar to add, we use a wait-free method for updating the queue size,
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
        return false;
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

    return true;
  }

  inline proc enterAddBarrier(localThis) {
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

    return true;
  }

  proc add(elt : eltType) : bool {
    return pushBack(elt);
  }

  proc remove() : (bool, eltType) {
    return popFront();
  }

  proc enqueue(elt : eltType) : bool {
    return pushBack(elt);
  }

  proc dequeue() : (bool, eltType) {
    return popFront();
  }

  proc push(elt : eltType) : bool {
    return pushBack(elt);
  }

  proc pop() : (bool, eltType) {
    return popBack();
  }

  proc pushBack(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Test for if we can continue...
    if enterAddBarrier(localThis) == false {
      return false;
    }

    // At this point, we know we have a space for us. We find our slot based on another
    // fetch-add counter, making this wait-free as well.
    var tail = globalTail.fetchAdd(1) % localThis.nSlots;
    localThis.slots[tail].pushBack(elt);
    local { localThis.concurrentTasks.sub(1); }
    return true;
  }

  proc popBack() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Test for if we can continue...
    if enterRemoveBarrier(localThis) == false {
      return (false, _defaultOf(eltType));
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var tail = globalTail.fetchSub(1) % localThis.nSlots;
    var elt = localThis.slots[tail].popBack();
    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  proc pushFront(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Test if we can continue...
    if enterAddBarrier(localThis) == false {
      return (false, _defaultOf(eltType));
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var head = globalHead.fetchSub(1) % localThis.nSlots;
    localThis.slots[head].pushFront(elt);
    local { localThis.concurrentTasks.sub(1); }
    return true;
  }

  proc popFront() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Test for if we can continue...
    if enterRemoveBarrier(localThis) == false {
      return (false, _defaultOf(eltType));
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var head = globalHead.fetchAdd(1) % localThis.nSlots;
    var elt = localThis.slots[head].popFront();
    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  proc canFreeze() : bool {
    return true;
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
        slot.lock$ = true;

        var prev = slot.head;
        var node = slot.head.next;
        while node != nil {
          if node.elt == targetElt {
            foundItem.write(true);
            break;
          }
        }

        // Release...
        slot.lock$;
      }

      if foundItem.read() {
        break;
      }
    }

    return foundItem.read();
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
    var size = queueSize.read();

    // Check if empty...
    if size == 0 {
      return;
    }

    // We iterate directly over the heads of each slot, so we capture them in advance.
    var nodes : [{0..#nSlots}] DistributedDequeSlotNode(eltType);
    for i in 0 .. #nSlots {
      nodes[i] = slots[i].head;
    }

    // Iterate over captured head nodes; each time we read them we advance them
    for i in head..#tail {
      var idx = i % nSlots;
      yield nodes[idx].elt;
      nodes[idx] = nodes[idx].next;
    }
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

  proc ~DistributedDeque() {
    var localThis = getPrivatizedThis;
    for slot in localThis.slots do delete slot;
  }
}

proc main() {
  var dq = new DistributedDeque(int);

  counterTest(dq);
  doNQueens(new DistributedDeque(26 * int));
  writeln("Done tests...");
}
