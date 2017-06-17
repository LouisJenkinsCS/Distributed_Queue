use CyclicDist;
use CombinedSynchronization;

class LocaleDescriptor {
    // Privatized type
    type eltType;

    // Monotonically increasing counters that represents the number of elements in the
    // queue. Used for when work stealing locales need to know how much is available.
    var head : atomic int;
    var tail : atomic int;

    // Our local queue.
    var localQueue : CCQueue(eltType);
}

class DistributedQueue {
  // Cannot just let compiler infer type because we need to return a tuple.
  type eltType;

  // per-locale descriptors
  var perLocaleDomain = {1 .. numLocales};
  var perLocaleDomainMapping = perLocaleDomain dmapped Cyclic(startIdx=perLocaleDomain.low);
  var descriptors : [perLocaleDomainMapping] LocaleDescriptor(eltType);

  inline proc getLocaleDescriptorIndex() {
    return descriptors.domain.localSubdomain().first;
  }

  // TODO: Need to accept custom locales...
  proc DistributedQueue(type eltType) {
    // Create our descriptors
    coforall loc in Locales do
      on loc {
        writeln("Locale #", here.id, ": Assigned index: ", getLocaleDescriptorIndex());
        descriptors[getLocaleDescriptorIndex()] = new LocaleDescriptor(eltType=this.eltType, localQueue=new CCQueue(eltType));
      }
  }

  proc enqueue(elem : eltType) {
    descriptors[getLocaleDescriptorIndex()].localQueue.enqueue(elem);
  }

  proc dequeue() : (bool, eltType) {
    return descriptors[getLocaleDescriptorIndex()].localQueue.dequeue();
  }
}
