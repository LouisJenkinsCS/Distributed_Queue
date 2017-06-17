var dom = {1..10};
var arr : [dom] int;

writeln(arr.domain);

proc test(ref dom) {
  dom = {1 .. 15};
}

test(dom);
writeln(arr.domain);
