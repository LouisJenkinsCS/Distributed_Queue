use CyclicDist;
use ccqueue;

record LocaleDescriptor {
    // Privatized type
    type eltType;

    // Monotonically increasing counters that represents the number of elements in the
    // queue. Used for when work stealing locales need to know how much is available.
    var head : atomic int;
    var tail : atomic int;

    // Our local queue.
    var localQueue : ccqueue(eltType);
}

class Distributed_FIFO {
  // Cannot just let compiler infer type because we need to return a tuple.
  type eltType;

  // per-locale descriptors
  var perLocaleDomain = {1 .. nLocales};
  var perLocaleDomainMapping = perLocaleDomain dmapped Cyclic(startIdx=perLocaleDomain.low);
  var descriptors : [perLocaleDomainMapping] ccqueue(eltType);

  inline proc getLocaleDescriptorIndex() {
    return descriptors.domain.localSubdomain().first;
  }

  // TODO: Need to accept custom locales...
  proc Distributed_FIFO(type eltType) {
    // Create our descriptors
    coforall loc in Locales do
      on loc do
        descriptors[getLocaleDescriptorIndex()] = new LocaleDescriptor(eltType=this.eltType, localQueue=new ccqueue(eltType));
  }

  proc enqueue(elem : eltType) {
    descriptors[getLocaleDescriptorIndex()].localQueue.enqueue(elem);
  }

  proc dequeue() : (bool, eltType) {
    return descriptors[getLocaleDescriptorIndex()].localQueue.dequeue(elem);
  }
}
