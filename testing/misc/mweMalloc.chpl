var buffer : c_ptr(int);
on Locales[1] {
  on buffer do buffer = c_malloc(int, 1024);
}
for i in 1 .. 1024 do writeln(buffer[i]);
