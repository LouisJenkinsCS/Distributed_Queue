use Benchmark;
use Plot;
use BlockDist;
use CyclicDist;

proc main() {
  var plotter : Plotter(int, real);
  var targetLocales = (1,2,4,8,16,32,64);
  class DistWrapper {
    var dom : domain(1) = LocaleSpace;
    var arr : [dom] int = Locales;
  }

  // Both distributions are accessed in the same way and so share the same benchFn
  var benchFn = lambda(bd : BenchmarkData) {
    ref arr = (bd.userData : DistWrapper).arr;
    for i in 1 .. bd.iterations {
      arr[i] = i;
    }
  };
  var deinitFn = lambda(obj : object) {
    delete obj;
  };

  // BlockDist - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "BlockDist",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var space = {0..#bmd.totalOps};
        var dom : domain(1) = space dmapped Block(boundingBox=space, targetLocales=bmd.targetLocales);
        var arr : [dom] int;
        return new DistWrapper(dom = dom, arr = arr);
      }
  );

  // CyclicDist - Benchmark
  runBenchmarkMultiplePlotted(
      benchFn = benchFn,
      deinitFn = deinitFn,
      targetLocales=targetLocales,
      benchName = "CyclicDist",
      plotter = plotter,
      initFn = lambda (bmd : BenchmarkMetaData) : object {
        var space = {0..#bmd.totalOps};
        var dom : domain(1) = space dmapped Cyclic(startIdx=space.low, targetLocales=bmd.targetLocales);
        var arr : [dom] int;
        return new DistWrapper(dom = dom, arr = arr);
      }
  );

  plotter.plot("BlockVsCyclicDist");
}
