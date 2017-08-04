use BlockDist;

class PrivatizedExample {
  type eltType;
  var size;

  var pid : int;
  var space = {0..#size};
  var dom = space dmapped Block(boundingBox=space);
  var arr : [dom] eltType;

  inline proc getPrivatizedThis {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc PrivatizedExample(type eltType, size) {
    pid = _newPrivatizedClass(this);
  }

  proc PrivatizedExample(other, privData, type eltType = other.eltType, size = other.size) {
    arr = privData;
  }

  proc  dsiPrivatize(data) {
    return new PrivatizedExample(this, data);
  }

  proc dsiGetPrivatizeData() {
    return arr;
  }
}


var pe = new PrivatizedExample(int, 10000);

coforall loc in Locales do on loc {
  var localThis = pe.getPrivatizedThis;
  for e in localThis.arr {
    /*writeln(here, ": ", e, "->", e + 1);*/
    e = e + 1;
  }
}
