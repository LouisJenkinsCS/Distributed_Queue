class Parent {
  type eltType;
  var x = 1;
  proc action() {
    writeln(this);
  }
}

class OtherChild : Parent {
  proc OtherChild(type eltType) {
    this.x = 3;
  }
}

class Child : Parent {

  var otherChild : Parent(eltType);

  proc Child(type eltType) { x = 2; otherChild = new OtherChild(eltType);}

  proc action() {
    writeln(this);
  }
}

var x = new Child(int);
x.action();
var y : Parent(int) = x;
y.action();
ref refParent = y;
refParent.action();
