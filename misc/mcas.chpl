/*class example {
  var x : int = 0;
  var y : int = 1;
  var z : int = 2;
  var w : int = 3;
}

class Field {
  var data : atomic uint;
}

// Note: Assumes the field is at 'offset' is word sized.
proc getField(ref object, offset) : Field {
  var ptr = __primitive("cast", uint, object);
  var field = __primitive("cast", Field, ptr + offset);
  return field;
}

proc ptrOf(ref object) : uint {
  return __primitive("cast", uint, object);
}

enum MCASStatus {
  UNDECIDED,
  SUCCESSFUL,
  UNSUCCESSFUL
}

class MCASDescr {
  var status : MCASStatus = MCASStatus.UNDECIDED;
  var expected : example;
  var desired : example;
}

class CCASDesc {
  var addr : Field;
  var expected : uint;
  var want : uint;
  var cond : Field;
}



proc CCAS(addr : Field, expected : uint, want : uint, cond : Field) : uint {
  var desc = new CCASDesc(addr, expected, want, cond);
  while !desc.addr.data.compareExchangeWeak(desc.expected, ptrOf(desc)) {

  }
}

proc main() {
  var ex = new example(0, 1, 2, 3);
  writeln(__primitive("sizeof", ex));
  doSomething(ex);

  var expected = new example(1, 2, 3, 4);
  var want = new example(2, 3, 4, 5);
  var step = __primitive("sizeof", uint) : uint;
  var size = __primitive("sizeof", ex) : uint;
  var descr = new MCASDescr(expected = expected, desired = want);
  for offset in 0 .. size by step {
    var field = getField(ex, offset);
    var expectedField = getField(descr.expected, offset);
    field.data.compareExchangeStrong(expectedField.data.read(), __primitive("cast", uint, descr));
  }

  var success = true;
  for offset in 0 .. size by step {
    var field = getField(ex, offset);
    var wantField = getField(descr.desired, offset);
    var expectedField = getField(descr.expected, offset);
    field.data.compareExchangeStrong(__primitive("cast", uint, descr), wantField.data.read());
  }*/
  /*vptr = vptr + __primitive("sizeof", uint) : uint;*/
  /*var field = __primitive("cast", fieldSlot, vptr);*/
  /*writeln(ex);
}*/

/*


proc doSomething(ex : example) {
  ex.x = 1;
  ex.y = 2;
  ex.z = 3;
  ex.w = 4;
  writeln(ex);
}*/
