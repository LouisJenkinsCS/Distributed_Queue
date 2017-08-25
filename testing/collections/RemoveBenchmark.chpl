use Collection;
use DistributedDeque;
use DistributedBag;
use SynchronizedList;
use Benchmark;
use Plot;

class BagWrapper {
  var bag : DistBag(int);
}

class DequeWrapper {
  var deque : DistDeque(int);
}

proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);

  // Collections share the same API and hence share the same benchFn and deinitFn
  var benchFn = lambda(bd : BenchmarkData) {
    var c = bd.userData : CollectionImpl(int);
    for i in 1 .. bd.iterations {
      var _ignored = c.remove();
    }
  };
  var deinitFn = lambda(obj : object) {
    delete obj;
  };

  // DistributedDeque - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : DequeWrapper).deque;
        for i in 1 .. bd.iterations {
          var _ignored = c.remove();
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedDeque",
      plotter = plotter,
      benchTime = 1,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistDeque(int, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return new DequeWrapper(c);
      }
  );

  // SynchronizedList - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = bd.userData : CollectionImpl(int);
        for i in 1 .. bd.iterations {
          var _ignored = c.remove();
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      benchTime = 1,
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new SynchronizedList(int);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return c;
      }
  );

  // DistributedBag - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : BagWrapper).bag;
        while true {
          var (hasElem, elem) = c.remove();
          if !hasElem then break;
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag",
      plotter = plotter,
      benchTime = 1,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistBag(int, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        c.balance();
        return new BagWrapper(c);
      }
  );

  plotter.plot("Collections_Remove_Benchmark");
}
