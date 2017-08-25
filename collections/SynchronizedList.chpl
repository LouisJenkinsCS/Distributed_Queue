use Collection;

class SynchronizedListNode {
  type eltType;
  var elt : eltType;
  var next : SynchronizedListNode(eltType);
}

class SynchronizedList : CollectionImpl {
  var head : SynchronizedListNode(eltType);
  var tail : SynchronizedListNode(eltType);
  var lock$ : sync bool;

  proc add(elt : eltType) : bool {
    on this {
      lock$ = true;
      var node = new SynchronizedListNode(eltType, elt=elt);
      if head == nil {
        head = node;
        tail = node;
      } else {
        tail.next = node;
        tail = node;
      }
      lock$;
    }
    return true;
  }

  proc remove() : (bool, eltType) {
    var (hasElem, elem) : (bool, eltType);
    on this {
      lock$ = true;
      if head != nil {
        hasElem = true;
        elem = head.elt;

        if head == tail {
          delete head;
          head = nil;
          tail = nil;
        } else {
          var tmp = head;
          head = head.next;
          delete tmp;
        }
      }
      lock$;
    }
    return (hasElem, elem);
  }

  proc deinit() {
    while head != nil {
      var tmp = head.next;
      delete head;
      head = tmp;
    }
  }
}
