/*
  A 'Collection' is an interface for a data structure that is a 'contract' between
  the user and implementer that it fulfills the following:

  1. Is safe parallel-safe, hence is safe to use across multiple tasks across multiple locales.
  2. Supports the basic operations that any data structure needs to be truly useful, that is:
    a. Insertion of an arbitrary element
    b. Removal of an arbitrary element
    c. Lookup of an specific element
*/

/*
  A 'Collection' is a data structure, a container for elements that provide support
  for insert, lookup, remove, and iteration operations.
*/
module Collection-Interface {
  class Collection {
    /*
      The type of element that this Collection holds.
    */
    type eltType;

    /*
      Adds an element to this data structure.
    */
    proc add(elt : eltType) : bool {
      halt("'proc add(elt : eltType) : bool' is not supported...");
    }

    /*
      Add all elements in bulk to this data structure. If the data structure
      rejects an element, we cease to offer more. We return the number of elements
      successfully added to this data structure.
    */
    proc addBulk(elts) : int {
      var successful : int;
      for elt in elts {
        if !add(elt) {
          break;
        }

        successful += 1;
      }
    }

    /*
      Removes an arbitrary element from this data structure.

      **BUG:** Compiler will segfault if the returned value is not captured at callsite.
      Issue: #6542

      **FIX:** Ensure that you always capture the return value...

      ::

        var capturedRetval = c.remove()

      **BUG:** Loop Invariant Code Motion causes undefined behavior if assigned to a
      variable declared outside of loop. Issue: #7003

      **FIX:** Use the `--no-loop-invariant-code-motion` to disable LICM.
      Otherwise, just make sure you always capture the return value inside of a loop
      in a variable not declared outside of loop...

      ::

        for i in 1 .. N {
          var retval = c.remove();
        }

    */
    proc remove() : (bool, eltType) {
      halt("'proc remove() : (bool, eltType)' is not supported...");
    }

    /*
      Removes `nElts` elements from this data structure, returning them as an array.
      If the data structure fails to produce a new element, we cease and shrink the array
      to its appropriate size and return that. 
    */
    proc removeBulk(nElts : int) {
      var dom = {0..#nElts};
      var arr : [dom] eltType;
      var idx = 0;

      for 1 .. nElts {
        var (hasElt, elt) = remove();
        if !hasElt {
          dom = {0..#idx};
          break;
        }

        dom[idx] = elt;
        idx += 1;
      }

      return arr;
    }

    /*
      Determine whether an element exists in this collection.
    */
    proc contains(elt : eltType) : bool {
      var found = false;

      // Iterate to find it... note that we cannot break early due to
      // issues with leaking during serial iteration.
      for e in these() {
        if e == elt {
          found = true;
        }
      }

      return found;
    }

    /*
      Clears all elements in this collection.
    */
    proc clear() {
      while true {
        var (hasElt, elt) = remove();
        if !hasElt {
          break;
        }
      }
    }

    /*
      Check if this data structure is empty.
    */
    proc isEmpty() : bool {
      return getSize() == 0;
    }

    /*
      Syntactic sugar for `getSize`.
    */
    proc length : int {
      return getSize();
    }

    /*
      Syntactic sugar for `getSize`.
    */
    proc size : int {
      return getSize();
    }

    /*
      Obtain the number of elements contained in this collection.
    */
    proc getSize() : int {
      halt("'proc size() : int' is not supported...");
    }

    /*
      Iterate over all elements in the data structure.

      **BUG:** Compiler does not currently allow overriding standalone or leader/follower
      iterators, and as such only serial iterators may be used with the base type. See
      issue #6998

      **BUG:** Resources are not properly cleaned up when the user breaks or returns
      from a serial iterator, and so this *must* be avoided at all cost. See issue #6912
    */
    iter these() : eltType {
      halt("'iter these() : eltType' is not supported...");
      yield _defaultOf(eltType);
    }
  }

  /*
    Syntactic sugar for 'add'.

    **BUG:** Compiler produces a warning that `c` should be a `ref`, when it is not needed
    because it is a class and can be used by value. Need a pragma to disable this?
    As such, this cannot be used where `ref` intents cannot be used, such as ``forall``
    and ``coforall`` loops.
  */
  inline proc +=(const ref c : Collection(?eltType), elt : eltType) {
    c.add(elt);
  }
}