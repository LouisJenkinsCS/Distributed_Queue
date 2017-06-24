use CyclicDist;
use CCQueue;

class DistributedQueue : Queue {
  // per-locale descriptors
  var perLocaleDomain = {1 .. numLocales};
  var perLocaleDomainMapping = perLocaleDomain dmapped Cyclic(startIdx=perLocaleDomain.low);
  var descriptors : [perLocaleDomainMapping] Queue(eltType);

  inline proc getLocaleDescriptorIndex() {
    return descriptors.domain.localSubdomain().first;
  }

  // TODO: Need to accept custom locales...
  proc DistributedQueue(type eltType) {
    // Create our descriptors
    // forall
    coforall loc in Locales do
      on loc {
        writeln("Locale #", here.id, ": Assigned index: ", getLocaleDescriptorIndex());
        descriptors[getLocaleDescriptorIndex()] = new CCQueue(eltType);
      }
  }

  // Due to the lack of privitization, each and every single access of this queue would
  // cause significant penalties (I can't even begin to measure, but I mean in terms
  // of literal magnitudes, like 10^k for some constant k (and probably k is about 3 to 4)).
  proc getLocalQueue() : Queue(eltType) {
    return descriptors[getLocaleDescriptorIndex()];
  }

  proc enqueue(elt : eltType) {
    descriptors[getLocaleDescriptorIndex()].enqueue(elt);
  }

  proc dequeue() : (bool, eltType) {
    return descriptors[getLocaleDescriptorIndex()].dequeue();
  }

}
