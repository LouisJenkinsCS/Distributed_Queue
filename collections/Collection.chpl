/*
  Base class for data structures.
*/
class Collection {
  type eltType;

  /*
    Adds an element to this data structure.
  */
  inline proc add(elt : eltType) : bool {
    halt("'proc add(elts : eltType ... ?nElts) : bool' is not supported...");
  }
  /*
    Add all elements from another collection to this.
  */
  inline proc add(otherCollection : Collection(eltType)) : bool {
    halt("'proc add(otherCollection : Collection(eltType)) : bool' is not supported...");
  }
  /*
    Add all elements in the array.
  */
  inline proc add(elts : [?nElts] eltType) : bool {
    halt("'proc add(elts : [?nElts] eltType) : bool' is not supported...");
  }
  /*
    Removes an arbitrary element from this data structure.
  */
  inline proc remove() : (bool, eltType) {
    halt("'proc remove() : (bool, eltType)' is not supported...");
  }
  /*
    Removes up to `nElems` elements into a separate collection.
  */
  inline proc remove(nElems : int) : Collection(eltType) {
    halt("'proc remove(nElems : int) : Collection(eltType)' is not supported...");
  }
  /*
    Removes an item from the data structure (if it exists).
  */
  inline proc removeItem(elt : eltType) : bool {
    halt("'proc removeItem(elt : eltType) : bool' is not supported...");
  }
  /*
    Check if the element exists in this data structure.
  */
  inline proc contains(elt : eltType) : bool {
    halt("'proc contains(elt : eltType) : bool' is not supported...");
  }
  /*
    Clears all elements from this data structure.
  */
  inline proc clear() {
    halt("'proc clear()' is not supported...");
  }
  /*
    Check if this data structure is empty.
  */
  inline proc isEmpty() : bool {
    halt("'proc isEmpty() : bool' is not supported...");
  }
  /*
    Obtain the number of elements contained in this data structure.
  */
  inline proc size() : int {
    halt("'proc size() : int' is not supported...");
  }
  /*
    Iterate over all elements in the data structure.
  */
  iter these() : eltType {
    halt("'iter these() : eltType' is not supported...");
    yield _defaultOf(eltType);
  }
}

module Stack {
  /*
    A Last-In-First-Out data structure. Classes inheriting from this class must
    override the `add` to push elements in Last-In-First-Out order, and `remove`
    to pop elements in Last-In-First-Out order.
  */
  class Stack : Collection {
    /*
      Syntactic sugar for 'add'
    */
    inline proc push(data) : bool {
      halt("'proc push(data) : bool' is not supported...");
    }
    /*
      Syntactic sugar for 'remove'
    */
    inline proc pop() : (bool, eltType) {
      return this.remove();
    }
    /*
      Syntactic sugar for 'remove'
    */
    inline proc pop(nElems : int) : Collection(eltType) {
      return this.remove(nElems);
    }
  }

  /*
    A stack with a static capacity.
  */
  class BoundedStack : Stack {
    inline proc capacity() : int {
      halt("'proc capacity() : int' is not supported...");
    }
  }

  /*
    A stack with a dynamic capacity.
  */
  class DynamicBoundedStack : BoundedStack {
    inline proc resize(newSize : int) : bool {
      halt("'proc resize(newSize : int) : bool' is not supported...");
    }
  }
}

module Queue {
  /*
    A First-In-First-Out data structure. Classes inheriting from this class must
    override the `add` to enqueue elements in First-In-First-Out order, and `remove`
    to dequeue elements in First-In-First-Out order.
  */
  class Queue : Collection {
    /*
      Syntactic sugar for 'add'.
    */
    inline proc enqueue(elts : eltType ... ?nElts) : bool {
      return this.add((...elts));
    }
    /*
      Syntactic sugar for 'remove'
    */
    inline proc dequeue() : (bool, eltType) {
      return this.remove();
    }
    /*
      Syntactic sugar for 'remove'
    */
    inline proc dequeue(nElems : int) : Collection(eltType) {
      return this.remove(nElems);
    }
  }

  /*
    A queue with a static capacity.
  */
  class BoundedQueue : Queue {
    inline proc capacity() : int {
      halt("'proc capacity() : int' is not supported...");
    }
  }

  /*
    A queue with a dynamic capacity.
  */
  class DynamicBoundedQueue : BoundedQueue {
    inline proc resize(newSize : int) : bool {
      halt("'proc resize(newSize : int) : bool' is not supported...");
    }
  }
}

module List {
  /*
    An ordered structure which supports indexing.
  */
  class List : Collection {
    /*
      Obtain the element at the requested index.
    */
    inline proc get(idx : int) : (bool, eltType) {
      halt("'proc get(idx : int) : (bool, eltType)' is not supported...");
    }
    /*
      Obtains the index of the requested element, if present in the list.
    */
    inline proc indexOf(elt : eltType) : int {
      halt("'proc indexOf(elt : eltType) : int' is not supported...");
    }
    /*
      Add an element at a specific index in the list.
    */
    inline proc add(idx : int, elt : eltType) : bool {
      halt("'proc add(idx : int, elt : eltType) : bool' is not supported...");
    }
    /*
      Creates a new list containing the items at the specified indexes. If `end`
      is less than `start`, then the end indice is set to the end of the list.
      If the `end` is greater than the size of the list, it will also be set
      to the end of the list.
    */
    inline proc subList(start : int, end : int = -1) : List(eltType) {
      halt("'proc subList(start : int, end : int = -1) : List(eltType)' is not supported...");
    }
  }

  /*
    A data structure with a static capacity.
  */
  class BoundedList : List {
    inline proc capacity() : int {
      halt("'proc capacity() : int' is not supported...");
    }
  }

  /*
    A data structure with a dynamic capacity.
  */
  class DynamicBoundedList : BoundedList {
    inline proc resize(newSize : int) : bool {
      halt("'proc resize(newSize : int) : bool' is not supported...");
    }
  }
}

// TODO: Operator does not allow return type... trouble?

/*
  Syntactic sugar for 'add'.
*/
proc +=(ref c : Collection(?eltTyp), other) {
  c.add(other);
}

proc +=(ref c : Collection(?eltType), other) where isTuple(other) {
  c.add((...other));
}
