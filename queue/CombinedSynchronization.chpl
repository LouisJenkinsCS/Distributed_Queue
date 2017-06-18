module CombinedSynchronization {

  enum CCAction {
    ENQUEUE, DEQUEUE
  }

  class CCNode {
    type eltType;
    // Our active request
    var request : CCAction;
    // By default we only have one element of data...
    var dataDomain = {1 .. 1};
    // ENQUEUE* operations use this to put data to be added
    // DEQUEUE* operations use this to get data to be taken
    var data : [dataDomain] eltType;
    // What we are spinning on.
    var wait : atomic bool;
    // Is our operation completed? We only check this variable if we are not waiting,
    // and if it is not complete then we become the combiner thread.
    var completed : bool;
    // Next in the queue.
    var next : CCNode(eltType);
  }

  class QueueNode {
    type eltType;
    var elt : eltType;
    var next : QueueNode(eltType);
  }

  class CCQueue {
    type eltType;
    var maxRequests = 8;

    // Both head and tail are protected by their own respective CCLocks. Since
    // CCLock relies on callbacks, and first class functions in Chapel are very
    // buggy at the moment, so we need to inline the logic here.
    var head : QueueNode(eltType);
    var headCounter : atomic int;
    var headCCTail : atomic uint(64);
    var tail : QueueNode(eltType);
    var tailCounter : atomic int;
    var tailCCTail : atomic uint(64);

    proc CCQueue(type eltType) {
      local {
        // Head and Tail require a dummy node, as do their respective locks...
        headCCTail.write(__primitive("cast", uint, new CCNode(eltType)));
        tailCCTail.write(__primitive("cast", uint, new CCNode(eltType)));
        var n = new QueueNode(eltType);
        head = n;
        tail = n;
      }
    }

    proc cclockSync(request, ref dom, data) {
      local {
        var counter = 0;
        ref _tail = if request == CCAction.ENQUEUE then tailCCTail else headCCTail;
        var nextNode = new CCNode(eltType);
        nextNode.wait.write(true);
        nextNode.completed = false;

        // Register our dummy node so that the next task can add theirs safely,
        // then fill out the node we assigned to use
        var currNode = __primitive("cast", CCNode(eltType), _tail.exchange(__primitive("cast", uint, nextNode)));
        currNode.request = request;
        currNode.next = nextNode;
        currNode.dataDomain = dom;
        currNode.data = data;

        // Spin until we are finished...
        currNode.wait.waitFor(false);

        // If our operation is marked complete, we may safely reclaim it, as it is no
        // longer being touched by the combiner thread
        if currNode.completed {
          dom = currNode.dataDomain;
          var retval = currNode.data;
          delete currNode;
          return retval;
        }

        // If we are not marked as complete, we *are* the combiner thread
        var tmpNode = currNode;
        var tmpNodeNext : CCNode(eltType);

        while (tmpNode.next != nil && counter < maxRequests) {
          counter = counter + 1;
          // Note: Ensures that we do not touch the current node after it is freed
          // by the owning thread...
          tmpNodeNext = tmpNode.next;

          // Process...
          select tmpNode.request {
            when CCAction.ENQUEUE {
              for i in tmpNode.data.domain {
                var n = new QueueNode(eltType, tmpNode.data[i]);
                tail.next = n;
                tail = n;
                tailCounter.fetchAdd(1);
              }
            } when CCAction.DEQUEUE {
              var nElems = 0;
              var availData : [tmpNode.dataDomain] eltType;
              for i in tmpNode.data.domain {
                // Nothing left...
                if tailCounter.read() == headCounter.read() {
                  break;
                }

                var node = head;
                var next = node.next;
                availData[i] = next.elt;
                head = next;
                delete node;

                headCounter.fetchAdd(1);
                nElems = nElems + 1;
              }

              tmpNode.dataDomain = {1 .. nElems};
              tmpNode.data = availData;
            }
          }

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
        dom = currNode.dataDomain;
        return currNode.data;
      }
    }

    proc enqueue(elt : eltType) {
        var dom = {1 .. 1};
        var arr : [dom] eltType;
        arr[1] = elt;
        cclockSync(CCAction.ENQUEUE, dom, arr);
    }

    proc dequeue () : (bool, eltType) {
      var dom = {1 .. 1};
      var arr : [dom] eltType;
      var retval = cclockSync(CCAction.DEQUEUE, dom, arr);
      if dom.first > dom.last {
        return (false, _defaultOf(eltType));
      }
      else {
        return (true, retval[1]);
      }
    }
  }

  /*proc main() {
    var queue = new CCQueue(int);

    for i in 1 .. 100 {
      queue.enqueue(i);
    }

    for i in 1 .. 100 {
      var retval = queue.dequeue();
      if retval[2] != i {
        writeln("BAD RESULT! Expected ", i, ", Received ", retval);
        return;
      }
    }
  }*/
}
