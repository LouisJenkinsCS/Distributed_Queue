class Queue {
  type eltType;

  proc enqueue(elt : eltType) {
    halt("Enqueue Not Overloaded");
  }

  proc dequeue() : (bool, eltType) {
    halt ("Dequeue Not Overloaded");
  }
}
