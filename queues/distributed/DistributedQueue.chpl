use CyclicDist;
use Queue;

class LocalDistQueueNode {
  type eltType;
  var elt : eltType;
  var next : LocalDistQueueNode(eltType);
}

class LocalDistQueue {
  type eltType;

  // Counter is for outside readers
  var head : LocalDistQueueNode(eltType);
  var headLock$ : sync bool;
  var headCounter : atomic uint;

  // Counter is for outside readers
  var tail : LocalDistQueueNode(eltType);
  var tailCounter : atomic uint;
  var tailLock$ : sync bool;

  proc LocalDistQueue(type eltType) {
    var dummy = new LocalDistQueueNode(eltType);
    head = dummy;
    tail = dummy;
  }
}

class DistributedQueue : Queue {
  // per-locale descriptors
  var perLocaleDomain = {0 .. numLocales-1};
  var perLocaleDomainMapping = perLocaleDomain dmapped Cyclic(startIdx=perLocaleDomain.low);
  var descriptors : [perLocaleDomainMapping] LocalDistQueue(eltType);

  inline proc getLocaleDescriptorIndex() {
    return descriptors.domain.localSubdomain().first;
  }

  // TODO: Need to accept custom locales...
  proc DistributedQueue(type eltType) {
    // Create our descriptors
    // forall
    coforall loc in Locales do
      on loc {
        writeln("Locale #", here.id, ": Assigned index: ", getLocaleDescriptorIndex());
        descriptors[getLocaleDescriptorIndex()] = new LocalDistQueue(eltType);
      }
  }

  proc enqueue(elt : eltType) {
    var queue = descriptors[getLocaleDescriptorIndex()];
    var node = new LocalDistQueueNode(eltType, elt);
    queue.tailLock$ = true;
    queue.tail.next = node;
    queue.tail = node;
    queue.tailCounter.add(1);
    queue.tailLock$;
  }

  proc dequeue() : (bool, eltType) {
    var queue = descriptors[getLocaleDescriptorIndex()];
    var elt : eltType;
    queue.headLock$ = true;
    var node = queue.head;
    var newHead = queue.head.next;

    // Empty
    if newHead == nil {
      // Steal work... Allocate some space to store work we steal..
      // TODO: I believe we need to use something like c_malloc & c_memcpy like Engin does
      // in his distributed_list repo? Currently, its so inefficient, and I have no idea
      // how else to approach this without incurring communication cost on every item taken...
      var work : [{0 .. numLocales-1}] (bool, eltType);

      // This is a coforall because it is imperative that we spawn a task for each
      // as it is mainly blocking.
      coforall loc in Locales {
        on loc {
          var theirQueue = descriptors[getLocaleDescriptorIndex()];
          var nElems = theirQueue.tailCounter.read() - theirQueue.headCounter.read();

          // They have some elements at this time. It should be noted that even if
          // the queue is empty after our read of both counters, then by the time they
          // attempt to steal from us, they will see we are empty and skip us, avoiding deadlock.
          if nElems {
            // TODO: Recalculate nElems once we have lock...
            var toSteal = 1;
            theirQueue.headLock$ = true;

            // Steal a fair amount...
            for 1 .. toSteal {
              var theirNode = theirQueue.head;
              var theirNewHead = theirQueue.head.next;

              // Their queue is empty...
              if theirNewHead == nil {
                theirQueue.headLock$;
                break;
              }

              // Grab and clean up
              var theirElt = theirNewHead.elt;
              theirQueue.head = theirNewHead;
              delete theirNode;
              theirQueue.headCounter.add(1);
              theirQueue.headLock$;

              // Add to our work buffer...
              work[here.id] = (true, elt);
            }
          }
        }
      }

      // We have the work we need... take the first one and add the rest...
      // TODO: Implement enqueue_bulk... need to settle on a decent bulk transfer
      // protocol...
      var first = false;
      for (present, elem) in work {
        if present {
          if !first {
            elt = elem;
            present = false;
            first = true;
          } else {
            enqueue(elem);
          }
        }
      }

      queue.headLock$;

      // Is Empty?
      if !first {
        return (false, _defaultOf(eltType));
      } else {
        return (true, elt);
      }
    }

    // Grab and clean up
    elt = newHead.elt;
    queue.head = newHead;
    delete node;
    queue.headCounter.add(1);
    queue.headLock$;
    return (true, elt);
  }
}

// Simple proof of correctness test - Self Contained
proc main() {
  var nElems = 100000;
  writeln("Starting MPMCQueue Proof of Correctness Test ~ nElems: ", nElems);

  var queue = new DistributedQueue(int);
  var counter : atomic int;
  var expected = (nElems * (nElems + 1)) / 2;

  forall i in 1 .. nElems {
    queue.enqueue(i);
  }

  coforall loc in Locales {
    coforall tid in 0 .. #here.maxTaskPar {
      while true {
        var (present, elem) = queue.dequeue();
        if !present {
          break;
        }

        counter.add(elem);
      }
    }
  }

  if counter.read() == expected {
    writeln("PASSED TEST!");
  } else {
    writeln("FAILED TEST! Expected: ", expected, ", but received: ", counter.read());
  }

}
