use Collection;
use BigInteger;
use Time;
use BlockDist;

/*
  A highly parallel segmented multiset. Each node gets its own queue, and in each queue
  its segmented into 'here.maxTaskPar' segments. Segments allow for actual parallelism
  while operating on the queue in that it enables us to manage 'best-case', 'average-case',
  and 'worst-case' scenarios by making multiple passes over each segment. Examples
  of 'best-case' scenarios would be when a segment is unlocked. 'average-case' would be
  when any unlocked/locked segment, and so on.

  This queue employs work stealing, where after multiple failed passes over the
  segments in the queue we attempt to steal work from other queues. Work stealing
  employs a nice helper algorithm where any task performing dequeue operations,
  after also making multiple failed consecutive passes over the queue,
  will enlist their help in terms of finding elements from other nodes.

  TODO/BUG: Global work stealing is non-deterministic in terms of whether or not
  the queue is empty. If we process a node and they steal from another node ahead
  of us, then we skip over it as if the queue is empty when it really isn't. Its
  possible a rather large amount has been stolen as well, which makes this extremely
  problematic. Requires a better global synchronization scheme, definitely need
  the employment for GlobalAtomicObject.

  TODO: Switch from Tuples to raw C pointers and double the size of each successor
  segment (potential performance boost, faster compilation time).
*/

/*
  Below are segment statuses, which is a way to make visible to outsiders the
  current ongoing operation.
*/
// Free to contest
const UNLOCKED : uint = 0;
// These are normal operations which are for more-verbose debugging purposes.
const ENQUEUE : uint = 1;
const DEQUEUE : uint = 2;
// The work stealer is initializing fields for work stealing, and will be ready soon.
const STEALING_INIT : uint = 3;
// The work stealer is currently stealing work, and may require assistance.
const STEALING_WORK : uint = 4;
// The work stealer is currently merging work that is stolen, and no longer requires assistance.
const STEALING_MERGE : uint = 5;

/*
  Below are statuses specific work queue segment slots.
*/
// The work stealer has reinitialized the slot for use.
const INITIALIZED : int = -1;
// A helper task has finished but has not found any work...
const FINISHED_WITH_NO_WORK : int = 0;
// A helper task has finished with work.
const FINISHED_WITH_WORK : int = 1;


// The amount of elements per unroll block; defines the tuple size.
config param ELEMS_PER_BLOCK = 1024;
// The amount we attempt to steal from each segment of other nodes. Helps to
// further ensure a proper load balance by not leaving segments empty by stealing
// on average 1/4 of their work, leaving them with 3/4. As we steal from *all* other
// segments, it is imperative that this stays low to prevent a ping-pong effect on
// work propagating from excessive work stealing. We steal at least one element, but
// no more than ELEMS_PER_BLOCK per segment.
config param WORK_STEALING_RATIO = 0.25;
config param logMPMCQueue = false;

class BagSegmentBlock {
  type eltType;
  var nElems : int;
  var elems : ELEMS_PER_BLOCK * eltType;
  var next : BagSegmentBlock(eltType);

  iter drain(n) {
    var iterations = n;
    while n > 0 {
      if nElems == 0 {
        return;
      }

      var elem = elems[nElems];
      nElems = nElems - 1;

      yield elem;
      iterations = iterations - 1;
    }
  }
}

record BagSegmentSlot {
  type eltType;

  // The locale we are assigned to steal from...
  var locIdx : int;
  var status : atomic int;
  var block : BagSegmentBlock(eltType);
}

record BagSegment {
  type eltType;

  var status : atomic uint;

  var headBlock : BagSegmentBlock(eltType);
  var tailBlock : BagSegmentBlock(eltType);

  /*
    Fields specific to work stealing for this segment (given 'ws' prefix).
    A helper must first 'register' themselves in our status table, which keeps
    track of which cells are currently taken and which are not. In work stealing,
    we attempt to steal ELEMS_PER_BLOCK * here.maxTaskPar elements, but never assign
    more than one task to a given node.
  */

  // Number of potential helpers. We don't want more workers than there are nodes.
  var wsNumSlots = numLocales - 1;

  // Used to atomically obtain a slot. A task knows they have a slot if it in
  // [0, wsNumSlots). If it is outside of this range, then all slots are filled
  // or this work stealing session is over before the next is initialized.
  var wsSlotsTaken : atomic int;

  // Slots which keep track of data stolen as well as the current status of the helper task.
  var wsSlots : [{0..#wsNumSlots}] BagSegmentSlot(eltType);

  // Number of elements currently in the list to allow faster determinism of whether
  // or not an operation should attempt this bucket.
  var nElems : atomic uint;

  inline proc isEmpty {
    return nElems.read() == 0;
  }

  inline proc acquireWithStatus(newStatus) {
    return status.compareExchangeStrong(UNLOCKED, newStatus);
  }

  inline proc isUnlocked {
    return status.read() == UNLOCKED;
  }

  inline proc currentStatus {
    return status.read();
  }

  inline proc releaseStatus() {
    status.write(UNLOCKED);
  }

  // TODO: Increase efficiency of bulk taking
  proc takeElements(n) {
    var iterations = n;
    var arr : [{0..#n : int}] eltType;
    var arrIdx = 0;
    while iterations > 0 {
      if isEmpty {
        halt("Attempted to take ", n, " elements when insufficient");
      }

      if headBlock.nElems == 0 {
        halt("Iterating over ", n, " elements but Head block is 0 but nElems is ", nElems.read());
      }

      arr[arrIdx] = headBlock.elems[headBlock.nElems];
      arrIdx = arrIdx + 1;
      headBlock.nElems = headBlock.nElems - 1;
      nElems.sub(1);

      // Fix list if we consumed last one...
      if headBlock.nElems == 0 {
        var tmp = headBlock;
        headBlock = headBlock.next;
        delete tmp;

        if headBlock == nil then tailBlock = nil;
      }

      iterations = iterations - 1;
    }

    return arr;
  }

  proc takeElement() {
    if isEmpty {
      return (false, _defaultOf(eltType));
    }

    if headBlock.nElems == 0 {
      halt("Iterating over ", 1, " elements but Head block is 0 but nElems is ", nElems.read());
    }

    var elem = headBlock.elems[headBlock.nElems];
    headBlock.nElems = headBlock.nElems - 1;
    nElems.sub(1);

    // Fix list if we consumed last one...
    if headBlock.nElems == 0 {
      var tmp = headBlock;
      headBlock = headBlock.next;
      delete tmp;

      if headBlock == nil then tailBlock = nil;
    }

    return (true, elem);
  }

  proc addElements(elt : eltType) {
    var block = tailBlock;

    // Empty?
    if block == nil then {
      tailBlock = new BagSegmentBlock(eltType);
      headBlock = tailBlock;
      block = tailBlock;
    }

    // Full?
    if block.nElems == ELEMS_PER_BLOCK {
      block.next = new BagSegmentBlock(eltType);
      tailBlock = block.next;
      block = block.next;
    }

    block.nElems = block.nElems + 1;
    block.elems[block.nElems] = elt;

    // We update the count in each iteration to increase the visibility of this
    // operation (as dequeue operations would skip over us during 2nd pass)
    nElems.add(1);
  }

  // TODO: Increase efficiency of bulk adding
  proc addElements(elts) {
    var block = tailBlock;

    // Empty?
    if block == nil then {
      tailBlock = new BagSegmentBlock(eltType);
      headBlock = tailBlock;
      block = tailBlock;
    }

    for elt in elts {
      // Full?
      if block.nElems == ELEMS_PER_BLOCK {
        block.next = new BagSegmentBlock(eltType);
        tailBlock = block.next;
        block = block.next;
      }

      block.nElems = block.nElems + 1;
      block.elems[block.nElems] = elt;

      // We update the count in each iteration to increase the visibility of this
      // operation (as dequeue operations would skip over us during 2nd pass)
      nElems.add(1);
    }
  }
}

class Bag : Collection {
  // A handle to our parent 'distributed' work queue, which is needed for work stealing.
  var parentHandle : DistributedBag(eltType);

  /*
    Helps evenly distribute and balance placement of elements in a best-effort
    round-robin approach. In the case where we have parallel enqueues or dequeues,
    they are less likely overlap with each other. Furthermore, it increases our
    chance to find our 'ideal' segment.
  */
  var startIdxEnq : atomic uint;
  var startIdxDeq : atomic uint;

  /*
    We only allow one segment to be nominated as the 'work stealer' for our queue.
    This reduces the complexity of having to manage multiple work stealing segments
    while also providing more concurrency through work stealing.
  */
  var workStealer : atomic int;

  var maxParallelSegmentSpace = {0 .. #here.maxTaskPar};
  var segments : [maxParallelSegmentSpace] BagSegment(eltType);

  const maxIterationsPerPhase = here.maxTaskPar;

  inline proc nextStartIdxEnq {
    return (startIdxEnq.fetchAdd(1) % here.maxTaskPar : uint) : int;
  }

  inline proc nextStartIdxDeq {
    return (startIdxDeq.fetchAdd(1) % here.maxTaskPar : uint) : int;
  }

  proc WorkQueue(type eltType) {
    workStealer.write(-1);
  }

  proc add(elt : eltType) : bool {
    var startIdx = nextStartIdxEnq;
    var idx = startIdx : int;
    var iterations = 0;

    /*
      Pass 1: Best Case

      Find a segment that is unlocked and attempt to acquire it. As we are adding
      elements, we don't care how many elements there are, just that we find
      some place to add ours.
    */
    while iterations < maxIterationsPerPhase {
      ref segment = segments[idx];

      // Attempt to acquire...
      if segment.acquireWithStatus(ENQUEUE) {
        segment.addElements(elt);
        segment.releaseStatus();
        return true;
      }

      iterations = iterations + 1;
      idx = (idx + 1) % here.maxTaskPar;
    }

    iterations = 0;
    idx = startIdx : int;

    /*
      Pass 2: Average Case

      Find any segment (locked or unlocked) and make an attempt to acquire it.
      If the segment is actively 'work stealing' then we skip over it to minimize
      the excessive wait-time; given that there can be only *one* work-stealer
      for a node, we know we'll find a better one nearby.
    */
    while true {
      ref segment = segments[idx];

      while true {
        select segment.currentStatus {
          // Quick acquire...
          when UNLOCKED do {
            if segment.acquireWithStatus(ENQUEUE) {
              segment.addElements(elt);
              segment.releaseStatus();
              return true;
            }
          }
          // If someone is stealing, then that means that we'd be waiting for a while
          // anyway, so we may as well attempt to find a node with a shorter wait time.
          when STEALING_INIT do break;
          when STEALING_WORK do break;
          when STEALING_MERGE do break;
        }

        chpl_task_yield();
      }

      idx = (idx + 1) % here.maxTaskPar;
    }

    halt("Almost exited enqueueAcquire before getting a segment...");
  }

  proc remove() : (bool, eltType) {
    var startIdx = nextStartIdxDeq;
    var idx = startIdx;
    var iterations = 0;

    /*
      Pass 1: Best Case

      Find the first bucket that is both unlocked and contains elements. This is
      extremely helpful in the case where we have a good distribution of elements
      in each segment.
    */
    while iterations < maxIterationsPerPhase {
      ref segment = segments[idx];

      // Attempt to acquire...
      if !segment.isEmpty && segment.acquireWithStatus(DEQUEUE) {
        var (hasElem, elem) : (bool, eltType) = segment.takeElement();
        segment.releaseStatus();

        if hasElem {
          return (hasElem, elem);
        }
      }

      iterations = iterations + 1;
      idx = (idx + 1) % here.maxTaskPar;
    }

    idx = startIdx;
    iterations = 0;

    /*
      Pass 2: Average Case

      Find the first bucket containing elements. We don't care if it is locked
      or unlocked this time, just that it contains elements; this handles majority
      of cases where we have elements anywhere in any segment.
    */
    while iterations < here.maxTaskPar {
      ref segment = segments[idx];

      // Attempt to acquire...
      while !segment.isEmpty {
        if segment.isUnlocked && segment.acquireWithStatus(DEQUEUE) {
          var (hasElem, elem) : (bool, eltType) = segment.takeElement();
          segment.releaseStatus();

          if hasElem {
            return (hasElem, elem);
          }
        }

        // Backoff
        chpl_task_yield();
      }

      iterations = iterations + 1;
      idx = (idx + 1) % here.maxTaskPar;
    }

    idx = startIdx;

    /*
      Pass 3: Worst Case

      After two full iterations, we're sure the queue is full at this point, so we
      can attempt to steal work from other nodes. In this pass, we find *any* segment
      and if it is empty, we attempt to become the work-stealer; if someone else is the
      current work stealer we assist them instead and lift an element for ourselves.

      Furthermore, in this phase we loop indefinitely until we are 100% certain it is
      empty or we get an item, so introduce some backoff here.
    */
    var backoff = 0;
    if logMPMCQueue then writeln(here, ": Task on 3rd pass (worst case)...");
    while true {
      ref segment = segments[idx];

      select segment.currentStatus {
        // Quick acquire
        when UNLOCKED {
          backoff = 0;
          if segment.acquireWithStatus(DEQUEUE) {
            // Steal if empty... because we help if we are not the one set, we only
            // know whether the queue is empty if we were the work stealer.
            if segment.isEmpty {
              var (_idx, hasElem, elem) = stealWork(idx);

              // If we have lifted an element, we've retrieved an item.
              if hasElem {
                return (hasElem, elem);
              }

              // If the index returned is equivalent to ours, then we were the 'work stealer'
              // for our queue, and since only we personally know how many elements there are
              // (as we were in charge of merging all work stolen), we know the queue is empty.
              // Otherwise, if the index differs then it means we helped assist another
              // segment in work stealing and we should move to it as if there is any work
              // available, it would be there.
              if _idx == idx {
                return (false, _defaultOf(eltType));
              } else {
                idx = _idx;
              }

              continue;
            }

            // We're lucky; another element has been added to the current segment,
            // take it and leave like normal...
            var (hasElem, elem) : (bool, eltType) = segment.takeElement();
            segment.releaseStatus();
            return (hasElem, elem);
          }
        }
        // If someone else is stealing work, we add ourself as a potential helper
        // to help speed this along, and hopefully we get an element for ourself.
        when STEALING_WORK {
          var (hasElem, elem) = helpStealWork(startIdx);

          // We have our element...
          if hasElem {
            return (hasElem, elem);
          }
          backoff = 0;
        }
      }

      // Backoff to maximum...
      if backoff == 0 then chpl_task_yield();
      else sleep(max(1000, 2 ** backoff), TimeUnits.microseconds);
      backoff = backoff + 1;
    }

    halt("Somehow exited without acquiring an item for dequeue...");
  }

  /*
    Work Stealing
  */

  /*
    Attempt to steal work as the segment referenced by 'idx'. As we may only have
    one work stealing segment, we must first contest for that right. If we obtain
    that right, we become responsible with coordinating and distributing work to other
    helper tasks, and then merging all of the work together. If another segment has
    that right, we move to that segment and become one of their helpers.
  */
  proc stealWork(idx) : (int, bool, eltType) {
    ref segment = segments[idx];

    // We can't steal if we're the only ones, so return as empty
    if numLocales == 1 {
      segment.releaseStatus();
      return (idx, false, _defaultOf(eltType));
    }

    if logMPMCQueue then writeln(here, ": Attempting to steal work for segment #", idx);

    // Attempt to become the sole work stealing segment. If we fail, then we enlist
    // our aid to the current work stealing segment as a helper.
    while true {
      // We are the new work stealing segment...
      if workStealer.compareExchangeStrong(-1, idx) {
        break;
      }

      // Another segment is the work stealing segment; help them out...
      // If we help steal work, it is possible we also lift an element while helping
      // Furthermore, we also return the index of the work stealing segment, as it is
      // likely to have more work.
      var currentStealer = workStealer.read();
      if currentStealer != -1 {
        segment.releaseStatus();
        var (hasElem, elem) = helpStealWork(currentStealer);
        return (currentStealer, hasElem, elem);
      }
    }

    // Initialize each slot for potential helpers. It is imperative that we initialize
    // the slots *before* resetting the wsSlotsTaken to avoid race conditions, as
    // helpers only help if they obtain a valid index.
    var locIdx = 0;
    for slot in segment.wsSlots {
      if locIdx == here.id then locIdx = locIdx + 1;
      slot.locIdx = locIdx;
      slot.status.write(INITIALIZED);
      locIdx = locIdx + 1;
    }
    segment.wsSlotsTaken.write(0);
    segment.status.write(STEALING_WORK);

    // Help yourself...
    var (hasElem, elem) = helpStealWork(idx);
    // Lets others know that we no longer require help.
    segment.status.write(STEALING_MERGE);
    if logMPMCQueue then writeln(here, ": Merging work stolen on segment #", idx);

    // At this point, it is possible that other helpers are still working, and so
    // we wait for them to finish. Merge what has been stolen.
    for slot in segment.wsSlots {
      // Wait for the current helper to finish, and when they do skip any without work...
      while slot.status.read() == INITIALIZED do chpl_task_yield();
      if slot.status.read() == FINISHED_WITH_NO_WORK then continue;

      var stolenBlock = slot.block;
      var tailBlock = segment.tailBlock;
      var blockElems = stolenBlock.nElems;
      segment.nElems.add(blockElems : uint);

      while stolenBlock != nil {
        // Drain elements we've stolen and merge it into our segment.
        for elt in stolenBlock.drain(ELEMS_PER_BLOCK) {
          // If we have not lifted an element for ourself by now, do so.
          if !hasElem {
            elem = elt;
            hasElem = true;
            segment.nElems.sub(1);
            if logMPMCQueue then writeln(here, ": Lifted element ", elem, " as segment #", idx);
            continue;
          }

          segment.addElements(elt);
        }

        var tmp = stolenBlock;
        stolenBlock = stolenBlock.next;
        delete tmp;
      }
    }

    // At this point, we have stolen from all other nodes, and we may relinquish
    // our role as primary work-stealer.
    workStealer.write(-1);
    segment.releaseStatus();
    return (idx, hasElem, elem);
  }

  /*
    Enlist our aid as a helper thread for the current work stealer. To do so, we
    must claim a slot (atomically),
  */
  proc helpStealWork(idx) : (bool, eltType) {
    ref segment = segments[idx];

    while true {
      select segment.currentStatus {
        // They are still initializing...
        when STEALING_INIT {
          // Tight spin, we'll be able to help soon...
        }
        // They are initialized, we can now attempt to help...
        when STEALING_WORK {
          break;
        }
        // We're not stealing work...
        otherwise do return (false, _defaultOf(eltType));
      }
    }

    if logMPMCQueue then writeln(here, ": Helping steal work for segment #", idx);
    var (hasElem, elem) : (bool, eltType);

    // Attempt to help...
    while true {
      var ourIdx = segment.wsSlotsTaken.fetchAdd(1);
      // If the index we get is not in a valid range, we're done helping.
      if ourIdx >= segment.wsNumSlots {
        return (hasElem, elem);
      }

      ref slot = segment.wsSlots[ourIdx];
      if logMPMCQueue then writeln(here, ": Assigned to steal work from segment #", ourIdx, " for segment #", idx);

      // We know which locale we are going to be working on, but we must setup some
      // temporaries that can make it easier for back-and-forth communication.
      // We create an array of tuples, one for each segment on the other node.
      // As well, in case a segment is skipped, we initialize the index at '1'
      // to signify that it is empty.
      var stolenWork : [{0..#Locales[slot.locIdx].maxTaskPar}] (int, ELEMS_PER_BLOCK * eltType);
      for work in stolenWork do work[1] = 1;

      on Locales[slot.locIdx] {
        // We keep track of a simple bitmap to keep track of which segments we have
        // already processed, since on the first pass we skip over any locked segments.
        var segmentBitmap : bigint;
        var queue = parentHandle.localQueue;
        var iterations = 0;
        var otherStartIdx = queue.nextStartIdxDeq;
        var otherSegmentIdx = otherStartIdx;

        /*
          Pass 1: Best Case

          Find any unlocked segment that contains elements...
        */
        while iterations < here.maxTaskPar {
          ref otherSegment = segments[otherSegmentIdx];

          // Attempt to acquire...
          if !otherSegment.isEmpty && otherSegment.acquireWithStatus(DEQUEUE) {
            var toSteal = max(1, min(ELEMS_PER_BLOCK, otherSegment.nElems.read() * WORK_STEALING_RATIO));
            var stolen : ELEMS_PER_BLOCK * eltType;
            var stolenIdx = 1;
            for elt in otherSegment.takeElements(toSteal) {
                stolen[stolenIdx] = elt;
                stolenIdx = stolenIdx + 1;
            }
            otherSegment.releaseStatus();

            // Mark as processed and move stolen work...
            segmentBitmap.setbit(otherSegmentIdx);
            stolenWork[otherSegmentIdx] = (stolenIdx, stolen);
          }

          iterations = iterations + 1;
          otherSegmentIdx = (otherSegmentIdx + 1) % here.maxTaskPar;
        }

        otherSegmentIdx = otherStartIdx;
        iterations = 0;

        /*
          Pass 2: Average Case

          Find any segment not already processed that contains elements...
        */
        while iterations < here.maxTaskPar {
          if segmentBitmap.tstbit(otherSegmentIdx) {
            iterations = iterations + 1;
            otherSegmentIdx = (otherSegmentIdx + 1) % here.maxTaskPar;
            continue;
          }
          ref otherSegment = segments[otherSegmentIdx];

          // Attempt to acquire...
          while !otherSegment.isEmpty {
            // If they are stealing work as well, we back out.
            if otherSegment.status.read() == STEALING_WORK then break;

            if otherSegment.isUnlocked && otherSegment.acquireWithStatus(DEQUEUE) {
              var toSteal = max(1, min(ELEMS_PER_BLOCK, otherSegment.nElems.read() * WORK_STEALING_RATIO));
              var stolen : ELEMS_PER_BLOCK * eltType;
              var stolenIdx = 1;
              for elt in otherSegment.takeElements(toSteal) {
                  stolen[stolenIdx] = elt;
                  stolenIdx = stolenIdx + 1;
              }
              otherSegment.releaseStatus();

              // Mark as processed and move stolen work...
              segmentBitmap.setbit(otherSegmentIdx);
              stolenWork[otherSegmentIdx] = (stolenIdx, stolen);
            }

            // Backoff
            chpl_task_yield();
          }

          iterations = iterations + 1;
          otherSegmentIdx = (otherSegmentIdx + 1) % here.maxTaskPar;
        }

        // At this point we are done, we've stolen from all segments that aren't
        // currently stealing work...
      }

      // Link all of the stolen work together (only if they contain any work)
      for (idx, work) in stolenWork {
        // Is empty
        if idx == 1 then continue;

        // Lift an element if not already...
        if !hasElem {
          hasElem = true;
          elem = work[idx - 1];
          idx = idx - 1;

          // Consumed last element?
          if idx == 1 then continue;
        }

        // Create
        var block = new BagSegmentBlock(eltType);
        block.nElems = idx;
        block.elems = work;

        // Append
        block.next = slot.block;
        slot.block = block;
      }

      if slot.block == nil then slot.status.write(FINISHED_WITH_NO_WORK); else slot.status.write(FINISHED_WITH_WORK);
      if logMPMCQueue then writeln(here, ": Finished stealing work for segment #", idx);
    }

    halt("Exited helpStealWork loop...");
  }
}

class DistributedBag : Collection {
  var perLocaleDomain = LocaleSpace dmapped Block(boundingBox=LocaleSpace);
  var bags : [perLocaleDomain] Bag(eltType);

  proc DistributedBag(type eltType) {
    forall loc in Locales {
      on loc {
        bags[here.id] = new Bag(eltType, parentHandle=this);
      }
    }
  }

  inline proc localBag {
    return bags[here.id];
  }

  proc add(elt : eltType) : bool {
    localBag.add(elt);
    return true;
  }

  proc remove() : (bool, eltType) {
    return localBag.remove();
  }
}
