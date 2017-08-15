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
    Removes an arbitrary element from this data structure.

    BUG: Compiler will segfault if the returned value is not captured at callsite.
    'var capturedRetval = c.remove()'
  */
  inline proc remove() : (bool, eltType) {
    halt("'proc remove() : (bool, eltType)' is not supported...");
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

  // Freezes the collection, rendering it immutable.
  inline proc freeze() : bool {
    halt("'proc freeze() : bool' is not supported...");
  }

  // Unfreezes the collection, rendering it mutable.
  inline proc unfreeze() : bool {
    halt("'proc freeze() : bool' is not supported...");
  }

  // If this collection can be frozen.
  inline proc canFreeze() : bool {
    return false;
  }

  // If this collection is currently frozen.
  inline proc isFrozen() : bool {
    halt("'proc isFrozen() : bool' is not supported...");
  }
}

/*
  Syntactic sugar for 'add'.
*/
proc +=(ref c : Collection(?eltType), elt : eltType) {
  c.add(elt);
}
