use Collection;
use Barrier;

// Tests that all items added are returned.
proc counterTest(c : Collection(int)) {
  const nElems = 100;
  const expected = (nElems * (nElems + 1)) / 2;

  // Fill collection concurrently...
  c.unfreeze();
  for i in 1 .. nElems {
    c.add(i);
  }
  c.freeze();

  // Test to see if it contains middle element
  assert(c.contains((nElems / 2) : int));

  // Iterate over the collection.
  var actual = 0;
  for elem in c {
    actual = actual + elem;
  }
  assert(actual == expected);

  // Empty collection. Make sure all tasks start around same time...
  c.unfreeze();
  var concurrentActual : atomic int;
  writeln("At barrier");
  var barrier = new Barrier(here.maxTaskPar * numLocales);
  coforall loc in Locales do on loc {
    var perLocaleActual : atomic int;
    const _c = c;
    coforall tid in 0..#here.maxTaskPar {
      barrier.barrier();
      writeln(here, "~", tid, ": Left barrier");
      var (hasElem, elt) : (bool, int) = (true, 0);
      var perTaskActual : int;
      while hasElem {
        // This shows that the value, if printed prior to usage, seems to cause an issue
        if elt != 0 then writeln(here, "~", tid, ": Acquired elt: ", elt, ", hasElem: ", hasElem);
        perTaskActual = perTaskActual + elt;
        (hasElem, elt) = _c.remove();
        // Note: If this is removed, we loop infinitely...
        /*if elt != 0 then writeln(here, "~", tid, ": Acquired elt: ", elt, ", hasElem: ", hasElem);*/
      }
      perLocaleActual.add(perTaskActual);
    }
    concurrentActual.add(perLocaleActual.read());
  }

  assert(concurrentActual.read() == expected);
  assert(c.size() == 0 && c.isEmpty());
}
