use Time;

record BenchmarkResult {
  // Time in seconds requested units...
  var time : real;
  // The requested units... needed for calculating 'opsPerSec'
  var unit : TimeUnits;
  // Number of operations performed...
  var operations : int;

  inline proc timeInSeconds {
      select unit {
        when TimeUnits.microseconds do return time *    1.0e-6;
        when TimeUnits.milliseconds do return time *    1.0e-3;
        when TimeUnits.seconds      do return time;
        when TimeUnits.minutes      do return time *   60.0;
        when TimeUnits.hours        do return time * 3600.0;
    }

    halt("TimeUnit ", unit, " is not supported...");
  }

  inline proc opsPerSec {
    return operations / timeInSeconds;
  }
}

record BenchmarkData {
  // User created data from 'initFn' which also gets cleaned up in 'deinitFn'.
  var userData : object;
  // Number of iterations to run for this task...
  var iterations : int;
}

// Runs a benchmark and returns the result for the target number of locales.
proc runBenchmark(
  benchFn : func(BenchmarkData, void),
  benchTime : real = 5,
  unit: TimeUnits = TimeUnits.seconds,
  initFn : func(object) = nil,
  deinitFn : func(object, void) = nil,
  targetLocales : [?targetLocDom] = Locales,
  isWeakScaling : bool = false
) : BenchmarkResult {
  // Assertion
  if benchFn == nil {
    halt("'benchFn' must be non-nil!");
  }

  // Find the 'sweet-spot' for this benchmark that runs for specified amount of time.
  var n = 1;
  var timer = new Timer();
  while n < 1e12 {
    writeln("N=", n);

    var benchData : BenchmarkData;
    var totalOps = if isWeakScaling then n * here.maxTaskPar else n;
    benchData.iterations = totalOps / here.maxTaskPar;
    if initFn {
      benchData.userData = initFn();
    }

    timer.clear();
    timer.start();

    coforall loc in targetLocales do on loc {
      coforall tid in 0..#here.maxTaskPar {
        benchFn(benchData);
      }
    }

    timer.stop();
    if deinitFn {
      deinitFn(benchData.userData);
    }

    if timer.elapsed(unit) >= benchTime {
      return new BenchmarkResult(time=timer.elapsed(unit), unit=unit, operations=totalOps);
    }

    n = n * 2;
  }

  halt("Exceeded 'n' of 1e12...");
}

// Runs multiple benchmarks for the specified tuple of targetLocales and and returns an array of results.
/*proc runBenchmarkMultiple(
  benchFn : func(BenchmarkData, void),
  time : real,
  targetLocales,
  unit: TimeUnits = TimeUnits.seconds,
  initFn : func(B, void) = nil,
  deinitFn : func(B, void) = nil,
  days : int = 0,
  hours : int = 0,
  minutes : int = 0,
  seconds : int = 30,
  milliseconds : int = 0,
  microseconds : int = 0
) {
  // TODO
}*/


proc benchmarkAtomics() {
  class atomicCounter { var c : atomic uint; }
  var result = runBenchmark(
      benchFn = lambda(bd : BenchmarkData) {
        var counter = bd.userData : atomicCounter;
        for i in 1 .. bd.iterations {
            counter.c.fetchAdd(1);
        }
      },
      initFn = lambda() : object {
        return new atomicCounter();
      },
      deinitFn = lambda(obj : object) {
        delete obj;
      }
  );
  writeln(result.opsPerSec);
}

proc main() {
  benchmarkAtomics();
}
