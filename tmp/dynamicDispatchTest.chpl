class Parent {
  type eltType;

  proc overloadThisOrCrash() {
    halt("Not Overloaded...");
  }
}

class Child : Parent {
  proc Child(type eltType) {
    writeln("Child created...");
  }

  proc overloadThisOrCrash() {
    writeln("Overloaded!");
  }
}

proc main() {
  var child : Parent(26 * int) = new Child(26 * int);
  child.overloadThisOrCrash();
}
