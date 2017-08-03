use Collection.Queue;
use CyclicDist;
use Time;
use Random;
use Plot;
use Benchmark;

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
  var concurrentTasksDom = targetLocales.domain dmapped Cyclic(startIdx=targetLocDom.low, targetLocales=targetLocales);
  var concurrentTasks : [concurrentTasksDom] atomic uint;
  var frozenState : [concurrentTasksDom] atomic bool;

  // per-locale data
  var eltSlotsSpace = {0..#cap};
  var eltSlotsDomain = eltSlotsSpace dmapped Cyclic(startIdx=eltSlotsSpace.low, targetLocales=targetLocales);
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
    var ourIdx = ourConcurrentTasksIndex;
    ref freezeBarrier = concurrentTasks[ourIdx];
    var _cap = cap;
    ref _queueSize = queueSize;
    ref _globalTail = globalTail;

    // Announce that we are currently using the queue...
    freezeBarrier.add(1);

    // Check if the queue is now 'immutable'.
    if frozenState[ourIdx].read() == true {
      freezeBarrier.sub(1);
      return false;
    }

    // Fast path... Check if queue has space...
    if _queueSize.read() >= _cap {
      freezeBarrier.sub(1);
      return false;
    }

    // Wait free approach...
    // If what was read is out of range, the queue is full and we bail early.
    // In the case that it is within a valid range, [0, cap), we commit. Note
    // that the cases where we increment the queueSize and bail is fixed by
    // dequeue operations.
    while true {
      var sz = _queueSize.fetchAdd(1);
      if sz >= _cap {
        freezeBarrier.sub(1);
        return false;
      } else if sz >= 0 {
        break;
      }
    }

    var head = _globalTail.fetchAdd(1) % _cap : uint;
    ref slot = eltSlots[head : int];
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
    freezeBarrier.sub(1);
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
      var head = globalHead.fetchAdd(1) % cap : uint;
      ref slot = eltSlots[head : int];
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

  // FreezeBarrier
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = bd.userData : DistributedBoundedQueue(int);
        for i in 1 .. bd.iterations {
          var ourIdx = c.ourConcurrentTasksIndex;
          ref freezeCounter = c.concurrentTasks[ourIdx];
          freezeCounter.add(1);

          if c.frozenState[ourIdx].read() == true {
            freezeCounter.sub(1);
            continue;
          }

          freezeCounter.sub(1);
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "FreezeBarrier",
      plotter = plotter,
      initFn = initFn
  );

  // Bounds Check
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = bd.userData : DistributedBoundedQueue(int);
        for i in 1 .. bd.iterations {
          ref queueSize = c.queueSize;
          var cap = c.cap;
          if queueSize.read() >= cap {
            continue;
          }

          while true {
            var sz = queueSize.fetchAdd(1);
            if sz >= cap {
              continue;
            } else if sz >= 0 {
              break;
            }
          }
        }
      },
      deinitFn = deinitFn,
      targetLocales = targetLocales,
      benchName = "BoundsCheck",
      plotter = plotter,
      initFn = initFn
  );

  // Slot Check...
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = bd.userData : DistributedBoundedQueue(int);
        for i in 1 .. bd.iterations {
          var head = c.globalHead.fetchAdd(1) % c.cap : uint;
          ref slot = c.eltSlots[head : int];
          ref status = slot.status;
          ref isEnq = slot.isEnq;

          // Another enqueuer is waiting on this cell...
          while isEnq.testAndSet() {
            writeln("Waiting on another enqueuer...");
            chpl_task_yield();
          }

          status.waitFor(SLOT_EMPTY);
          slot.elt = 0;
          status.write(SLOT_FULL);

          isEnq.write(false);
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SlotCheck",
      plotter = plotter,
      initFn = initFn
  );

  plotter.plot("DistributedBoundedQueue_Bottleneck");
}
