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
  var headLock : atomic bool;
  var tailLock : atomic bool;

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
    // Create note ahead of time to reduce overhead...
    var node = new DistributedQueueSlotNode(eltType, elt=elt);

    ref _tailLock = tailLock;
    // Contest for lock...
    while !_tailLock.testAndSet() do chpl_task_yield();

    // Append to tail...
    ref _tail = tail;
    _tail.next = node;
    _tail = node;

    // Release lock. This counts as a full memory barrier so the above will be
    // made visible to other nodes.
    _tailLock.write(false);
  }

  // Note, this should be *only* called after we know for a fact that there is an element
  // waiting for us...
  // TODO: Check performance using an 'on' statement...
  proc remove() : eltType {
    ref _headLock = headLock;
    // Contest for lock...
    while !_headLock.testAndSet() do chpl_task_yield();

    ref _head = head;
    var node = _head;
    var newHead = _head.next;

    // Another node hasn't finished it's write yet...
    while newHead == nil {
      newHead = _head.next;
    }
    _head = newHead;
    var elt = newHead.elt;

    // Release the lock and free resources...
    _headLock.write(false);

    delete node;
    return elt;
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
        return true;
      }
    }

    halt("Somehow broke out of add loop...");
  }

  proc remove() : (bool, eltType) {
    var localThis = getPrivatizedThis;

    // Find a slot we can take from; if the slot is empty, we bail as it is empty.
    var head = (globalHead.fetchAdd(1) % localThis.nSlots : uint) : int;
    ref slot = localThis.slots[head];
    var sz = slot.size.fetchSub(1);

    // Nothing for us...
    if sz < 1 {
      return (false, _defaultOf(eltType));
    }

    // There is something for us
    return (true, slot.remove());
  }
}
