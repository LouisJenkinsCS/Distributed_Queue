/* Time.chpl:30 */
static void chpl__init_Time(int64_t _ln_chpl,
                            int32_t _fn_chpl) {
  _ref_int32_t refIndentLevel_chpl = NULL;
  if (chpl__init_Time_p) {
    goto _exit_chpl__init_Time_chpl;
  }
  printModuleInit("%*s\n", "Time", INT64(4));
  refIndentLevel_chpl = &moduleInitLevel;
  *(refIndentLevel_chpl) += INT64(1);
  chpl__init_Time_p = UINT8(true);
  *(refIndentLevel_chpl) -= INT64(1);
  _exit_chpl__init_Time_chpl:;
  return;
}
