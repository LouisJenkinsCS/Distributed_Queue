use GlobalAtomicObject;
use LocalAtomicObject;

const HSYNCH_WAITING = 0;
const HSYNCH_COMPLETE = 1;
const HSYNCH_COMBINER = 2;

// Used for global MCS Lock
class HSynchGlobalNode {
  var next : GlobalAtomicObject(HSynchGlobalNode);
  var waiting : atomic bool;
}

// Used for local CCSynch Lock
class HSynchLocalNode {
  type userDataType;
  var requestData : c_void_ptr;
  // request is a function taking both userData and requestData. If the user wishes
  // to return they may do so through the c_void_ptr.
  var request : func(userDataType, c_void_ptr);
  var status : atomic int;
  var next : LocalAtomicObject(HSynchLocalNode(userDataType));
}

class HSynch {
  type userDataType;
  var userData : userDataType;
  var pid : int;

  var globalWaitList : LocalAtomicObject(HSynchGlobalNode);

  // Node-local fields
  var localWaitList : GlobalAtomicObject(HSynchLocalNode(userDataType));
  var globalWaitListNode : HSynchGlobalNode;
  var isGlobalLockOwner : atomic bool;

  proc HSynch(type userDataType) {
    pid = _newPrivatizedClass(this);
  }

  proc HSynch(other, userData, type userDataType = other.userDataType) {
    localWaitList.write(new HSynchLocalNode(userDataType));
    globalWaitList = new HSynchGlobalNode();
  }

  proc dsiPrivatize(userData) {
    return new HSynch(this, userData);
  }

  proc dsiGetPrivatizeData() {
    return userData;
  }

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc acquireGlobalLock(localThis) {
    var ourNode = localThis.globalWaitListNode;
    ourNode.next.write(nil);

    var predNode = globalWaitList.exchange(ourNode);
    if predNode != nil {
      ourNode.waiting.write(true);
      predNode.next.write(ourNode);
      while ourNode.waiting.read() do chpl_task_yield();
    }
  }

  proc releaseGlobalLock(localThis) {
    var ourNode = localThis.globalWaitListNode;
    if ourNode.next.read() == nil {
      if globalWaitList.compareExchange(ourNode, nil) {
        return;
      }

      while ourNode.next.read() != nil do chpl_task_yield();
    }

    ourNode.next.read().waiting.write(false);
  }

  proc synch(request : func(userDataType, c_void_ptr), requestData : c_void_ptr) {
    var localThis = getPrivatizedThis;
    var dummyNext = new HSynchLocalNode(userDataType);
    var ourNode = localThis.localWaitList.exchange(dummyNext);

    var status = ourNode.status.read();
    if status == HSYNCH_WAITING {
      ourNode.request = request;
      ourNode.requestData = requestData;
      ourNode.next.write(dummyNext);

      while status == HSYNCH_WAITING {
        chpl_task_yield();
        status = ourNode.status.read();
      }
    }

    if status != HSYNCH_COMPLETE {
      if !localThis.isGlobalLockOwner.read() {
        acquireGlobalLock();
        localThis.isGlobalLockOwner.write(true);
      }
      request(localThis.userData, requestData);

      var tmpCurr = dummyNext;
      var tmpNext = tmpCurr.next.read();
      var count = 0;
      const HSYNCH_HELP_BOUND = 256;

      while tmpNext != nil && count < HSYNCH_HELP_BOUND {
        count = count + 1;
        tmpCurr.request(userData, tmpCurr.requestData);
        tmpCurr.status.write(HSYNCH_COMPLETE);

        tmpCurr = tmpNext;
        tmpNext = tmpCurr.next.read();
      }

      if tmpNext == nil {
        releaseGlobalLock();
        localThis.isGlobalLockOwner.write(false);
      }

      tmpCurr.status.write(HSYNCH_COMBINER);
    }

    delete ourNode;
  }
}
