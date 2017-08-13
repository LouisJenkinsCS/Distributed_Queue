use Collection.Queue;
use CyclicDist;
use CollectionsTest;
use NQueens;

config param DistributedBoundedQueue_DoubleCheckBounds = false;

// TODO: Make this convoy avoidant...

// Freeze statuses.
const FREEZE_UNFROZEN = 0;
const FREEZE_MARKED = 1;
const FREEZE_FROZEN = 2;

// Determines status of a slot.
const SLOT_EMPTY = 0;
const SLOT_FULL = 1;

record DistributedBoundedQueueSlot {
  type eltType;

  var elt : eltType;
  var status : atomic int;
  var isEnq : atomic bool;
  var isDeq : atomic bool;

  proc enq(elt : eltType) {
    on this {
      // Another enqueuer is waiting on this cell...
      while isEnq.testAndSet() {
        chpl_task_yield();
      }

      status.waitFor(SLOT_EMPTY);
      this.elt = elt;
      status.write(SLOT_FULL);

      isEnq.write(false);
    }
  }

  proc deq() : eltType {
    var _elt : eltType;

    on this {
      // Another dequeuer is waiting on this cell...
      while isDeq.testAndSet() do chpl_task_yield();

      status.waitFor(SLOT_FULL);
      _elt = elt;
      status.write(SLOT_EMPTY);

      isDeq.write(false);
    }

    return _elt;
  }
}

/*
  Bounded queue that is distributed across nodes.
*/
class DistributedBoundedQueue : BoundedQueue {
  var cap;
  var targetLocales;

  // Keeps track of which slot we are on...
  var globalHead : atomic uint;
  var globalTail : atomic uint;
  var queueSize : atomic int;

  // To 'freeze' the queue, we must ensure that current mutating operations finish
  // first. However, at the same time we want to reduce communication by keeping
  // a task counter for each node that can be checked at next to no cost.
  var concurrentTasks : atomic uint;
  var frozenState : atomic int;

  // per-locale data
  var eltSlotsSpace = {0..#cap};
  var eltSlotsDomain = eltSlotsSpace dmapped Cyclic(startIdx=eltSlotsSpace.low, targetLocales=targetLocales);
  var eltSlots : [eltSlotsDomain] DistributedBoundedQueueSlot(eltType);

  // Privatization id...
  var pid : int;

  proc DistributedBoundedQueue(type eltType, cap, targetLocales = Locales) {
    if cap == 0 then halt("Cap cannot be 0!");
    pid = _newPrivatizedClass(this);
  }


  proc DistributedBoundedQueue(other, type eltType = other.eltType, cap = 0, targetLocales=other.targetLocales) {
    // Avoid creating array...
    this.cap = other.cap;
  }

  proc dsiPrivatize(_ignored) {
      return new DistributedBoundedQueue(this);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc add(elt : eltType) : bool {
    var localThis = getPrivatizedThis;
    ref _queueSize = queueSize;
    ref _globalTail = globalTail;

    // Announce that we are currently using the queue...
    local {
      localThis.concurrentTasks.add(1);

      // Check if the queue is now 'immutable'.
      if localThis.frozenState.read() > FREEZE_UNFROZEN {
        localThis.concurrentTasks.sub(1);
        return false;
      }
    }
    // Fast path... Check if queue has space...
    if DistributedBoundedQueue_DoubleCheckBounds && _queueSize.read() >= localThis.cap {
      local { localThis.concurrentTasks.sub(1); }
      return false;
    }

    // Wait free approach...
    // If what was read is out of range, the queue is full and we bail early.
    // In the case that it is within a valid range, [0, cap), we commit. Note
    // that the cases where we increment the queueSize and bail is fixed by
    // dequeue operations.
    while true {
      var sz = _queueSize.fetchAdd(1);
      if sz >= localThis.cap {
        local { localThis.concurrentTasks.sub(1); }
        return false;
      } else if sz >= 0 {
        break;
      }
    }

    var tail = _globalTail.fetchAdd(1) % localThis.cap : uint;
    ref slot = eltSlots[tail : int];
    slot.enq(elt);

    local { localThis.concurrentTasks.sub(1); }
    return true;
  }

  proc remove() : (bool, eltType) {
    var localThis = getPrivatizedThis;
    ref _queueSize = queueSize;

    // Announce that we are currently using the queue...
    localThis.concurrentTasks.add(1);

    // Check if the queue is now 'immutable'.
    if localThis.frozenState.read() > FREEZE_UNFROZEN {
      localThis.concurrentTasks.sub(1);
      return (false, _defaultOf(eltType));
    }

    // Fast path... check if queue is empty...
    if DistributedBoundedQueue_DoubleCheckBounds && _queueSize.read() < 1 {
      localThis.concurrentTasks.sub(1);
      return (false, _defaultOf(eltType));
    }

    while true {
      var sz = _queueSize.fetchSub(1);
      if sz <= 0 {
        localThis.concurrentTasks.sub(1);
        return (false, _defaultOf(eltType));
      } else if sz <= localThis.cap {
        break;
      }
    }

    var head = globalHead.fetchAdd(1) % localThis.cap : uint;
    ref slot = eltSlots[head : int];
    var elt = slot.deq();

    local { localThis.concurrentTasks.sub(1); }
    return (true, elt);
  }

  // Very costly O(N) sequential search if unfrozen...
  proc contains(elt : eltType) : bool {
    var localThis = getPrivatizedThis;

    // Fast-Path: Can search concurrently safely...
    if isFrozen {
      var foundElt : atomic bool;
      forall idx in globalHead.read() .. #globalTail.read() {
        ref slot = eltSlots[(idx % localThis.cap : uint) : int];
        if slot.status.read() == SLOT_FULL {
          if slot.elt == elt then foundElt.write(true);
        }
      }

      return foundElt.read();
    }

    // Slow-Path: Need to do a slow sequential search. We do not do so concurrently
    // to avoid strangling concurrency in the queue, assuming lower priority.
    for idx in globalHead.read() .. #globalTail.read() {
      ref slot = eltSlots[(idx % localThis.cap : uint) : int];
      ref isDeq = slot.isDeq;
      ref status = slot.status;
      var foundElt : bool;

      if status.read() == SLOT_FULL {
        // Acquire dequeuer lock to ensure we can safely read without it being modified
        while isDeq.testAndSet() do chpl_task_yield();

        // Check if status changed in between...
        if status.read() == SLOT_FULL && slot.elt == elt {
          foundElt = true;
        }

        isDeq.write(false);
      }

      if foundElt {
        return true;
      }
    }

    return false;
  }

  proc capacity() {
    return cap;
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

  inline proc isFrozen {
    return getPrivatizedThis.frozenState.read();
  }

  // To clear the data structure, we must be sure to update the counter while
  // maintaining concurrent safety. The easiest way to do this is to just call remove.
  proc clear() {
    while remove()[1] do ;
  }

  proc size() : int {
    return max(0, queueSize.read());
  }

  proc isEmpty() : bool {
      return size() == 0;
  }

  iter these() : eltType {
    if !isFrozen {
      halt("Attempted to iterate while queue is not frozen...");
    }

    for idx in globalHead.read() .. #globalTail.read() {
      yield eltSlots[(idx % cap : uint) : int].elt;
    }
  }

  iter these(param tag : iterKind) where tag == iterKind.leader {
    if !isFrozen {
      halt("Attempted to iterate while queue is not frozen...");
    }

    forall slot in eltSlots {
      yield slot.elt;
    }
  }

  iter these(param tag : iterKind, followThis) where tag == iterKind.follower {
    yield followThis;
  }
}

proc main() {
  var space = {0..0};
  var arr : [space] locale;
  arr[0] = here;
  var dbq = new DistributedBoundedQueue(int, cap=100);
  counterTest(dbq);

  var cap = 1;
  for i in 1 .. NQueens.nQueens {
    cap *= i;
  }

  doNQueens(new DistributedBoundedQueue(26 * int, cap=cap));
}
