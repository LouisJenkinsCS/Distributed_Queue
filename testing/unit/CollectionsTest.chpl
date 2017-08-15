use Collection;
use Barrier;

// Tests that all items added are returned.
proc counterTest(c : Collection(int)) {
  const nElems = 100;
  const expected = (nElems * (nElems + 1)) / 2;

  // Fill collection concurrently...
  c.unfreeze();
  c.clear();
  for i in 1 .. nElems {
    c.add(i);
  }
  c.freeze();

  writeln(c.size());
  assert(c.size() == nElems);

  // Test to see if it contains middle element
  assert(c.contains((nElems / 2) : int));
  writeln("Contains: Passed");

  // Iterate over the collection.
  var actual = 0;
  for elem in c {
    actual = actual + elem;
  }
  writeln("actual: ", actual, ", expected: ", expected);
  assert(actual == expected);
  writeln("Iteration: Passed");
  writeln(c.size());

  // Empty collection. Make sure all tasks start around same time...
  c.unfreeze();
  var concurrentActual : atomic int;
  var barrier = new Barrier(here.maxTaskPar * numLocales);
  coforall loc in Locales do on loc {
    var perLocaleActual : atomic int;
    const _c = c;
    coforall tid in 0..#here.maxTaskPar {
      barrier.barrier();
      var (hasElem, elt) : (bool, int) = (true, 0);
      var perTaskActual : int;
      while hasElem {
        perTaskActual = perTaskActual + elt;
        (hasElem, elt) = _c.remove();
        writeln((hasElem, elt));
      }
      perLocaleActual.add(perTaskActual);
    }
    concurrentActual.add(perLocaleActual.read());
  }

  writeln("size: ", c.size());
  writeln("concurrentActual: ", concurrentActual.read(), ", expected: ", expected);
  assert(concurrentActual.read() == expected);
  assert(c.size() == 0 && c.isEmpty());
  writeln("Drain: Passed");
}
