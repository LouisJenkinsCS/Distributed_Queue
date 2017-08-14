use DistributedBoundedQueue;
use DistributedQueue;
use DistributedBag;
use SynchronizedList;
use Collection;
use Benchmark;
use Plot;

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

  // DistributedBoundedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      benchTime = 10,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedQueue - Bounded",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedQueue(int, cap=bmd.totalOps, targetLocales=bmd.targetLocales);
      }
  );

  // DistributedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      benchTime = 10,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedQueue",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedQueue(int, targetLocales=bmd.targetLocales);
      }
  );

  // SynchronizedList - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      benchTime = 10,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new SynchronizedList(int);
      }
  );

  // DistributedBag - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : DistributedBag(int)).localBag;
        for i in 1 .. bd.iterations {
          c.add(i);
        }
      },
      benchTime = 10,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedBag(int);
      }
  );

  plotter.plot("Collections_Add_Benchmark");
}
