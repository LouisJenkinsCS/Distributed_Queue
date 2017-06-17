use BigInteger;
use Time;

class ccnode {
  // User-defined request object
  var request : object;
  // User-defined result object
  var retval : object;
  // What we are spinning on.
  var wait : atomic bool;
  // Is our operation completed? We only check this variable if we are not waiting,
  // and if it is not complete then we become the combiner thread.
  var completed : bool;
  // Next in the queue.
  var next : ccnode;
}

// Remove strict data types, let compiler infer...
class cclock {
  // The shared data to be protected and operated on.
  var data : object;
  // Request dispatcher function to provide a more reusable approach.
  // First Arg: Shared data to be operated on
  // Second Arg: Request object
  // Return Value: User-Defined
  // (Data, Request) -> RetVal
  var dispatcher : func(object, object, object);

  // The number of requests to serve until you switch to a new combiner...
  var maxRequests : int = 8;

  // Pointer to tail... Note that this must be local. Added bonus to allowing
  // a more polymorphic type, as we can point to any type of 'ccnode'
  var _tail : atomic uint(64);

  // TODO: Constructor for some reason will *not* be called, no matter what I try
  proc cclock(data, dispatcher, maxRequests = 8) {
    // Create with dummy node.
    var dummyNode = new ccnode();
    _tail.write(__primitive("cast", uint, dummyNode));
  }

  proc initializer(data, dispatcher, maxRequests = 8) {
    // Constructor...
    this.data = data;
    this.dispatcher = dispatcher;
    this.maxRequests = maxRequests;

    // Create with dummy node.
    var dummyNode = new ccnode();
    _tail.write(__primitive("cast", uint, dummyNode));
  }

  // TODO: Local
  proc ccsync(request : object) : object {
    var counter = 0;
    var nextNode = new ccnode(request);
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node so that the next task can add theirs safely,
    // then fill out the node we assigned to use
    var currNode = __primitive("cast", ccnode, _tail.exchange(__primitive("cast", uint, nextNode)));
    currNode.request = request;
    currNode.next = nextNode;

    // Spin until we are finished...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread
    if currNode.completed {
      var retval = currNode.retval;
      delete currNode;
      return retval;
    }

    // If we are not marked as complete, we *are* the combiner thread
    var tmpNode = currNode;
    var tmpNodeNext : ccnode;

    while (tmpNode.next != nil && counter < maxRequests) {
      counter = counter + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      tmpNode.retval = dispatcher(data, tmpNode.request);

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner.
    tmpNode.wait.write(false);
    return currNode.retval;
  }
}

config var nOps = 1024 * 1024;
config var nMaxRequests = 32;

proc test() {

  var expected : bigint = new bigint(nOps + 1);
  writeln("Expected Value: ", expected);

  // Simple test: Atomic Counter
  class counter {
    var x : bigint;
  }

  var ccCounter = new counter(new bigint(1));
  var adder = lambda (c : object, n : object) {
    var count = c : counter;
    var add = n : counter;
    var retval : object = nil;

    count.x = count.x + add.x;
    return retval;
  };

  // Test CCLock
  var lock = new cclock(ccCounter, adder);
  lock.initializer(ccCounter, adder, nMaxRequests);

  var t = new Timer();

  t.start();
  forall i in 1 .. nOps {
    var n = new counter(new bigint(1));
    lock.ccsync(n);
  }
  t.stop();

  if ccCounter.x != expected {
    writeln("BAD VALUE FOR CCLOCK: EXPECTED ", expected, " BUT RECEIVED ", ccCounter.x);
    return;
  }
  writeln("CCLock - ", t.elapsed());
  delete lock;

  class synccounter {
    var x : bigint = new bigint(1);
    var lock$ : sync bool;

    proc adder(n : bigint) {
      lock$.writeEF(true);
      x = x + n;
      lock$.reset();
    }
  }

  // Test sync variable
  var syncCounter = new synccounter();
  t = new Timer();
  t.start();
  forall i in 1 .. nOps {
    syncCounter.adder(new bigint(1));
  }
  t.stop();
  if syncCounter.x != expected {
    writeln("BAD VALUE FOR SYNCLOCK: EXPECTED ", expected, " BUT RECEIVED ", syncCounter.x);
    return;
  }
  writeln("SyncLock - ", t.elapsed());
}
