use DistributedBoundedQueue;
use SynchronizedList;
use Collection;
use Benchmark;
use Plot;

proc doBench(bd : BenchmarkData) {
  var c = bd.userData : Collection(int);
  for i in 1 .. bd.iterations {
    c.add(i);
  }
}

proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);
  /*class CollectionWrapper {
    var
    proc doesItInherit( type t, type checkType ) param {
      proc help( x: checkType) param return true;
      proc help( x ) param return false;
      var x:t; return help(x);
    }
  }*/

  // Collections share the same API and hence share the same benchFn and deinitFn
  // TODO: This will resolve to Collection.add instead of overloaded for some reason...
  var benchFn = lambda(bd : BenchmarkData) {
    var c = bd.userData : DistributedBoundedQueue(int);
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

  // SynchronizedList - Benchmark
  /*runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "SynchronizedList",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        return new SynchronizedList(int);
      }
  );*/

  plotter.plot("Collections_Add_Benchmark");
}
