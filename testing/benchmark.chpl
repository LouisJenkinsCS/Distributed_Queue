use Time;

class B {
  // Number of iterations for the current benchmark to run...
  var N : int;
  // Some function that will setup data for the benchmark
  var initFn : func(B, void);
  // Some function that will cleanup the data after finished
  var deinitFn : func(B, void);
  // Data initialized by initFn...
  var data : object;
  // Whether we are 'weak scaling' or not; if we are, we delegate 'N' elements per node...
  var isWeakScaling : bool;
  //  Number of locales to use...
  var nLocales = numLocales;

  // Determines the max time to run the benchmark for...
  var maxDays = 0;
  var maxHours = 0;
  var maxMinutes = 0;
  var maxSeconds = 30;
  var maxMilliseconds = 0;
  var maxMicroseconds = 0;

  // Function to benchmark...
  var benchFn : func(B, void);
  var timer : Timer;

  inline proc nanoseconds {
    var ns : int(64);

    // Days
    ns = maxDays * 86400000000000;
    // Hours
    ns = ns + maxHours * 3600000000000;
    // Minutes
    ns = ns + maxMinutes * 60000000000;
    // Seconds
    ns = ns + maxSeconds * 1000000000;
    // Milliseconds
    ns = ns + maxMilliseconds * 1000000;
    // Microseconds
    ns = ns + maxMicroseconds * 1000;

    return ns;
  }

  proc run() {
    if benchFn == nil {
      halt("'benchFn' must be non-nil!");
    }
    var targetLocDom = {0..#nLocales};
    var targetLocales : [targetLocDom] locale;
    for idx in targetLocDom do targetLocales[idx] = Locales[idx];

    var n = 1;
    while n < 1e9 {
      writeln("N=", n);
      N = n;
      if initFn then initFn(this);
      timer.clear();
      timer.start();

      coforall loc in targetLocales do on loc {
        coforall tid in 0..#here.maxTaskPar {
          benchFn(this);
        }
      }

      timer.stop();
      if deinitFn then deinitFn(this);

      if (timer.elapsed(TimeUnits.microseconds) * 1000) >= nanoseconds {
        writeln("Finished in ", timer.elapsed(), " seconds");
        writeln("Ns/Op: ", (timer.elapsed(TimeUnits.microseconds) * 1000) / N);
        writeln("Ops/Sec: ", N / ((timer.elapsed(TimeUnits.microseconds) * 1000) * 1e-9));
        return;
      }

      n = n * 2;
    }
  }
}
