use Collection.List;
use HSynch;

/*
  BUG: Compiler bug that will not recognize generic lambda...
*/

class DistributedListNode {
  type eltType;
  var elt : eltType;
  var next : DistributedListNode(eltType);
}

/*
  A queue that is distributed across nodes; employs load balancing to redistribute
  work when a list is empty.
*/
class DistributedList : List {
  var head : DistributedListNode(eltType);
  var tail : DistributedListNode(eltType);
  var hsynchLock : HSynch(DistributedList(eltType));

  proc DistributedList(type eltType) {
    hsynchLock = new HSynch(this.type, userData=this);
  }

  proc add(elt : eltType) : bool {
    var request = lambda(thiz : DistributedList(eltType), requestData : c_void_ptr) {
      var elem = (requestData : c_ptr(eltType))[0];
      var node = new DistributedListNode(eltType, elt = elem);
      if thiz.head == nil {
        thiz.head = node;
        thiz.tail = node;
      } else {
        thiz.tail.next = node;
        thiz.tail = node;
      }
    };
    var elem = elt;
    var requestData = c_ptrTo(elem) : c_void_ptr;
    hsynchLock.synch(request, requestData);
    return true;
  }

  /*proc remove() : (bool, eltType) {
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
  }*/
}
