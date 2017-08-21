use Collection;

/*
  A parallel-safe scalable distributed deque. A deque is a double-ended queue that supports
  insertion and removal from both ends of the queue, effectively supporting both
  FIFO, LIFO, and a Total ordering, where the order in which you add them will be
  the exact order you remove them in; for emphasis, a Deque can be used as a Queue,
  a Stack, and a List respectively. The deque enforces a 'barrier', which is a method
  of checking whether you may proceed with an operation, that is wait-free under
  most cases, lock-free in the worst case, which guarantees scalability. In the
  barrier, we perform bounds checking (if a capacity is given). Deque operations
  are separated into two levels: global and local. At a global level, we use
  simple fetchAdd and fetchSub counters to denote which local deque we apply our
  operation to, and at a local level we use an unrolled linked list which further
  has its own (non-atomic) counter.
*/

/*
  Size of each unroll block for each local deque node.
*/
config param distributedDequeBlockSize = 8;

/*
  The ordering used for serial iteration. NONE, the default, is the most performant
  and is algorithmically similar to parallel iteration.
*/
enum Ordering {
  NONE,
  FIFO,
  LIFO
}

// For each node we manage an unroll block. This block needs to also support Deque
// operations, and as such we maintain our own mini headIdx and tailIdx. Since we can
// add and remove from either direction, we must also maintain the size ourselves...
pragma "no doc"
class LocalDequeNode {
  type eltType;
  var elements : distributedDequeBlockSize * eltType;
  var headIdx : int = 1;
  var tailIdx : int = 1;
  var size : int;
  var next : LocalDequeNode(eltType);
  var prev : LocalDequeNode(eltType);

  inline proc isFull {
    return size == distributedDequeBlockSize;
  }

  inline proc isEmpty {
    return size == 0;
  }

  inline proc pushBack(elt : eltType) {
    elements[tailIdx] = elt;

    tailIdx += 1;
    if tailIdx > distributedDequeBlockSize {
      tailIdx = 1;
    }
    size += 1;
  }

  inline proc popBack() : eltType {
    tailIdx -= 1;
    if tailIdx == 0 {
      tailIdx = distributedDequeBlockSize;
    }

    size -= 1;
    return elements[tailIdx];
  }

  inline proc pushFront(elt : eltType) {
    headIdx -= 1;
    if headIdx == 0 {
      headIdx = distributedDequeBlockSize;
    }

    elements[headIdx] = elt;
    size += 1;
  }

  inline proc popFront() : eltType {
    var elt = elements[headIdx];
    headIdx += 1;
    if headIdx > distributedDequeBlockSize {
      headIdx = 1;
    }

    size -= 1;
    return elt;
  }
}

/*
  For each slot (core) we maintain a deque.

  **TODO:** Need to convert LocalDequeNode to use C_Ptr, double the size of each
  successor for better locality, and use the snapshot approach so that iteration
  does not prevent usage of other methods on the same Deque from the same task.
*/
pragma "no doc"
class LocalDeque {
  type eltType;

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
  A parallel-safe scalable distributed double-ended queue that supports both
  insertion and removal from either end of the queue. Can be used as a Queue,
  Stack, or even a List.
*/
class DistributedDeque : Collection {
  /*
    Capacity, the maximum number of elements a Deque can hold. A `cap` of -1 is
    considered unbounded.
  */
  var cap : int;
  pragma "no doc"
  var targetLocDom : domain(1);
  /*
    Locales to distribute the `Deque` across.
  */
  var targetLocales : [targetLocDom] locale;

  // Privatization id
  pragma "no doc"
  var pid : int;

  // Keeps track of which slot we are on...
  pragma "no doc"
  var globalHead : atomic int;
  pragma "no doc"
  var globalTail : atomic int;
  pragma "no doc"
  var queueSize : atomic int;

  // We maintain an array of slots, wherein each slot is a pointer into a node's
  // address space. To maximize parallelism, we maintain numLocales * maxTaskPar
  // to reduce the amount of contention.
  pragma "no doc"
  var nSlots : int;
  pragma "no doc"
  var slotSpace = {0..-1};
  pragma "no doc"
  var slots : [slotSpace] LocalDeque(eltType);

  proc DistributedDeque(type eltType, cap : int = -1, targetLocales : [?locDom] locale =Locales) {
    this.cap = cap;
    this.nSlots = here.maxTaskPar * targetLocales.size;
    this.slotSpace = {0..#this.nSlots};
    this.targetLocDom = locDom;
    this.targetLocales = targetLocales;

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

  pragma "no doc"
  proc DistributedDeque(other, privData, type eltType = other.eltType) {
    this.cap = other.cap;
    this.targetLocDom = other.targetLocDom;
    this.targetLocales = other.targetLocales;
    this.nSlots = other.nSlots;
    this.slotSpace = {0..#this.nSlots};
    slots = other.slots;
  }

  pragma "no doc"
  proc dsiPrivatize(privData) {
      return new DistributedDeque(this, privData);
  }

  pragma "no doc"
  proc dsiGetPrivatizeData() {
    return pid;
  }

  pragma "no doc"
  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  pragma "no doc"
  inline proc enterRemoveBarrier(localThis) {
    // If we have a capacity of 0, then we can't really remove anything anyway.
    if localThis.cap == 0 {
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

  pragma "no doc"
  inline proc enterAddBarrier(localThis) {
    // If we have a capacity of 0, then we can't really add anything anyway.
    if localThis.cap == 0 {
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

  /*
    Syntactic sugar for `pushBack`.
  */
  proc add(elt : eltType) : bool {
    return pushBack(elt);
  }

  /*
    Syntactic sugar for `popFront`.
  */
  proc remove() : (bool, eltType) {
    return popFront();
  }

  /*
    Syntactic sugar for `pushBack`.
  */
  proc enqueue(elt : eltType) : bool {
    return pushBack(elt);
  }

  /*
    Syntactic sugar for `popFront`.
  */
  proc dequeue() : (bool, eltType) {
    return popFront();
  }

  /*
    Syntactic sugar for `pushBack`.
  */
  proc push(elt : eltType) : bool {
    return pushBack(elt);
  }

  /*
    Syntactic sugar for `popBack`.
  */
  proc pop() : (bool, eltType) {
    return popBack();
  }

  /*
    Appends the element to the tail.
  */
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
    return true;
  }

  /*
    Removes the element at the tail.
  */
  proc popBack() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Test for if we can continue...
    if enterRemoveBarrier(localThis) == false {
      return (false, _defaultOf(eltType));
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var tail = (globalTail.fetchSub(1) - 1) % localThis.nSlots;
    var elt = localThis.slots[abs(tail)].popBack();
    return (true, elt);
  }

  /*
    Appends the element to the head.
  */
  proc pushFront(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Test if we can continue...
    if enterAddBarrier(localThis) == false {
      return false;
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var head = (globalHead.fetchSub(1) - 1) % localThis.nSlots;
    localThis.slots[abs(head)].pushFront(elt);
    return true;
  }

  /*
    Removes the element at the head.
  */
  proc popFront() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Test for if we can continue...
    if enterRemoveBarrier(localThis) == false {
      return (false, _defaultOf(eltType));
    }

    // We find our slot based on another fetch-add counter, making this wait-free as well.
    var head = globalHead.fetchAdd(1) % localThis.nSlots;
    var elt = localThis.slots[abs(head)].popFront();
    return (true, elt);
  }

  /*
    Obtains the number of elements held by this queue.
  */
  proc getSize() : int {
    return queueSize.read();
  }

  /*
    Performs a lookup for the element in the data structure.
  */
  proc contains(elt : eltType) : bool {
    var containsElem : atomic bool;
    forall elem in this {
      if elem == elt {
        containsElem.write(true);
      }
    }
    return containsElem.read();
  }

  /*
    Iterate over all elements in the deque in the order specified.

    **Warning:** Calling other methods while inside of an iterator is not safe as
    it will likely lead to deadlock.

    **FIXME:** Likely can be worked around by either using snapshot iteration approach
    or by making the lock reentrant and forcing all iterators to acquire all locks in
    some global locking order.
  */
  iter these(param order : Ordering = Ordering.NONE) : eltType where order == Ordering.NONE {
    for slot in getPrivatizedThis.slots {
      slot.lock$ = true;
      var node = slot.head;

      while node != nil {
        var headIdx = node.headIdx;
        for 1 .. node.size {
          yield node.elements[headIdx];

          headIdx += 1;
          if headIdx > distributedDequeBlockSize {
            headIdx = 1;
          }
        }
        node = node.next;
      }

      slot.lock$;
    }
  }

  iter these(param order : Ordering = Ordering.NONE) : eltType where order == Ordering.FIFO {
    var localThis = getPrivatizedThis;

    // Fill our slots to visit in FIFO order.
    var head = globalHead.read();
    var tail = globalTail.read();
    var size = queueSize.read();

    // Check if empty...
    if size == 0 {
      return;
    }

    // Acquire in locking order...
    for slot in slots do slot.lock$ = true;

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
      if headIdx > distributedDequeBlockSize {
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

    // Release in locking order...
    for slot in slots do on slot slot.lock$;
  }

  iter these(param order : Ordering = Ordering.NONE) : eltType where order == Ordering.LIFO {
    var localThis = getPrivatizedThis;

    // Fill our slots to visit in FIFO order.
    var head = globalHead.read();
    var tail = globalTail.read();
    var size = queueSize.read();

    // Check if empty...
    if size == 0 {
      return;
    }

    // Acquire in locking order...
    for slot in slots do slot.lock$ = true;

    // We iterate directly over the heads of each slot, so we capture them in advance.
    var nodes : [{0..#nSlots}] (int, int, LocalDequeNode(eltType));
    for i in 0 .. #nSlots {
      var node = slots[i].tail;
      nodes[i] = (node.size, node.tailIdx, node);
    }

    // Iterate over captured head nodes; each time we read them we advance them
    var iterations = size;
    while tail - 1 >= head - 1 {
      if iterations == 0 then break;
      iterations -= 1;

      var idx = (tail - 1) % nSlots;
      var (size, tailIdx, node) = nodes[idx];
      if node == nil {
        halt("Iterating over nil nodes, head: ", head, ", tail: ", tail, ", idx: ", tail-1);
      }
      yield node.elements[tailIdx];

      // Update state...
      size -= 1;
      tailIdx -= 1;
      if tailIdx == 0 {
        tailIdx = distributedDequeBlockSize;
      }

      // Advance...
      if size == 0 {
        node = node.prev;
        if node != nil {
          nodes[idx] = (node.size, node.tailIdx, node);
        } else {
          nodes[idx] = (-1, -1, node);
        }
      } else {
        // Else update state...
        nodes[idx] = (size, tailIdx, node);
      }
    }

    // Release in locking order...
    for slot in slots do on slot slot.lock$;
  }

  iter these(param tag : iterKind) where tag == iterKind.leader {
    coforall slot in getPrivatizedThis.slots do on slot do yield slot;
  }

  iter these(param tag : iterKind, followThis) where tag == iterKind.follower {
    followThis.lock$ = true;
    var node = followThis.head;

    while node != nil {
      var headIdx = node.headIdx;
      for 1 .. node.size {
        yield node.elements[headIdx];

        headIdx += 1;
        if headIdx > distributedDequeBlockSize {
          headIdx = 1;
        }
      }
      node = node.next;
    }

    followThis.lock$;
  }

  proc ~DistributedDeque() {
    var localThis = getPrivatizedThis;
    for slot in localThis.slots do delete slot;
  }
}
