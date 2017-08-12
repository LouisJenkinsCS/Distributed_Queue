use Collection.Queue;
use CyclicDist;
use Time;
use Random;
use Plot;
use Benchmark;

config param DistributedBoundedQueue_DoubleCheckBounds = false;

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

  // Keeps track of which slot we are on...
  var globalHead : atomic uint;
  var globalTail : atomic uint;
  var queueSize : atomic int;

  // To 'freeze' the queue, we must ensure that current mutating operations finish
  // first. However, at the same time we want to reduce communication by keeping
  // a task counter for each node that can be checked at next to no cost.
  var concurrentTasks : atomic uint;
  var frozenState : atomic bool;

  // per-locale data
  var eltSlotsSpace = {0..#cap};
  var eltSlotsDomain = eltSlotsSpace dmapped Cyclic(startIdx=eltSlotsSpace.low, targetLocales=targetLocales);
  var eltSlots : [eltSlotsDomain] DistributedBoundedFIFOSlot(eltType);

  // Privatization id...
  var pid : int;

  proc DistributedBoundedQueue(type eltType, cap = 0, targetLocDom = LocaleSpace, targetLocales = Locales) {
    if cap == 0 then halt("Cap cannot be 0!");
    pid = _newPrivatizedClass(this);
  }


  proc DistributedBoundedQueue(other, type eltType = other.eltType, cap = other.cap, eltSlotsSpace = {0..-1}) {
  }

  proc dsiPrivatize(_ignored) {
      return new DistributedBoundedQueue(this);
  }

  proc dsiGetPrivatizeData() {
    return eltSlots;
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
      if localThis.frozenState.read() == true {
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
    ref status = slot.status;
    ref isEnq = slot.isEnq;

    // Another enqueuer is waiting on this cell...
    while isEnq.testAndSet() {
      writeln("Waiting on another enqueuer...");
      chpl_task_yield();
    }

    status.waitFor(SLOT_EMPTY);
    slot.elt = elt;
    status.write(SLOT_FULL);

    isEnq.write(false);
    local { localThis.concurrentTasks.sub(1); }
    return true;
  }

  proc remove() : (bool, eltType) {
    var localThis = getPrivatizedThis;
    ref _queueSize = queueSize;

    // Announce that we are currently using the queue...
    localThis.concurrentTasks.add(1);

    // Check if the queue is now 'immutable'.
    if localThis.frozenState.read() == true {
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
    ref status = slot.status;
    ref isDeq = slot.isDeq;

    // Another dequeuer is waiting on this cell...
    while isDeq.testAndSet() do chpl_task_yield();

    status.waitFor(SLOT_FULL);
    var elt = slot.elt;
    status.write(SLOT_EMPTY);

    isDeq.write(false);
    localThis.concurrentTasks.sub(1);
    return (true, elt);
  }

  proc capacity() {
    return cap;
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

  inline proc isFrozen {
    return getPrivatizedThis.frozenState.read();
  }

  iter these() : eltType {
    if !isFrozen {
      halt("Attempted to iterate while queue is not frozen...");
    }

    for idx in globalTail.read() .. #globalHead.read() {
      yield eltSlots[(idx % cap : uint) : int].elt;
    }
  }

  iter these(param tag : iterKind) where tag = iterKind.leader {
    if !isFrozen {
      halt("Attempted to iterate while queue is not frozen...");
    }

    forall slot in eltSlots {
      yield slot.elt;
    }
  }

  iter these(param tag : iterKind, followThis) where tag = iterKind.follower {
    yield followThis;
  }
}


proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);
  var seconds = 30 : real;

  var benchFn = lambda(bd : BenchmarkData) {
    var c = bd.userData : DistributedBoundedQueue(int);
    for i in 1 .. bd.iterations {
      c.add(i);
    }
  };
  var deinitFn = lambda(obj : object) {
    delete obj;
  };
  var initFn = lambda (bmd : BenchmarkMetaData) : object {
    return new DistributedBoundedQueue(int, cap=bmd.totalOps, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
  };

  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBoundedQueue",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedBoundedQueue(int, cap=bmd.totalOps, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
      }
  );

  plotter.plot("DistributedBoundedQueue_Performance");
}
