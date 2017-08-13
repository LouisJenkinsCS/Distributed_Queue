use Collection;
use DistributedBoundedQueue;
use DistributedQueue;
use DistributedBag;
use SynchronizedList;
use Benchmark;
use Plot;

proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);

  // Collections share the same API and hence share the same benchFn and deinitFn
  var benchFn = lambda(bd : BenchmarkData) {
    var c = bd.userData : Collection(int);
    for i in 1 .. bd.iterations {
      var _ignored = c.remove();
    }
  };
  var deinitFn = lambda(obj : object) {
    delete obj;
  };

  // DistributedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedQueue",
      plotter = plotter,
      benchTime = 10,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistributedQueue(int, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return c;
      }
  );

  // DistributedBoundedQueue - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBoundedQueue",
      plotter = plotter,
      benchTime = 10,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistributedBoundedQueue(int, cap=bmd.totalOps, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return c;
      }
  );

  // SynchronizedList - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      benchTime = 10,
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new SynchronizedList(int);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return c;
      }
  );

  // DistributedBag (Imbalanced) - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : DistributedBag(int)).localBag;
        for i in 1 .. bd.iterations {
          c.remove();
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag - Imbalanced",
      plotter = plotter,
      benchTime = 10,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistributedBag(int, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        return c;
      }
  );

  // DistributedBag (Balanced) - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var c = (bd.userData : DistributedBag(int)).localBag;
        for i in 1 .. bd.iterations {
          c.remove();
        }
      },
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "DistributedBag - Balanced",
      plotter = plotter,
      benchTime = 10,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistributedBag(int, targetLocDom=bmd.targetLocDom, targetLocales=bmd.targetLocales);
        coforall loc in bmd.targetLocales do on loc {
          forall i in 1 .. bmd.totalOps / bmd.targetLocales.size do c.add(i);
        }
        return c;
      }
  );

  plotter.plot("Collections_Remove_Benchmark");
}
