use DistributedBoundedQueue;
use DistributedQueue;
use DistributedList;
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
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBoundedQueue",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedBoundedQueue(int, cap=bmd.totalOps, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
      }
  );

  // DistributedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedQueue",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedQueue(int, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
      }
  );

  // SynchronizedList - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new SynchronizedList(int);
      }
  );

  // Compiler BUG: Generic Lambda issue...
  // DistributedList - Benchmark
  /*runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedList",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedList(int);
      }
  );*/

  // DistributedBag - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedBag(int);
      }
  );

  // DistributedBag (w/ Localization) - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : DistributedBag(int)).localBag;
        for i in 1 .. bd.iterations {
          c.add(i);
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag with Localization",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new DistributedBag(int);
      }
  );

  plotter.plot("Collections_Add_Benchmark");
}
