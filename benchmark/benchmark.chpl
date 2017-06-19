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
// Whether or not we log communications and per-locale information.
config var logLocaleInfo = 0;

use IO;
use CommDiagnostics;
use DistributedFIFOQueue;
use DistributedQueue;
use Time;
use Random;

proc main() {

  // Enqueue
  var file = open("tmp/enqueue" + numLocales, iomode.cw);
  var writer = file.writer();

  var trialTime : [1 .. nTrials] real;
  // Obtain average time for enqueue...
  for i in 1 .. nTrials {
    // We only use one or the other, but we must declare both.
    // TODO: Have both implement some parent 'Queue' class/interface?
    var FIFO = new DistributedFIFOQueue(int);
    var MPMC = new DistributedQueue(int);

    var timer = new Timer();
    timer.start();

    if logLocaleInfo {
      resetCommDiagnostics();
      startCommDiagnostics();
    }
    coforall loc in Locales {
      on loc {
        if logLocaleInfo then writeln(here, " has started...");

        var iterations = if weak then nElements / numLocales else nElements;
        if isFIFO {
          // Helps with privitization/localization
          var descr = FIFO.getLocalDescriptor();
          var randStr = makeRandomStream(int);
          forall j in 1 .. iterations {
            FIFO.enqueue(j, descr);
            var nComps = nComputations + (randStr.getNext() % nJitter);
            for i in 1 .. nComps {
              // Hopefully compiler doesn't throw away?
              var x = sin(i);
              x = x + 1;
            }
          }
        } else {
          // Helps with privitization/localization
          var localQueue = MPMC.getLocalQueue();
          var randStr = makeRandomStream(int);
          forall j in 1 .. iterations {
            localQueue.enqueue(j);
            var nComps = nComputations + (randStr.getNext() % nJitter);
            for i in 1 .. nComps {
              // Hopefully compiler doesn't throw away?
              var x = sin(i);
              x = x + 1;
            }
          }
        }

        if logLocaleInfo then writeln(here, " has finished...");
      }
    }

    if logLocaleInfo {
      stopCommDiagnostics();
      writeln(getCommDiagnostics());
    }

    timer.stop();
    trialTime[i] = (if weak then nElements else numLocales * nElements) / timer.elapsed();
    writeln(i, "/", nTrials, ": ", (+ reduce trialTime) / i);
    delete FIFO;
    delete MPMC;
  }
  writer.write((+ reduce trialTime) / nTrials);
  writer.close();

  /*// Dequeue
  // Open file
  file = open("tmp/dequeue" + numLocales, iomode.cw);
  writer = file.writer();

  // Obtain average time for enqueue...
  for i in 1 .. nTrials {
    var queue = new Distributed_FIFO(int);
    var timer = new Timer();
    forall j in 1 .. nElements {
      queue.enqueue(j);
    }
    timer.start();
    forall j in 1 .. nElements {
      queue.dequeue();
    }
    timer.stop();
    trialTime[i] = nElements / timer.elapsed();
  }
  writer.write((+ reduce trialTime) / nTrials);
  writer.close();*/
}
