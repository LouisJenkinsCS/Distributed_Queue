module CCQueue {

  use cclock;
  use Queue;

  class enqueue_request {
    type eltType;
    var data : eltType;
  }

  class dequeue_request {
    type eltType;
  }

  class dequeue_response {
    type eltType;
    var success : bool;
    var elt : eltType;
  }

  class QueueNode {
    type eltType;
    var elt : eltType;
    var next : QueueNode(eltType);
  }

  class CCQueue : Queue {
    var maxRequests = 8;

    var head : QueueNode(eltType);
    var hlock : cclock;
    var tail : QueueNode(eltType);
    var tlock : cclock;

    proc CCQueue(type eltType) {
      local {
        // Create and register our locks
        var enqueue_dispatch = lambda (thiz : object, request : object) {
          var requestObject = request : enqueue_request(eltType);
          type typ = requestObject.eltType;
          var thizQueue = thiz : CCQueue(typ);
          var n = new QueueNode(typ);

          n.elt = requestObject.data : typ;
          thizQueue.tail.next = n;
          thizQueue.tail = n;
          return nil : object;
        };
        var dequeue_dispatch = lambda (thiz : object, request : object) {
          var requestObject = request : dequeue_request(eltType);
          type typ = requestObject.eltType;
          var thizQueue = thiz : CCQueue(typ);
          var node = thizQueue.head;
          var next = node.next;

          if next == nil then return new dequeue_response(eltType, false) : object;
          var retval = next.elt;
          thizQueue.head = next;
          delete node;
          return new dequeue_response(eltType, true, retval) : object;
        };
        this.hlock = new cclock(this, dequeue_dispatch);
        this.hlock.initializer(this, dequeue_dispatch);
        this.tlock = new cclock(this, enqueue_dispatch);
        this.tlock.initializer(this, enqueue_dispatch);

        // Create a dummy node...
        var n = new QueueNode(eltType);
        head = n;
        tail = n;
      }
    }

    proc enqueue(elt : eltType) {
      var request = new enqueue_request(eltType, elt);
      tlock.ccsync(request);
      delete request;
    }

    proc dequeue () : (bool, eltType) {
      var request = new dequeue_request(eltType);
      var retval = hlock.ccsync(request) : dequeue_response(eltType);
      delete request;
      return (retval.success, retval.elt);
    }
  }

  proc main() {
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
  }
}
