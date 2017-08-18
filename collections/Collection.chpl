/*
  A 'Collection' is a data structure, a container for elements that provide support
  for insert, lookup, remove, and iteration operations.

  BUG: Compiler does not currently allow overloading standalone or leader/follower
  iterators, and as such only serial iterators may be used with a Collection.
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
    BUG: Loop Invariant Code Motion causes undefined behavior if assigned to a
    variable declared outside of loop. Use '--no-loop-invariant-code-motion' flag...
  */
  inline proc remove() : (bool, eltType) {
    halt("'proc remove() : (bool, eltType)' is not supported...");
  }

  /*
    Lookup an element in the data structure, returning whether or not it was present.
  */
  inline proc contains(elt : eltType) : bool {
    halt("'proc contains(elt : eltType) : bool' is not supported...");
  }

  /*
    Clears all elements from this data structure. By default, this will repeatedly
    invoke 'remove' until emptied.
  */
  inline proc clear() {
    while !remove()[1] do ;
  }

  /*
    Check if this data structure is empty. By default, this will check if `size`
    returns 0.
  */
  inline proc isEmpty() : bool {
    return size() == 0;
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
