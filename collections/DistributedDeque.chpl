use Collection;

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

// Default assumption is that the cache line size is 64 bytes and that most elements
// are within 8 bytes.
private param DEQUE_BLOCK_SIZE = 8;

// For each node we manage an unroll block. This block needs to also support Deque
// operations, and as such we maintain our own mini headIdx and tailIdx. Since we can
// add and remove from either direction, we must also maintain the size ourselves...
class LocalDequeNode {
  type eltType;
  var elements : DEQUE_BLOCK_SIZE * eltType;
  var headIdx : int = 1;
  var tailIdx : int = 1;
  var size : int;
  var next : LocalDequeNode(eltType);
  var prev : LocalDequeNode(eltType);

  inline proc isFull {
    return size == DEQUE_BLOCK_SIZE;
  }

  inline proc isEmpty {
    return size == 0;
  }

  inline proc pushBack(elt : eltType) {
    elements[tailIdx] = elt;

    tailIdx += 1;
    if tailIdx > DEQUE_BLOCK_SIZE {
      tailIdx = 1;
    }
    size += 1;
  }

  inline proc popBack() : eltType {
    tailIdx -= 1;
    if tailIdx == 0 {
      tailIdx = DEQUE_BLOCK_SIZE;
    }

    size -= 1;
    return elements[tailIdx];
  }

  inline proc pushFront(elt : eltType) {
    headIdx -= 1;
    if headIdx == 0 {
      headIdx = DEQUE_BLOCK_SIZE;
    }

    elements[headIdx] = elt;
    size += 1;
  }

  inline proc popFront() : eltType {
    var elt = elements[headIdx];
    headIdx += 1;
    if headIdx > DEQUE_BLOCK_SIZE {
      headIdx = 1;
    }

    size -= 1;
    return elt;
  }
}

/*
  For each slot we maintain a deque.
*/
class LocalDeque {
  type eltType;

  // Locks are atomic to allow us to remotely contest for the lock.
  var lock$ : sync bool;

  var head : LocalDequeNode(eltType);
  var tail : LocalDequeNode(eltType);

  // We cache the last deleted node to handle cases where we have rapid mixed push/pop
  var cached : LocalDequeNode(eltType);

  // The size of a segment. This is used as both a means of knowing when an element
  // gets added, as well as a barrier to prevent the head and tail from being cached.
  var size : atomic int;

  inline proc recycleNode() {
    // If we have cached a previous used node, reuse it here...
    if cached != nil {
      var tmp = cached;
      cached = nil;
      return tmp;
    }

    // Create a new one...
    return  new LocalDequeNode(eltType);
  }

  inline proc retireNode(node) {
    if cached != nil {
      delete cached;
    }

    cached = node;
  }

  proc pushBack(elt : eltType) {
    on this {
      var _elt = elt;
      local {
        lock$ = true;

        // Its empty...
        if tail == nil {
          tail = recycleNode();
          head = tail;
        }

        // Its full...
        if tail.isFull {
          tail.next = recycleNode();
          tail.next.prev = tail;
          tail = tail.next;
        }

        // Push...
        tail.pushBack(_elt);
        size.add(1);

        lock$;
      }
    }
  }

  // TODO: Make 'local'
  proc popBack() : eltType {
    var elt : eltType;
    on this {
      var _elt : eltType;
      local {
        while true {
          // Check if there is an element for us...
          if size.read() == 0 {
            while size.read() == 0 {
              chpl_task_yield();
            }
          }

          lock$ = true;

          // Someone else came in and took a value, wait for the next one...
          if size.read() == 0 {
            lock$;
            continue;
          }

          // Pop...
          _elt = tail.popBack();
          if tail.isEmpty {
            var node = tail;
            tail = tail.prev;

            // If not empty, remove reference to retired node...
            // If it is empty, fix the head...
            if tail != nil {
              tail.next = nil;
            } else {
              head = nil;
            }

            retireNode(node);
          }

          size.sub(1);
          lock$;
          break;
        }
      }
      elt = _elt;
    }

    return elt;
  }

  proc pushFront(elt : eltType) {
    on this {
      var _elt = elt;
      local {
        lock$ = true;

        // Its empty...
        if head == nil {
          head = recycleNode();
          tail = head;
        }

        // Its full...
        if head.isFull {
          head.prev = recycleNode();
          head.prev.next = head;
          head = head.prev;
        }

        // Push...
        head.pushFront(_elt);
        size.add(1);

        lock$;
      }
    }
  }

  proc popFront() : eltType {
    var elt : eltType;
    on this {
      var _elt : eltType;
      local {
        while true {
          // Check if there is an element for us...
          if size.read() == 0 {
            while size.read() == 0 {
              chpl_task_yield();
            }
          }

          lock$ = true;

          // Someone else came in and took a value, wait for the next one...
          if size.read() == 0 {
            lock$;
            continue;
          }

          // Pop...
          _elt = head.popFront();
          if head.isEmpty {
            var node = head;
            head = head.next;

            // If not empty, remove reference to retired node...
            // If it is empty, fix the tail...
            if head != nil {
              head.prev = nil;
            } else {
              tail = nil;
            }

            retireNode(node);
          }

          size.sub(1);
          lock$;
          break;
        }
      }
      elt = _elt;
    }

    return elt;
  }

  proc ~LocalDeque() {
    on this {
      var curr = head;

      while curr != nil {
        var tmp = curr.next;
        delete curr;
        curr = tmp;
      }

      if cached != nil {
        delete cached;
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
  var slots : [slotSpace] LocalDeque(eltType);

  proc DistributedDeque(type eltType, cap=-1, targetLocales=Locales) {
    nSlots = here.maxTaskPar * targetLocales.size;
    slotSpace = {0..#nSlots};

    // Initialize each slot. We use a round-robin algorithm.
    var idx : atomic int;
    for 0 .. #here.maxTaskPar {
      for loc in targetLocales do on loc {
        var i = idx.fetchAdd(1);
        slots[i] = new LocalDeque(eltType);
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
          while readSize < 0 && !queueSize.compareExchangeWeak(readSize, 0) {
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
            while readSize > this.cap && !queueSize.compareExchangeWeak(readSize, this.cap) {
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
    localThis.slots[abs(tail)].pushBack(elt);
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
    var tail = (globalTail.fetchSub(1) - 1) % localThis.nSlots;
    var elt = localThis.slots[abs(tail)].popBack();
    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  proc pushFront(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Test if we can continue...
    if enterAddBarrier(localThis) == false {
      return false;
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var head = (globalHead.fetchSub(1) - 1) % localThis.nSlots;
    localThis.slots[abs(head)].pushFront(elt);
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
    var elt = localThis.slots[abs(head)].popFront();
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

        var node = slot.head;
        while node != nil {
          var headIdx = node.headIdx;
          for 1 .. node.size {
            if node.elements[headIdx] == targetElt {
              foundItem.write(true);
              break;
            }

            headIdx += 1;
            if headIdx > DEQUE_BLOCK_SIZE {
              headIdx = 1;
            }
          }

          if foundItem.read() {
            break;
          }

          node = node.next;
        }

        // Release...
        slot.lock$;
      }

      if foundItem.read() {
        return true;
      }
    }

    return false;
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
    var nodes : [{0..#nSlots}] (int, int, LocalDequeNode(eltType));
    for i in 0 .. #nSlots {
      var node = slots[i].head;
      nodes[i] = (node.size, node.headIdx, node);
    }

    // Iterate over captured head nodes; each time we read them we advance them
    var iterations = size;
    for i in head..#tail {
      if iterations == 0 then break;
      iterations -= 1;

      var idx = i % nSlots;
      var (size, headIdx, node) = nodes[idx];
      if node == nil {
        halt("Iterating over nil nodes, head: ", head, ", tail: ", tail, ", idx: ", i);
      }
      yield node.elements[headIdx];

      // Update state...
      size -= 1;
      headIdx += 1;
      if headIdx > DEQUE_BLOCK_SIZE {
        headIdx = 1;
      }

      // Advance...
      if size == 0 {
        node = node.next;
        if node != nil {
          nodes[idx] = (node.size, node.headIdx, node);
        } else {
          nodes[idx] = (-1, -1, node);
        }
      } else {
        // Else update state...
        nodes[idx] = (size, headIdx, node);
      }
    }
  }

  iter FIFO() {
    halt("Not implemented...");
  }

  iter LIFO() {
    halt("Not implemented...");
  }

  iter these(param tag : iterKind) where tag == iterKind.leader {
    if !isFrozen() {
      halt("Iteration only supported while frozen...");
    }
    coforall slot in getPrivatizedThis.slots do on slot do yield slot;
  }

  iter these(param tag : iterKind, followThis) where tag == iterKind.follower {
    var node = followThis.head;
    while node != nil {
      var headIdx = node.headIdx;
      for 1 .. node.size {
        yield node.elements[headIdx];

        headIdx += 1;
        if headIdx > DEQUE_BLOCK_SIZE {
          headIdx = 1;
        }
      }
      node = node.next;
    }
  }

  proc ~DistributedDeque() {
    var localThis = getPrivatizedThis;
    for slot in localThis.slots do delete slot;
  }
}
