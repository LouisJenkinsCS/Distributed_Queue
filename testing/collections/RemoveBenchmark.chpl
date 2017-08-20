use Collection;
use DistributedDeque;
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
      benchName = "DistributedDeque",
      plotter = plotter,
      benchTime = 1,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var c = new DistributedDeque(int, targetLocales=bmd.targetLocales);
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
        var c = (bd.userData : DistributedBag(int)).getPrivatizedInstance();
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
        var c = new DistributedBag(int, targetLocales=bmd.targetLocales);
        forall i in 1 .. bmd.totalOps do c.add(i);
        c.balance();
        return c;
      }
  );

  plotter.plot("Collections_Remove_Benchmark");
}
