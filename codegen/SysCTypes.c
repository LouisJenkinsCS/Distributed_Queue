/* SysCTypes.chpl:1 */
static void chpl__init_SysCTypes(int64_t _ln_chpl,
                                 int32_t _fn_chpl) {
  _ref_int32_t refIndentLevel_chpl = NULL;
  uint64_t call_tmp_chpl;
  uint64_t call_tmp_chpl2;
  uint64_t call_tmp_chpl3;
  uint64_t call_tmp_chpl4;
  uint64_t call_tmp_chpl5;
  uint64_t call_tmp_chpl6;
  uint64_t call_tmp_chpl7;
  uint64_t call_tmp_chpl8;
  uint64_t call_tmp_chpl9;
  uint64_t call_tmp_chpl10;
  uint64_t call_tmp_chpl11;
  uint64_t call_tmp_chpl12;
  uint64_t call_tmp_chpl13;
  uint64_t call_tmp_chpl14;
  uint64_t call_tmp_chpl15;
  uint64_t call_tmp_chpl16;
  uint64_t call_tmp_chpl17;
  uint64_t call_tmp_chpl18;
  uint64_t call_tmp_chpl19;
  uint64_t call_tmp_chpl20;
  uint64_t call_tmp_chpl21;
  uint64_t call_tmp_chpl22;
  uint64_t call_tmp_chpl23;
  uint64_t call_tmp_chpl24;
  uint64_t call_tmp_chpl25;
  uint64_t call_tmp_chpl26;
  uint64_t call_tmp_chpl27;
  uint64_t call_tmp_chpl28;
  uint64_t call_tmp_chpl29;
  uint64_t call_tmp_chpl30;
  uint64_t call_tmp_chpl31;
  uint64_t call_tmp_chpl32;
  if (chpl__init_SysCTypes_p) {
    goto _exit_chpl__init_SysCTypes_chpl;
  }
  printModuleInit("%*s\n", "SysCTypes", INT64(9));
  refIndentLevel_chpl = &moduleInitLevel;
  *(refIndentLevel_chpl) += INT64(1);
  chpl__init_SysCTypes_p = UINT8(true);
  call_tmp_chpl = sizeof(c_int);
  call_tmp_chpl2 = sizeof(int32_t);
  assert_chpl((call_tmp_chpl == call_tmp_chpl2));
  call_tmp_chpl3 = sizeof(c_uint);
  call_tmp_chpl4 = sizeof(uint32_t);
  assert_chpl((call_tmp_chpl3 == call_tmp_chpl4));
  call_tmp_chpl5 = sizeof(c_long);
  call_tmp_chpl6 = sizeof(int64_t);
  assert_chpl((call_tmp_chpl5 == call_tmp_chpl6));
  call_tmp_chpl7 = sizeof(c_ulong);
  call_tmp_chpl8 = sizeof(uint64_t);
  assert_chpl((call_tmp_chpl7 == call_tmp_chpl8));
  call_tmp_chpl9 = sizeof(c_longlong);
  call_tmp_chpl10 = sizeof(int64_t);
  assert_chpl((call_tmp_chpl9 == call_tmp_chpl10));
  call_tmp_chpl11 = sizeof(c_ulonglong);
  call_tmp_chpl12 = sizeof(uint64_t);
  assert_chpl((call_tmp_chpl11 == call_tmp_chpl12));
  call_tmp_chpl13 = sizeof(c_char);
  call_tmp_chpl14 = sizeof(int8_t);
  assert_chpl((call_tmp_chpl13 == call_tmp_chpl14));
  call_tmp_chpl15 = sizeof(c_schar);
  call_tmp_chpl16 = sizeof(int8_t);
  assert_chpl((call_tmp_chpl15 == call_tmp_chpl16));
  call_tmp_chpl17 = sizeof(c_uchar);
  call_tmp_chpl18 = sizeof(uint8_t);
  assert_chpl((call_tmp_chpl17 == call_tmp_chpl18));
  call_tmp_chpl19 = sizeof(c_short);
  call_tmp_chpl20 = sizeof(int16_t);
  assert_chpl((call_tmp_chpl19 == call_tmp_chpl20));
  call_tmp_chpl21 = sizeof(c_ushort);
  call_tmp_chpl22 = sizeof(uint16_t);
  assert_chpl((call_tmp_chpl21 == call_tmp_chpl22));
  call_tmp_chpl23 = sizeof(c_intptr);
  call_tmp_chpl24 = sizeof(int64_t);
  assert_chpl((call_tmp_chpl23 == call_tmp_chpl24));
  call_tmp_chpl25 = sizeof(c_uintptr);
  call_tmp_chpl26 = sizeof(uint64_t);
  assert_chpl((call_tmp_chpl25 == call_tmp_chpl26));
  call_tmp_chpl27 = sizeof(c_ptrdiff);
  call_tmp_chpl28 = sizeof(int64_t);
  assert_chpl((call_tmp_chpl27 == call_tmp_chpl28));
  call_tmp_chpl29 = sizeof(ssize_t);
  call_tmp_chpl30 = sizeof(int64_t);
  assert_chpl((call_tmp_chpl29 == call_tmp_chpl30));
  call_tmp_chpl31 = sizeof(size_t);
  call_tmp_chpl32 = sizeof(uint64_t);
  assert_chpl((call_tmp_chpl31 == call_tmp_chpl32));
  *(refIndentLevel_chpl) -= INT64(1);
  _exit_chpl__init_SysCTypes_chpl:;
  return;
}
