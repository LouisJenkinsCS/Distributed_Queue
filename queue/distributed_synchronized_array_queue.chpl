use CyclicDist;
use Barrier;
use Time;

record SyncDistrQueueNode {
  type t;
  var element : t;
  var busy : atomic bool;
}

class SyncDistrQueue {
  type t;
  var size: int = 1024;
  var domainMapping = {1..size};
  var cyclicDomain = domainMapping dmapped Cyclic(startIdx=domainMapping.low);
  var buffer: [cyclicDomain] QueueNode(t);
  var head: int = 1;
  var tail: int = 1;
  var default: t;
  var lock$: sync bool;

  proc enqueue(element: t) : bool {
    lock$.writeEF(true);
    // Full
    if (max(1, (tail + 1) % size) == head) {
      lock$.reset();
      return false;
    }

    ref node : QueueNode(t) = buffer[tail];
    // Wait until operation finishes if one is still in progress...
    if (node.busy.read()) {
      node.busy.waitFor(false);
    }

    // Mark as being ours now and release lock so next task can proceed
    node.busy.write(true);
    tail = max(1, (tail + 1) % size);
    lock$.reset();

    // Write
    node.element = element;
    node.busy.write(false);
    return true;
  }

  proc dequeue() : (bool, t) {
    lock$.writeEF(true);
    // Empty
    if (tail == head) {
      lock$.reset();
      return (false, default);
    }

    ref node : QueueNode(t) = buffer[head];
    var element : t;
    on node {
      // Wait until operation finishes if one is still in progress
      if (node.busy.read()) {
        writeln(here, ": Node owned on ", node.locale);
        node.busy.waitFor(false);
      }

      // Mark as being ours now and release lock so next task can proceeed
      node.busy.write(true);
      head = max(1, (head + 1) % size);
      lock$.reset();

      // Element must be obtained by value as it is liable to change after we unmark
      element = node.element;
      node.busy.write(false);
    }
    return (true, element);
  }
}

writeln("Starting...");

proc proofOfCorrectness() {
  var timer = new Timer();
  var Q : Queue(int) = new Queue(int);
  var counter : atomic int;
  counter.write(Q.size);
  var go : atomic bool;

  timer.start();
  [i in 1..Q.size] {
      Q.enqueue(i);
      if (counter.fetchSub(1) == 1) {
        go.write(true);
      }
  }

  go.waitFor(true);
  counter.write(Q.size);
  go.write(false);

  writeln("Enqueued in ", timer.elapsed(), " seconds...");
  [i in 1..Q.size] {
      var elem = Q.dequeue();
      if (counter.fetchSub(1) == 1) {
        go.write(true);
      }
  }

  go.waitFor(true);
  timer.stop();

  writeln("Done processing ", Q.size, " elements in ", timer.elapsed(), " seconds!");
}

proofOfCorrectness();
