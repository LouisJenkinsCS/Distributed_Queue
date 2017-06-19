config var nElements = 44 * 1024 * 1024;
config var nTrials = 10;
config var step = 1;
config var weak = 1;
config var isFIFO = 0;

use IO;
use CommDiagnostics;
use DistributedFIFOQueue;
use DistributedQueue;
use Time;

proc main() {

  // Enqueue
  var file = open("tmp/enqueue" + numLocales, iomode.cw);
  var writer = file.writer();

  var trialTime : [1 .. nTrials] real;
  // Obtain average time for enqueue...
  for i in 1 .. nTrials {
    // We only use one or the other because compiler cannot infer type
    var FIFO = new DistributedFIFOQueue(int);
    var MPMC = new DistributedQueue(int);

    var timer = new Timer();
    timer.start();

    resetCommDiagnostics();
    startCommDiagnostics();
    coforall loc in Locales {
      on loc {
        writeln(here, " has started...");
        var iterations = if weak then nElements / numLocales else nElements / 44;
        if isFIFO {
          var descr = FIFO.getLocalDescriptor();
          forall j in 1 .. iterations {
            FIFO.enqueue(j, descr);
          }
        } else {
          var localQueue = MPMC.getLocalQueue();
          forall j in 1 .. iterations {
            localQueue.enqueue(j);
          }
        }
        writeln(here, " has finished...");
      }
    }
    stopCommDiagnostics();
    writeln(getCommDiagnostics());


    timer.stop();
    trialTime[i] = (if weak then nElements else numLocales * (nElements / 44)) / timer.elapsed();
    write("\n", i, "/", nTrials, ": ", (+ reduce trialTime) / i);
    delete FIFO;
    delete MPMC;
  }
  writer.write((+ reduce trialTime) / nTrials);
  writer.close();
/*
  // Dequeue
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
