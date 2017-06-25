// Number of elements to distribute across clusters. We choose 44 million as we're
// using Haswell currently and it has 44 HPC clusters at our disposal. For 'strong'
// scaling, this should likely be changed.
config var nElements = 44 * 1024 * 1024;
// Number of trials to run (and take the average of)
config var nTrials = 10;
// Number of computations per queue operation. This is used to introduce some
// variation that can help reduce contention on the queue (and emulate a more
// realistic workload)
config var nComputations = 0;
// The 'jitter' that causes variations in number of computations per second. In this
// way, the number of computations per operation is 'nComputations ± nJitter'.
config var nJitter = 0;
// Whether or not we are 'weak' scaling, as in we keep the workload the same but distribute
// it as we increase in the number of locales, or 'strong' in that we keep the number
// of elements per locale the same.
config var weak = 1;
// Determines if we test strictly FIFO or work stealing MPMC queue.
config var isFIFO = 0;
config var isMPMC = 0;
config var isSync = 0;
config var isCCSynch = 0;
// Whether or not we log communications and per-locale information.
config var logLocaleInfo = 0;
config var verboseLog = 0;

use IO;
use CommDiagnostics;
use CCQueue;
use DistributedFIFOQueue;
use DistributedQueue;

use Time;
use Random;

inline proc getQueue() : Queue(int) {
  if isFIFO {
    return new DistributedFIFOQueue(int);
  } else if isMPMC {
    return new DistributedQueue(int);
  } else if isSync {
    return new SyncQueue(int);
  } else if isCCSynch {
    return new CCQueue(int);
  } else {
    halt("Requires one of the flags to be set: '--isFIFO', '--isMPMC', '--isSync', or '--isCCSynch'");
  }
}

proc main() {
  // Setup...
  var enqueueFile = open("tmp/enqueue" + numLocales, iomode.cw);
  var dequeueFile = open("tmp/dequeue" + numLocales, iomode.cw);
  var enqueueWriter = enqueueFile.writer();
  var dequeueWriter = dequeueFile.writer();
  var enqueueTrialTime : [1 .. nTrials] real;
  var dequeueTrialTime : [1 .. nTrials] real;

  // Obtain average time for enqueue followed by dequeued...
  for i in 1 .. nTrials {
    // We only use one or the other, but we must declare both.
    // TODO: Have both implement some parent 'Queue' class/interface?
    var queue = getQueue();
    var timer = new Timer();
    timer.start();

    if logLocaleInfo {
      resetCommDiagnostics();
      if verboseLog then startVerboseComm();
      startCommDiagnostics();
    }

    coforall loc in Locales do on loc {
      if logLocaleInfo then writeln(here, " has started Enqueue...");
      var iterations = if weak then nElements / numLocales else nElements;

      coforall tid in 0 .. #here.maxTaskPar {
        var x : atomic int;
        var randStr = makeRandomStream(int);
        for j in 1 .. iterations / here.maxTaskPar {
          queue.enqueue(j);
          var nComps = nComputations + (if nJitter then (randStr.getNext() % nJitter) else 0);
          for i in 1 .. nComps {
            // Hopefully compiler doesn't throw away?
            x.write(sin(i) : int);
          }
        }
      }

      if logLocaleInfo then writeln(here, " has finished Enqueue...");

    }

    if logLocaleInfo {
      if verboseLog then stopVerboseComm();
      stopCommDiagnostics();
      writeln(getCommDiagnostics());
    }

    timer.stop();
    enqueueTrialTime[i] = (if weak then nElements else numLocales * nElements) / timer.elapsed();
    writeln(i, "/", nTrials, ": ", (+ reduce enqueueTrialTime) / i);


    // Dequeue portion...
    timer.clear();
    timer.start();

    if logLocaleInfo {
      resetCommDiagnostics();
      if verboseLog then startVerboseComm();
      startCommDiagnostics();
    }
    coforall loc in Locales do on loc {
      if logLocaleInfo then writeln(here, " has started Dequeue...");
      var iterations = if weak then nElements / numLocales else nElements;

      coforall tid in 0 .. #here.maxTaskPar {
        var x : atomic int;
        var randStr = makeRandomStream(int);
        for j in 1 .. iterations / here.maxTaskPar {
          queue.dequeue();
          var nComps = nComputations + (if nJitter then (randStr.getNext() % nJitter) else 0);
          for i in 1 .. nComps {
            // Hopefully compiler doesn't throw away?
            x.write(sin(i) : int);
          }
        }
      }

      if logLocaleInfo then writeln(here, " has finished Dequeue...");

    }

    if logLocaleInfo {
      if verboseLog then stopVerboseComm();
      stopCommDiagnostics();
      writeln(getCommDiagnostics());
    }

    timer.stop();
    dequeueTrialTime[i] = (if weak then nElements else numLocales * nElements) / timer.elapsed();
    writeln(i, "/", nTrials, ": ", (+ reduce dequeueTrialTime) / i);

    delete queue;
    /*delete MPMC;*/
  }
  enqueueWriter.write((+ reduce enqueueTrialTime) / nTrials);
  dequeueWriter.write((+ reduce dequeueTrialTime) / nTrials);
  enqueueWriter.close();
  dequeueWriter.close();
}
