use Collection.Queue;

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

  // Number of elements in this slot. If the count is negative, that means a 'dequeue'
  // has skipped over this, and as 'enqueue' we should as well to catch up.
  var size : atomic int;

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
      local {
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
      }
      elt = _elt;
    }
    return elt;
  }

  proc ~DistributedQueueSlot() {
    on this {
      local {
        var curr = head;

        while curr != nil {
          var tmp = curr.next;
          delete curr;
          curr = tmp;
        }
      }
    }
  }
}

/*
  An unbounded queue that is distributed across nodes.
*/
class DistributedQueue : Queue {
  var targetLocDom : domain(1) = LocaleSpace;
  var targetLocales : [targetLocDom] locale = Locales;

  // Privatization id
  var pid : int;

  // Keeps track of which slot we are on...
  var globalHead : atomic uint;
  var globalTail : atomic uint;

  // To 'freeze' the queue, we must ensure that current mutating operations finish
  // first. However, at the same time we want to reduce communication by keeping
  // a task counter for each node that can be checked at next to no cost.
  var concurrentTasks : atomic uint;
  var frozenState : atomic bool;

  // We maintain an array of slots, wherein each slot is a pointer into a node's
  // address space. To maximize parallelism, we maintain numLocales * maxTaskPar
  // to reduce the amount of contention.
  var nSlots = here.maxTaskPar * targetLocales.size;
  var slotSpace = {0..#nSlots};
  var slots : [slotSpace] DistributedQueueSlot(eltType);

  proc DistributedQueue(type eltType, targetLocDom=LocaleSpace, targetLocales=Locales) {
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

  proc DistributedQueue(other, privData, type eltType = other.eltType) {
    nSlots = other.nSlots;
    slotSpace = other.slotSpace;
    slots = privData;
  }

  proc dsiPrivatize(privData) {
      return new DistributedQueue(this, privData);
  }

  proc dsiGetPrivatizeData() {
    return slots;
  }

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc add(elt : eltType) : bool {
    var localThis = getPrivatizedThis;
    ref _globalTail = globalTail;

    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() == true {
        localThis.concurrentTasks.sub(1);
        return false;
      }
    }

    var _nSlots : int;
    local { _nSlots = localThis.nSlots; }

    // Find a slot we can add to; skip over any with a negative size
    while true {
      var tail = (_globalTail.fetchAdd(1) % _nSlots : uint) : int;
      var slot : DistributedQueueSlot(eltType);
      local { slot = localThis.slots[tail]; }
      var sz = slot.size.fetchAdd(1);

      if sz >= 0 {
        slot.add(elt);
        local { localThis.concurrentTasks.sub(1); }
        return true;
      }
    }

    halt("Somehow broke out of add loop...");
  }

  proc remove() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() == true {
        localThis.concurrentTasks.sub(1);
        return (false, _defaultOf(eltType));
      }
    }

    // Find a slot we can take from; if the slot is empty, we bail as it is empty.
    var head = (globalHead.fetchAdd(1) % localThis.nSlots : uint) : int;
    var slot : DistributedQueueSlot(eltType);
    local { slot = localThis.slots[head]; }
    var sz = slot.size.fetchSub(1);

    // Nothing for us...
    if sz < 1 {
      local { localThis.concurrentTasks.sub(1); }
      return (false, _defaultOf(eltType));
    }

    // There is something for us
    var elt = slot.remove();
    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  proc isFrozen() : bool {
    return getPrivatizedThis.frozenState.read();
  }

  proc freeze() {
    coforall loc in Locales do on loc {
      var localThis = getPrivatizedThis;
      localThis.frozenState.write(true);
      localThis.concurrentTasks.waitFor(0);
    }
  }

  proc unfreeze() {
    coforall loc in Locales do on loc {
      var localThis = getPrivatizedThis;
      localThis.frozenState.write(false);
    }
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
    var head = globalHead.read() % nSlots;
    var [{0..#nSlots}] DistributedQueueSlotNode(eltType);
    for offset in 0 .. #nSlots {

    }
  }

  proc ~DistributedQueue() {
    var localThis = getPrivatizedThis;
    for slot in localThis.slots do delete slot;
  }
}
