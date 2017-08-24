use DistributedDeque;
use DistributedBag;
use SynchronizedList;
use Benchmark;
use Plot;

class BagWrapper {
  var bag : DistBag(int);
}

proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);

  // Collections share the same API and hence share the same benchFn and deinitFn
  var benchFn = lambda(bd : BenchmarkData) {
    var c = bd.userData : Collection(int);
    for i in 1 .. bd.iterations {
      c.add(i);
    }
  };
  var deinitFn = lambda(obj : object) {
    delete obj;
  };

  // SynchronizedList - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      benchTime = 1,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new SynchronizedList(int);
      }
  );

  // DistributedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      benchTime = 1,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedDeque",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedDeque(int, targetLocales=bmd.targetLocales);
      }
  );

  // DistributedBag - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : BagWrapper).bag;
        for i in 1 .. bd.iterations {
          c.add(i);
        }
      },
      benchTime = 1,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new BagWrapper(new DistBag(int, targetLocales=bmd.targetLocales));
      }
  );

  plotter.plot("Collections_Add_Benchmark");
}
