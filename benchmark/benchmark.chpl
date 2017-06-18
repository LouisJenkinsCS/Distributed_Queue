config var nElements = 44 * 1024 * 1024;
config var nTrials = 10;
config var step = 1;
config var weak = 1;

use IO;
use CommDiagnostics;
use DistributedQueue;
use Time;

proc main() {

  // Enqueue
  var file = open("tmp/enqueue" + numLocales, iomode.cw);
  var writer = file.writer();

  var trialTime : [1 .. nTrials] real;
  // Obtain average time for enqueue...
  for i in 1 .. nTrials {
    var queue = new DistributedQueue(int);
    var timer = new Timer();
    timer.start();

    coforall loc in Locales {
      on loc {
        writeln(here, " has started...");
        var iterations = if weak then nElements / numLocales else nElements / 44;
        var localQueue = queue.getLocalQueue();
        forall j in 1 .. iterations {
          localQueue.enqueue(j);
        }
        writeln(here, " has finished...");
      }
    }


    timer.stop();
    trialTime[i] = (if weak then nElements else numLocales * (nElements / 44)) / timer.elapsed();
    write("\n", i, "/", nTrials, ": ", (+ reduce trialTime) / i);
    delete queue;
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
