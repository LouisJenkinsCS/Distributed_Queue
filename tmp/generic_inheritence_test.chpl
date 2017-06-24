// Causes Segfault...
use Queue;
use DistributedFIFOQueue;
use Random;


proc main() {
  // Compiler crashed with segfault if we do...
  // var queue : Queue(26 * int) = new DistributedFIFOQueue(26 * int);
  var queue : Queue(26 * int) = new DistributedFIFOQueue(26 * int);
  var randStr = makeRandomStream(int);
  coforall loc in Locales do on loc do
    coforall tid in 0 .. #here.maxTaskPar {
      for i in 1 .. 100000 {
        if randStr.getNext() % 2 {
          writeln("Enqueue...");
          queue.enqueue(_defaultOf(26 * int));
        } else {
          writeln("Dequeue...");
          queue.dequeue();
        }
      }
    }
}
