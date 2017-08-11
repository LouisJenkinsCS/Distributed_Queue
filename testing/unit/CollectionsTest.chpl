use Collection;

// Tests that all items added are returned.
proc counterTest(c : Collection(int)) {
  const nElems = 100;
  const expected = (nElems * (nElems + 1)) / 2;

  // Fill collection concurrently...
  c.unfreeze();
  forall i in 1 .. nElems {
    c.add(i);
  }
  c.freeze();

  // Iterate over the collection.
  var actual = 0;
  for elem in c {
    actual = actual + elem;
  }
  assert(actual == expected);

  // Iterate concurrently over the collection.
  var concurrentActual : atomic int;
  forall elem in c {
    concurrentActual.add(elem);
  }
  assert(concurrentActual.read() == expected);

  // Empty collection
  c.unfreeze();
  concurrentActual.write(0);
  coforall loc in Locales do on loc {
    coforall tid in 0..#here.maxTaskPar {
      var (hasElem, elt) = (true, 0);
      while hasElem {
        concurrentActual.add(elt);
        (hasElem, elt) = c.remove();
      }
    }
  }

  assert(c.size() == 0 && c.isEmpty());
}
