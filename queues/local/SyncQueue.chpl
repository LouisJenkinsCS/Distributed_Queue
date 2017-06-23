use Queue;

class SyncNode {
  type eltType;
  var elt : eltType;
  var next : SyncNode(eltType);
}

class SyncQueue : Queue {
  var head : SyncNode(eltType);
  var headLock$ : sync bool;
  var tail : SyncNode(eltType);
  var tailLock$ : sync bool;


  proc SyncQueue(type eltType) {
    var dummy = new SyncNode(eltType);
    head = dummy;
    tail = dummy;
  }

  proc enqueue(elt : eltType) {
    var node = new SyncNode(eltType, elt);
    tailLock$ = true;
    tail.next = node;
    tail = node;
    tailLock$;
  }

  proc dequeue() : (bool, eltType) {
    var elt : eltType;
    headLock$ = true;
    var node = head;
    var newHead = head.next;

    // Empty
    if newHead == nil {
      headLock$;
      return (false, _defaultOf(eltType));
    }

    // Grab and clean up
    elt = newHead.elt;
    head = newHead;
    delete node;
    headLock$;
    return (true, elt);
  }
}


proc main() {
  var queue : Queue(int) = new SyncQueue(int);
  for i in 1 .. 100 {
    queue.enqueue(i);
  }

  for i in 1 .. 100 {
    var (exists, elt) = queue.dequeue();
    if !exists || elt != i {
      halt("Expected: ", i, " but was returned: ", elt, "; Exists: ", exists);
    }
  }
}
