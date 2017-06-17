// To cast from a pointer to an integer...
// __primitive("cast", uint, instance);
// To cast from a WIDE pointer to an integer...
// __primitive("_wide_get_addr", instance)
// To cast from a pointer to the object...
// __primitive("cast", instance.type, instance_address)

class queueNode {
  type eltType;
  var data: eltType;
  var next_addr: atomic uint;

  proc toString() : string {
    return "Data: " + data + ", Next: " + next_addr.read();
  }
}

class queue {
  type eltType;
  var error_value : eltType;
  var head_addr: atomic uint;
  var tail_addr: atomic uint;

  proc ref enqueue(elem: eltType) {
    var n = new queueNode(eltType, elem);
    n.next_addr.write(0);
    var n_addr = __primitive("cast", uint, n);

    var local_tail_addr : uint;
    var local_tail : queueNode(eltType);
    var local_next_addr : uint;
    var local_next : queueNode(eltType);
    while (true) {
      // Get the current tail
      local_tail_addr = tail_addr.read();
      local_tail = __primitive("cast", queueNode(eltType), local_tail_addr);

      // Sanity Check in case the actual tail changed
      if local_tail_addr != tail_addr.read() {
        continue;
      }

      // Obtain the potential tail.
      local_next_addr = local_tail.next_addr.read();
      local_next = __primitive("cast", queueNode(eltType), local_next_addr);

      // Sanity Check in case the actual tail changed again.
      if local_tail_addr != tail_addr.read() {
        continue;
      }

      // Note: If the tail's 'next' node is non-nil, another thread has set theirs
      // but did not update the tail correctly, so we fix it here.
      if local_next_addr != 0 {
        tail_addr.compareExchangeWeak(local_tail_addr, local_next_addr);
        continue;
      }

      // Append the node to our local tail.
      if local_tail.next_addr.compareExchangeWeak(0, n_addr) {
        break;
      }
    }
      // Fix the tail if someone else did not already do so
      tail_addr.compareExchangeStrong(local_tail_addr, n_addr);
  }

  proc ref dequeue() : (bool, eltType) {
    var local_tail_addr : uint;
    var local_tail : queueNode(eltType);
    var local_head_addr : uint;
    var local_head : queueNode(eltType);
    var local_next_addr : uint;
    var local_next : queueNode(eltType);
    var elem : eltType;

    while (true) {
      // Get head of queue
      local_head_addr = head_addr.read();
      local_head = __primitive("cast", queueNode(eltType), local_head_addr);

      // Sanity Check in case head of queue has changed.
      if local_head_addr != head_addr.read() {
        continue;
      }

      local_tail_addr = tail_addr.read();
      local_tail = __primitive("cast", queueNode(eltType), local_tail_addr);
      local_next_addr = local_head.next_addr.read();
      local_next = __primitive("cast", queueNode(eltType), local_next_addr);

      // Sanity check in case head of queue has changed.
      if head_addr.read() != local_head_addr {
        continue;
      }

      // Is Empty
      if (local_next_addr == 0) {
        return (false, error_value);
      }

      // If the head and the tail are the same, yet is not empty, then it is out of date
      // To fix it, we must advance the tail appropriately.
      if (local_head_addr == local_tail_addr) {
        tail_addr.compareExchangeWeak(local_tail_addr, local_next_addr);
        continue;
      }

      // The head node is always the dummy node, and since we know that 'next' is not NULL
      // at this point, we serve the item held by 'next'.
      elem = local_next.data;
      if head_addr.compareExchangeWeak(local_head_addr, local_next_addr) {
        break;
      }
    }

    return (true, elem);
  }

  proc initialize() {
    // Our dummy node
    var dummy = new queueNode(eltType);
    var dummy_addr = __primitive("cast", uint, dummy);

    dummy.next_addr.write(0);
    head_addr.write(dummy_addr);
    tail_addr.write(dummy_addr);
  }
}
