use Collection.Queue;
use BlockDist;
use Time;
use Random;

record DistributedBoundedFIFOSlot {
  type eltType;

  var elt : eltType;
  var status : atomic int;
  var isEnq : atomic bool;
  var isDeq : atomic bool;
}

// Determines status of a slot.
const SLOT_EMPTY = 0;
const SLOT_FULL = 1;

/*
  Bounded queue that is distributed across nodes.
*/
class DistributedBoundedQueue : BoundedQueue {
  var cap : int;

  var targetLocDom : domain(1) = LocaleSpace;
  var targetLocales: [targetLocDom] locale = Locales;
  // Two monotonically increasing counters used in deciding which locale to choose from
  var globalHead : atomic uint;
  var globalTail : atomic uint;
  var queueSize : atomic int;

  // To 'freeze' the queue, we must ensure that current mutating operations finish
  // first. However, at the same time we want to reduce communication by keeping
  // a task counter for each node that can be checked at next to no cost.
  var concurrentTasksDom = targetLocales.domain dmapped Block(boundingBox=targetLocales.domain, targetLocales=targetLocales);
  var concurrentTasks : [concurrentTasksDom] atomic uint;
  var frozenState : [concurrentTasksDom] atomic bool;

  // per-locale data
  var eltSlotsSpace = {0..#cap};
  var eltSlotsDomain = eltSlotsSpace dmapped Block(boundingBox=eltSlotsSpace, targetLocales=targetLocales);
  var eltSlots : [eltSlotsDomain] DistributedBoundedFIFOSlot(eltType);

  proc DistributedBoundedQueue(type eltType) {
    if cap == 0 then halt("Cap cannot be 0!");
  }

  inline proc ourConcurrentTasksIndex {
    return concurrentTasksDom.localSubdomain().first;
  }

  inline proc enterFreezeBarrier() {
    concurrentTasks[ourConcurrentTasksIndex].add(1);
  }

  inline proc exitFreezeBarrier() {
    concurrentTasks[ourConcurrentTasksIndex].sub(1);
  }

  proc add(elt : eltType) : bool {
    // Announce that we are currently using the queue...
    enterFreezeBarrier();

    // Check if the queue is now 'immutable'.
    if frozenState[ourConcurrentTasksIndex].read() == true {
      exitFreezeBarrier();
      return false;
    }

    // Fast path... Check if queue has space...
    if queueSize.read() >= cap {
      concurrentTasks[ourConcurrentTasksIndex].sub(1);
      return false;
    }

    // Wait free approach...
    // If what was read is out of range, the queue is full and we bail early.
    // In the case that it is within a valid range, [0, cap), we commit. Note
    // that the cases where we increment the queueSize and bail is fixed by
    // dequeue operations.
    while true {
      var sz = queueSize.fetchAdd(1);
      if sz >= cap {
        exitFreezeBarrier();
        return false;
      } else if sz >= 0 {
        break;
      }
    }

    var head = globalHead.fetchAdd(1) % cap : uint;
    ref slot = eltSlots[head : int];

    // Another enqueuer is waiting on this cell...
    while slot.isEnq.testAndSet() {
      writeln("Waiting on another enqueuer...");
      chpl_task_yield();
    }

    slot.status.waitFor(SLOT_EMPTY);
    slot.elt = elt;
    slot.status.write(SLOT_FULL);

    slot.isEnq.write(false);
    exitFreezeBarrier();
    return true;
  }

  proc remove() : (bool, eltType) {
    // Announce that we are currently using the queue...
    enterFreezeBarrier();

    // Check if the queue is now 'immutable'.
    if frozenState[ourConcurrentTasksIndex].read() == true {
      exitFreezeBarrier();
      return (false, _defaultOf(eltType));
    }

    // Fast path... check if queue is empty...
    if queueSize.read() < 1 {
      exitFreezeBarrier();
      return (false, _defaultOf(eltType));
    }

    while true {
      var sz = queueSize.fetchSub(1);
      if sz <= 0 {
        exitFreezeBarrier();
        return (false, _defaultOf(eltType));
      } else if sz <= cap {
        break;
      }
    }

    while true {
      var tail = globalTail.fetchAdd(1) % cap : uint;
      ref slot = eltSlots[tail : int];
      // Another dequeuer is waiting on this cell...
      while slot.isDeq.testAndSet() do chpl_task_yield();

      slot.status.waitFor(SLOT_FULL);
      var elt = slot.elt;
      slot.status.write(SLOT_EMPTY);

      slot.isDeq.write(false);
      exitFreezeBarrier();
      return (true, elt);
    }

    halt("Broke out of dequeue loop...");
  }

  proc freeze() {
    forall state in frozenState do state.write(true);

    // Wait for all ongoing tasks to finish. Any new tasks will see the new state.
    forall counter in concurrentTasks do counter.waitFor(0);
  }

  proc unfreeze() {
    forall state in frozenState do state.write(false);
  }

  // TODO: Allow this to be parallel-safe with respect to the freezing operation.
  // Such as adding a second state after we know all concurrent tasks have exited.
  inline proc isFrozen {
    return frozenState[ourConcurrentTasksIndex].read();
  }

  iter these() : eltType {
    if !isFrozen {
      halt("Attempted to iterate while queue is not frozen...");
    }

    for idx in globalTail.read() .. #globalHead.read() {
      yield eltSlots[(idx % cap : uint) : int].elt;
    }
  }
}
