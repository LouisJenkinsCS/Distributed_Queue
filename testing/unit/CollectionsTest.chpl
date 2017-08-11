use Collection;
use Barrier;

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

  // Test to see if it contains middle element
  assert(c.contains((nElems / 2) : int));

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

  // Empty collection. Make sure all tasks start around same time...
  c.unfreeze();
  concurrentActual.write(0);
  var barrier = new Barrier(here.maxTaskPar * numLocales);
  coforall loc in Locales do on loc {
    var perLocaleActual : atomic int;
    coforall tid in 0..#here.maxTaskPar {
      barrier.barrier();
      var (hasElem, elt) = (true, 0);
      var perTaskActual : int;
      while hasElem {
        perTaskActual = perTaskActual + elt;
        (hasElem, elt) = c.remove();
      }
      perLocaleActual.add(perTaskActual);
    }
    concurrentActual.add(perLocaleActual.read());
  }

  assert(c.size() == 0 && c.isEmpty());
}
