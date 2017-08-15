use Collection;
use Barrier;

// For this test, we implement a simple counter; we add a predetermined number
// of elements, then concurrently remove all elements from it until it is empty,
// testing that all elements added were removed.
config param isBoundedDeque = false;
config param isDeque = false;
config param isBag = false;

const nElems = 1000;
const expected = (nElems * (nElems + 1)) / 2;

var c : Collection(int);
if isBoundedDeque {
  c = new DistributedDeque(int, cap=nElems);
} else if isDeque {
  c = new DistributedDeque(int);
} else if isBag {
  c = new DistributedBag(int);
} else {
  halt("Require 'isBoundedDeque', 'isDeque', or 'isBag' to be set...");
}

// Fill...
for i in 1 .. nElems {
  c.add(i);
}
c.freeze();

assert(c.size() == nElems);
writeln("Add: Passed");

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
assert(c.size() == nElems);
writeln("Iteration: Passed");

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
writeln("Remove: Passed");
