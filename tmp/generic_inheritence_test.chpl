class Parent {
  type eltType;
  var x = 1;
  proc action() {
    halt("Bad...");
  }
}

class OtherChild : Parent {
  var fcf : func(int) = nil;
  proc OtherChild(type eltType) {
    this.x = 3;
  }

  proc action() {
    halt("Bad2...");
  }
}

class Child : Parent {

  var otherChild : Parent(eltType);

  proc Child(type eltType) { x = 2; otherChild = new OtherChild(eltType);}

  proc action() {
    writeln(this, "\n", otherChild.x);
  }
}

var x = new Child(4 * int);
x.action();
var y : Parent(4 * int) = x;
y.action();
ref refParent = y;
refParent.action();
