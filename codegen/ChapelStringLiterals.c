/* <internal>:0 */
static void chpl__init_ChapelStringLiterals(int64_t _ln,
                                            int32_t _fn) {
  _ref_int32_t refIndentLevel = NULL;
  if (chpl__init_ChapelStringLiterals_p) {
    goto _exit_chpl__init_ChapelStringLiterals;
  }
  printModuleInit("%*s\n", "ChapelStringLiterals", INT64(20));
  refIndentLevel = &moduleInitLevel;
  *(refIndentLevel) += INT64(1);
  chpl__init_ChapelStringLiterals_p = UINT8(true);
  *(refIndentLevel) -= INT64(1);
  _exit_chpl__init_ChapelStringLiterals:;
  return;
}

/* ChapelBase.chpl:36 */
void chpl__initStringLiterals(void) {
  string ret_tmp;
  _ref_string ret_to_arg_ref_tmp_ = NULL;
  string ret_tmp2;
  _ref_string ret_to_arg_ref_tmp_2 = NULL;
  string ret_tmp3;
  _ref_string ret_to_arg_ref_tmp_3 = NULL;
  string ret_tmp4;
  _ref_string ret_to_arg_ref_tmp_4 = NULL;
  string ret_tmp5;
  _ref_string ret_to_arg_ref_tmp_5 = NULL;
  string ret_tmp6;
  _ref_string ret_to_arg_ref_tmp_6 = NULL;
  string ret_tmp7;
  _ref_string ret_to_arg_ref_tmp_7 = NULL;
  string ret_tmp8;
  _ref_string ret_to_arg_ref_tmp_8 = NULL;
  string ret_tmp9;
  _ref_string ret_to_arg_ref_tmp_9 = NULL;
  string ret_tmp10;
  _ref_string ret_to_arg_ref_tmp_10 = NULL;
  string ret_tmp11;
  _ref_string ret_to_arg_ref_tmp_11 = NULL;
  string ret_tmp12;
  _ref_string ret_to_arg_ref_tmp_12 = NULL;
  string ret_tmp13;
  _ref_string ret_to_arg_ref_tmp_13 = NULL;
  string ret_tmp14;
  _ref_string ret_to_arg_ref_tmp_14 = NULL;
  string ret_tmp15;
  _ref_string ret_to_arg_ref_tmp_15 = NULL;
  string ret_tmp16;
  _ref_string ret_to_arg_ref_tmp_16 = NULL;
  string ret_tmp17;
  _ref_string ret_to_arg_ref_tmp_17 = NULL;
  string ret_tmp18;
  _ref_string ret_to_arg_ref_tmp_18 = NULL;
  string ret_tmp19;
  _ref_string ret_to_arg_ref_tmp_19 = NULL;
  string ret_tmp20;
  _ref_string ret_to_arg_ref_tmp_20 = NULL;
  string ret_tmp21;
  _ref_string ret_to_arg_ref_tmp_21 = NULL;
  string ret_tmp22;
  _ref_string ret_to_arg_ref_tmp_22 = NULL;
  string ret_tmp23;
  _ref_string ret_to_arg_ref_tmp_23 = NULL;
  string ret_tmp24;
  _ref_string ret_to_arg_ref_tmp_24 = NULL;
  string ret_tmp25;
  _ref_string ret_to_arg_ref_tmp_25 = NULL;
  string ret_tmp26;
  _ref_string ret_to_arg_ref_tmp_26 = NULL;
  string ret_tmp27;
  _ref_string ret_to_arg_ref_tmp_27 = NULL;
  string ret_tmp28;
  _ref_string ret_to_arg_ref_tmp_28 = NULL;
  string ret_tmp29;
  _ref_string ret_to_arg_ref_tmp_29 = NULL;
  string ret_tmp30;
  _ref_string ret_to_arg_ref_tmp_30 = NULL;
  string ret_tmp31;
  _ref_string ret_to_arg_ref_tmp_31 = NULL;
  string ret_tmp32;
  _ref_string ret_to_arg_ref_tmp_32 = NULL;
  string ret_tmp33;
  _ref_string ret_to_arg_ref_tmp_33 = NULL;
  string ret_tmp34;
  _ref_string ret_to_arg_ref_tmp_34 = NULL;
  string ret_tmp35;
  _ref_string ret_to_arg_ref_tmp_35 = NULL;
  string ret_tmp36;
  _ref_string ret_to_arg_ref_tmp_36 = NULL;
  string ret_tmp37;
  _ref_string ret_to_arg_ref_tmp_37 = NULL;
  string ret_tmp38;
  _ref_string ret_to_arg_ref_tmp_38 = NULL;
  string ret_tmp39;
  _ref_string ret_to_arg_ref_tmp_39 = NULL;
  string ret_tmp40;
  _ref_string ret_to_arg_ref_tmp_40 = NULL;
  string ret_tmp41;
  _ref_string ret_to_arg_ref_tmp_41 = NULL;
  string ret_tmp42;
  _ref_string ret_to_arg_ref_tmp_42 = NULL;
  string ret_tmp43;
  _ref_string ret_to_arg_ref_tmp_43 = NULL;
  string ret_tmp44;
  _ref_string ret_to_arg_ref_tmp_44 = NULL;
  string ret_tmp45;
  _ref_string ret_to_arg_ref_tmp_45 = NULL;
  string ret_tmp46;
  _ref_string ret_to_arg_ref_tmp_46 = NULL;
  string ret_tmp47;
  _ref_string ret_to_arg_ref_tmp_47 = NULL;
  string ret_tmp48;
  _ref_string ret_to_arg_ref_tmp_48 = NULL;
  string ret_tmp49;
  _ref_string ret_to_arg_ref_tmp_49 = NULL;
  string ret_tmp50;
  _ref_string ret_to_arg_ref_tmp_50 = NULL;
  string ret_tmp51;
  _ref_string ret_to_arg_ref_tmp_51 = NULL;
  string ret_tmp52;
  _ref_string ret_to_arg_ref_tmp_52 = NULL;
  string ret_tmp53;
  _ref_string ret_to_arg_ref_tmp_53 = NULL;
  string ret_tmp54;
  _ref_string ret_to_arg_ref_tmp_54 = NULL;
  string ret_tmp55;
  _ref_string ret_to_arg_ref_tmp_55 = NULL;
  string ret_tmp56;
  _ref_string ret_to_arg_ref_tmp_56 = NULL;
  string ret_tmp57;
  _ref_string ret_to_arg_ref_tmp_57 = NULL;
  string ret_tmp58;
  _ref_string ret_to_arg_ref_tmp_58 = NULL;
  string ret_tmp59;
  _ref_string ret_to_arg_ref_tmp_59 = NULL;
  string ret_tmp60;
  _ref_string ret_to_arg_ref_tmp_60 = NULL;
  string ret_tmp61;
  _ref_string ret_to_arg_ref_tmp_61 = NULL;
  string ret_tmp62;
  _ref_string ret_to_arg_ref_tmp_62 = NULL;
  string ret_tmp63;
  _ref_string ret_to_arg_ref_tmp_63 = NULL;
  string ret_tmp64;
  _ref_string ret_to_arg_ref_tmp_64 = NULL;
  string ret_tmp65;
  _ref_string ret_to_arg_ref_tmp_65 = NULL;
  string ret_tmp66;
  _ref_string ret_to_arg_ref_tmp_66 = NULL;
  string ret_tmp67;
  _ref_string ret_to_arg_ref_tmp_67 = NULL;
  string ret_tmp68;
  _ref_string ret_to_arg_ref_tmp_68 = NULL;
  string ret_tmp69;
  _ref_string ret_to_arg_ref_tmp_69 = NULL;
  string ret_tmp70;
  _ref_string ret_to_arg_ref_tmp_70 = NULL;
  string ret_tmp71;
  _ref_string ret_to_arg_ref_tmp_71 = NULL;
  string ret_tmp72;
  _ref_string ret_to_arg_ref_tmp_72 = NULL;
  string ret_tmp73;
  _ref_string ret_to_arg_ref_tmp_73 = NULL;
  string ret_tmp74;
  _ref_string ret_to_arg_ref_tmp_74 = NULL;
  string ret_tmp75;
  _ref_string ret_to_arg_ref_tmp_75 = NULL;
  string ret_tmp76;
  _ref_string ret_to_arg_ref_tmp_76 = NULL;
  string ret_tmp77;
  _ref_string ret_to_arg_ref_tmp_77 = NULL;
  string ret_tmp78;
  _ref_string ret_to_arg_ref_tmp_78 = NULL;
  string ret_tmp79;
  _ref_string ret_to_arg_ref_tmp_79 = NULL;
  string ret_tmp80;
  _ref_string ret_to_arg_ref_tmp_80 = NULL;
  string ret_tmp81;
  _ref_string ret_to_arg_ref_tmp_81 = NULL;
  string ret_tmp82;
  _ref_string ret_to_arg_ref_tmp_82 = NULL;
  string ret_tmp83;
  _ref_string ret_to_arg_ref_tmp_83 = NULL;
  string ret_tmp84;
  _ref_string ret_to_arg_ref_tmp_84 = NULL;
  string ret_tmp85;
  _ref_string ret_to_arg_ref_tmp_85 = NULL;
  string ret_tmp86;
  _ref_string ret_to_arg_ref_tmp_86 = NULL;
  string ret_tmp87;
  _ref_string ret_to_arg_ref_tmp_87 = NULL;
  string ret_tmp88;
  _ref_string ret_to_arg_ref_tmp_88 = NULL;
  string ret_tmp89;
  _ref_string ret_to_arg_ref_tmp_89 = NULL;
  ret_to_arg_ref_tmp_ = &ret_tmp;
  string4(((c_ptr_uint8_t)("Pure virtual function called.")), INT64(29), INT64(30), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_);
  _str_literal_32 /* "Pure virtual function called." */ = ret_tmp;
  ret_to_arg_ref_tmp_2 = &ret_tmp2;
  string4(((c_ptr_uint8_t)("assert failed - ")), INT64(16), INT64(17), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_2);
  _str_literal_47 /* "assert failed - " */ = ret_tmp2;
  ret_to_arg_ref_tmp_3 = &ret_tmp3;
  string4(((c_ptr_uint8_t)("-")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_3);
  _str_literal_86 /* "-" */ = ret_tmp3;
  ret_to_arg_ref_tmp_4 = &ret_tmp4;
  string4(((c_ptr_uint8_t)("ArrayInit.heuristicInit should have been made concrete")), INT64(54), INT64(55), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_4);
  _str_literal_177 /* "ArrayInit.heuristicInit should have been made concrete" */ = ret_tmp4;
  ret_to_arg_ref_tmp_5 = &ret_tmp5;
  string4(((c_ptr_uint8_t)("Cannot call .c_str() on a remote string")), INT64(39), INT64(40), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_5);
  _str_literal_337 /* "Cannot call .c_str() on a remote string" */ = ret_tmp5;
  ret_to_arg_ref_tmp_6 = &ret_tmp6;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_6);
  _str_literal_349 /* "" */ = ret_tmp6;
  ret_to_arg_ref_tmp_7 = &ret_tmp7;
  string4(((c_ptr_uint8_t)(" \t\r\n")), INT64(4), INT64(5), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_7);
  _str_literal_370 /* " \t\r\n" */ = ret_tmp7;
  ret_to_arg_ref_tmp_8 = &ret_tmp8;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_8);
  _str_literal_372 /* "" */ = ret_tmp8;
  ret_to_arg_ref_tmp_9 = &ret_tmp9;
  string4(((c_ptr_uint8_t)("a")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_9);
  _str_literal_392 /* "a" */ = ret_tmp9;
  ret_to_arg_ref_tmp_10 = &ret_tmp10;
  string4(((c_ptr_uint8_t)(" ")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_10);
  _str_literal_400 /* " " */ = ret_tmp10;
  ret_to_arg_ref_tmp_11 = &ret_tmp11;
  string4(((c_ptr_uint8_t)("\n")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_11);
  _str_literal_404 /* "\n" */ = ret_tmp11;
  ret_to_arg_ref_tmp_12 = &ret_tmp12;
  string4(((c_ptr_uint8_t)(")")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_12);
  _str_literal_411 /* ")" */ = ret_tmp12;
  ret_to_arg_ref_tmp_13 = &ret_tmp13;
  string4(((c_ptr_uint8_t)(":")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_13);
  _str_literal_432 /* ":" */ = ret_tmp13;
  ret_to_arg_ref_tmp_14 = &ret_tmp14;
  string4(((c_ptr_uint8_t)("true")), INT64(4), INT64(5), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_14);
  _str_literal_563 /* "true" */ = ret_tmp14;
  ret_to_arg_ref_tmp_15 = &ret_tmp15;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_15);
  _str_literal_577 /* "" */ = ret_tmp15;
  ret_to_arg_ref_tmp_16 = &ret_tmp16;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_16);
  _str_literal_579 /* "" */ = ret_tmp16;
  ret_to_arg_ref_tmp_17 = &ret_tmp17;
  string4(((c_ptr_uint8_t)("[")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_17);
  _str_literal_581 /* "[" */ = ret_tmp17;
  ret_to_arg_ref_tmp_18 = &ret_tmp18;
  string4(((c_ptr_uint8_t)(", ")), INT64(2), INT64(3), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_18);
  _str_literal_583 /* ", " */ = ret_tmp18;
  ret_to_arg_ref_tmp_19 = &ret_tmp19;
  string4(((c_ptr_uint8_t)("]")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_19);
  _str_literal_585 /* "]" */ = ret_tmp19;
  ret_to_arg_ref_tmp_20 = &ret_tmp20;
  string4(((c_ptr_uint8_t)("(")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_20);
  _str_literal_587 /* "(" */ = ret_tmp20;
  ret_to_arg_ref_tmp_21 = &ret_tmp21;
  string4(((c_ptr_uint8_t)("With a negative count, the range must have a last index.")), INT64(56), INT64(57), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_21);
  _str_literal_723 /* "With a negative count, the range must have a last index." */ = ret_tmp21;
  ret_to_arg_ref_tmp_22 = &ret_tmp22;
  string4(((c_ptr_uint8_t)("'")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_22);
  _str_literal_854 /* "'" */ = ret_tmp22;
  ret_to_arg_ref_tmp_23 = &ret_tmp23;
  string4(((c_ptr_uint8_t)("Cannot create additional LocaleModel instances")), INT64(46), INT64(47), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_23);
  _str_literal_881 /* "Cannot create additional LocaleModel instances" */ = ret_tmp23;
  ret_to_arg_ref_tmp_24 = &ret_tmp24;
  string4(((c_ptr_uint8_t)("dataParTasksPerLocale must be >= 0")), INT64(34), INT64(35), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_24);
  _str_literal_916 /* "dataParTasksPerLocale must be >= 0" */ = ret_tmp24;
  ret_to_arg_ref_tmp_25 = &ret_tmp25;
  string4(((c_ptr_uint8_t)("dataParMinGranularity must be > 0")), INT64(33), INT64(34), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_25);
  _str_literal_918 /* "dataParMinGranularity must be > 0" */ = ret_tmp25;
  ret_to_arg_ref_tmp_26 = &ret_tmp26;
  string4(((c_ptr_uint8_t)("array index out of bounds: ")), INT64(27), INT64(28), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_26);
  _str_literal_1075 /* "array index out of bounds: " */ = ret_tmp26;
  ret_to_arg_ref_tmp_27 = &ret_tmp27;
  string4(((c_ptr_uint8_t)("illegal reallocation")), INT64(20), INT64(21), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_27);
  _str_literal_1079 /* "illegal reallocation" */ = ret_tmp27;
  ret_to_arg_ref_tmp_28 = &ret_tmp28;
  string4(((c_ptr_uint8_t)("[\n")), INT64(2), INT64(3), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_28);
  _str_literal_1093 /* "[\n" */ = ret_tmp28;
  ret_to_arg_ref_tmp_29 = &ret_tmp29;
  string4(((c_ptr_uint8_t)(",\n")), INT64(2), INT64(3), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_29);
  _str_literal_1096 /* ",\n" */ = ret_tmp29;
  ret_to_arg_ref_tmp_30 = &ret_tmp30;
  string4(((c_ptr_uint8_t)("BulkTransferStride: stride levels greater than rank.")), INT64(52), INT64(53), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_30);
  _str_literal_1169 /* "BulkTransferStride: stride levels greater than rank." */ = ret_tmp30;
  ret_to_arg_ref_tmp_31 = &ret_tmp31;
  string4(((c_ptr_uint8_t)("BulkTransferStride: bulk-count incorrect for stride level of 0.")), INT64(63), INT64(64), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_31);
  _str_literal_1171 /* "BulkTransferStride: bulk-count incorrect for stride level of 0." */ = ret_tmp31;
  ret_to_arg_ref_tmp_32 = &ret_tmp32;
  string4(((c_ptr_uint8_t)("internal error: dsiMyDist is not implemented")), INT64(44), INT64(45), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_32);
  _str_literal_1589 /* "internal error: dsiMyDist is not implemented" */ = ret_tmp32;
  ret_to_arg_ref_tmp_33 = &ret_tmp33;
  string4(((c_ptr_uint8_t)("internal error: dsiGetBaseDom is not implemented")), INT64(48), INT64(49), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_33);
  _str_literal_1623 /* "internal error: dsiGetBaseDom is not implemented" */ = ret_tmp33;
  ret_to_arg_ref_tmp_34 = &ret_tmp34;
  string4(((c_ptr_uint8_t)("reallocating not supported for this array type")), INT64(46), INT64(47), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_34);
  _str_literal_1626 /* "reallocating not supported for this array type" */ = ret_tmp34;
  ret_to_arg_ref_tmp_35 = &ret_tmp35;
  string4(((c_ptr_uint8_t)("_backupArray() not supported for non-associative arrays")), INT64(55), INT64(56), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_35);
  _str_literal_1640 /* "_backupArray() not supported for non-associative arrays" */ = ret_tmp35;
  ret_to_arg_ref_tmp_36 = &ret_tmp36;
  string4(((c_ptr_uint8_t)("_removeArrayBackup() not supported for non-associative arrays")), INT64(61), INT64(62), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_36);
  _str_literal_1642 /* "_removeArrayBackup() not supported for non-associative arrays" */ = ret_tmp36;
  ret_to_arg_ref_tmp_37 = &ret_tmp37;
  string4(((c_ptr_uint8_t)("_preserveArrayElement() not supported for non-associative arrays")), INT64(64), INT64(65), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_37);
  _str_literal_1644 /* "_preserveArrayElement() not supported for non-associative arrays" */ = ret_tmp37;
  ret_to_arg_ref_tmp_38 = &ret_tmp38;
  string4(((c_ptr_uint8_t)("halt reached - ")), INT64(15), INT64(16), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_38);
  _str_literal_1675 /* "halt reached - " */ = ret_tmp38;
  ret_to_arg_ref_tmp_39 = &ret_tmp39;
  string4(((c_ptr_uint8_t)("couldn't add ")), INT64(13), INT64(14), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_39);
  _str_literal_1764 /* "couldn't add " */ = ret_tmp39;
  ret_to_arg_ref_tmp_40 = &ret_tmp40;
  string4(((c_ptr_uint8_t)(" -- ")), INT64(4), INT64(5), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_40);
  _str_literal_1766 /* " -- " */ = ret_tmp40;
  ret_to_arg_ref_tmp_41 = &ret_tmp41;
  string4(((c_ptr_uint8_t)(" / ")), INT64(3), INT64(4), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_41);
  _str_literal_1768 /* " / " */ = ret_tmp41;
  ret_to_arg_ref_tmp_42 = &ret_tmp42;
  string4(((c_ptr_uint8_t)(" taken")), INT64(6), INT64(7), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_42);
  _str_literal_1770 /* " taken" */ = ret_tmp42;
  ret_to_arg_ref_tmp_43 = &ret_tmp43;
  string4(((c_ptr_uint8_t)("associative array exceeds maximum size")), INT64(38), INT64(39), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_43);
  _str_literal_1782 /* "associative array exceeds maximum size" */ = ret_tmp43;
  ret_to_arg_ref_tmp_44 = &ret_tmp44;
  string4(((c_ptr_uint8_t)("cannot implicitly add to an array's domain when the domain is used by more than one array: ")), INT64(91), INT64(92), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_44);
  _str_literal_1788 /* "cannot implicitly add to an array's domain when the domain is used by more than one array: " */ = ret_tmp44;
  ret_to_arg_ref_tmp_45 = &ret_tmp45;
  string4(((c_ptr_uint8_t)("zippered associative array does not match the iterated domain")), INT64(61), INT64(62), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_45);
  _str_literal_1798 /* "zippered associative array does not match the iterated domain" */ = ret_tmp45;
  ret_to_arg_ref_tmp_46 = &ret_tmp46;
  string4(((c_ptr_uint8_t)("To use task tracking, you must recompile with --task-tracking")), INT64(61), INT64(62), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_46);
  _str_literal_1857 /* "To use task tracking, you must recompile with --task-tracking" */ = ret_tmp46;
  ret_to_arg_ref_tmp_47 = &ret_tmp47;
  string4(((c_ptr_uint8_t)("false")), INT64(5), INT64(6), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_47);
  _str_literal_1867 /* "false" */ = ret_tmp47;
  ret_to_arg_ref_tmp_48 = &ret_tmp48;
  string4(((c_ptr_uint8_t)("Unexpected value when converting from string to bool: '")), INT64(55), INT64(56), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_48);
  _str_literal_1869 /* "Unexpected value when converting from string to bool: '" */ = ret_tmp48;
  ret_to_arg_ref_tmp_49 = &ret_tmp49;
  string4(((c_ptr_uint8_t)("Starting FCHQueue Proof-Of-Correctness Test ~ nElementForFCHQueue=")), INT64(66), INT64(67), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_49);
  _str_literal_1936 /* "Starting FCHQueue Proof-Of-Correctness Test ~ nElementForFCHQueue=" */ = ret_tmp49;
  ret_to_arg_ref_tmp_50 = &ret_tmp50;
  string4(((c_ptr_uint8_t)("BAD RESULT! Expected ")), INT64(21), INT64(22), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_50);
  _str_literal_1940 /* "BAD RESULT! Expected " */ = ret_tmp50;
  ret_to_arg_ref_tmp_51 = &ret_tmp51;
  string4(((c_ptr_uint8_t)(", Received ")), INT64(11), INT64(12), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_51);
  _str_literal_1942 /* ", Received " */ = ret_tmp51;
  ret_to_arg_ref_tmp_52 = &ret_tmp52;
  string4(((c_ptr_uint8_t)("PASSED!")), INT64(7), INT64(8), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_52);
  _str_literal_1944 /* "PASSED!" */ = ret_tmp52;
  ret_to_arg_ref_tmp_53 = &ret_tmp53;
  string4(((c_ptr_uint8_t)("Bad Functor (by Ref)...")), INT64(23), INT64(24), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_53);
  _str_literal_1966 /* "Bad Functor (by Ref)..." */ = ret_tmp53;
  ret_to_arg_ref_tmp_54 = &ret_tmp54;
  string4(((c_ptr_uint8_t)("A bit was not found!!! Bitmap: ")), INT64(31), INT64(32), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_54);
  _str_literal_1990 /* "A bit was not found!!! Bitmap: " */ = ret_tmp54;
  ret_to_arg_ref_tmp_55 = &ret_tmp55;
  string4(((c_ptr_uint8_t)("Descriptor is 0!")), INT64(16), INT64(17), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_55);
  _str_literal_1993 /* "Descriptor is 0!" */ = ret_tmp55;
  ret_to_arg_ref_tmp_56 = &ret_tmp56;
  string4(((c_ptr_uint8_t)("pop_front on empty list")), INT64(23), INT64(24), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_56);
  _str_literal_2009 /* "pop_front on empty list" */ = ret_tmp56;
  ret_to_arg_ref_tmp_57 = &ret_tmp57;
  string4(((c_ptr_uint8_t)("used to create a Replicated")), INT64(27), INT64(28), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_57);
  _str_literal_2011 /* "used to create a Replicated" */ = ret_tmp57;
  ret_to_arg_ref_tmp_58 = &ret_tmp58;
  string4(((c_ptr_uint8_t)("used during privatization")), INT64(25), INT64(26), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_58);
  _str_literal_2022 /* "used during privatization" */ = ret_tmp58;
  ret_to_arg_ref_tmp_59 = &ret_tmp59;
  string4(((c_ptr_uint8_t)("Operation attempted on an invalid file")), INT64(38), INT64(39), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_59);
  _str_literal_2397 /* "Operation attempted on an invalid file" */ = ret_tmp59;
  ret_to_arg_ref_tmp_60 = &ret_tmp60;
  string4(((c_ptr_uint8_t)("in file.close")), INT64(13), INT64(14), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_60);
  _str_literal_2400 /* "in file.close" */ = ret_tmp60;
  ret_to_arg_ref_tmp_61 = &ret_tmp61;
  string4(((c_ptr_uint8_t)("unknown")), INT64(7), INT64(8), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_61);
  _str_literal_2406 /* "unknown" */ = ret_tmp61;
  ret_to_arg_ref_tmp_62 = &ret_tmp62;
  string4(((c_ptr_uint8_t)("r")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_62);
  _str_literal_2413 /* "r" */ = ret_tmp62;
  ret_to_arg_ref_tmp_63 = &ret_tmp63;
  string4(((c_ptr_uint8_t)("r+")), INT64(2), INT64(3), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_63);
  _str_literal_2415 /* "r+" */ = ret_tmp63;
  ret_to_arg_ref_tmp_64 = &ret_tmp64;
  string4(((c_ptr_uint8_t)("w")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_64);
  _str_literal_2417 /* "w" */ = ret_tmp64;
  ret_to_arg_ref_tmp_65 = &ret_tmp65;
  string4(((c_ptr_uint8_t)("w+")), INT64(2), INT64(3), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_65);
  _str_literal_2419 /* "w+" */ = ret_tmp65;
  ret_to_arg_ref_tmp_66 = &ret_tmp66;
  string4(((c_ptr_uint8_t)("in openfd")), INT64(9), INT64(10), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_66);
  _str_literal_2475 /* "in openfd" */ = ret_tmp66;
  ret_to_arg_ref_tmp_67 = &ret_tmp67;
  string4(((c_ptr_uint8_t)("in openfp")), INT64(9), INT64(10), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_67);
  _str_literal_2477 /* "in openfp" */ = ret_tmp67;
  ret_to_arg_ref_tmp_68 = &ret_tmp68;
  string4(((c_ptr_uint8_t)("in openmem")), INT64(10), INT64(11), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_68);
  _str_literal_2481 /* "in openmem" */ = ret_tmp68;
  ret_to_arg_ref_tmp_69 = &ret_tmp69;
  string4(((c_ptr_uint8_t)("in lock")), INT64(7), INT64(8), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_69);
  _str_literal_2495 /* "in lock" */ = ret_tmp69;
  ret_to_arg_ref_tmp_70 = &ret_tmp70;
  string4(((c_ptr_uint8_t)("in file.reader")), INT64(14), INT64(15), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_70);
  _str_literal_2522 /* "in file.reader" */ = ret_tmp70;
  ret_to_arg_ref_tmp_71 = &ret_tmp71;
  string4(((c_ptr_uint8_t)("in file.writer")), INT64(14), INT64(15), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_71);
  _str_literal_2529 /* "in file.writer" */ = ret_tmp71;
  ret_to_arg_ref_tmp_72 = &ret_tmp72;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_72);
  _str_literal_2566 /* "" */ = ret_tmp72;
  ret_to_arg_ref_tmp_73 = &ret_tmp73;
  string4(((c_ptr_uint8_t)("b")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_73);
  _str_literal_2569 /* "b" */ = ret_tmp73;
  ret_to_arg_ref_tmp_74 = &ret_tmp74;
  string4(((c_ptr_uint8_t)("c")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_74);
  _str_literal_2571 /* "c" */ = ret_tmp74;
  ret_to_arg_ref_tmp_75 = &ret_tmp75;
  string4(((c_ptr_uint8_t)("d")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_75);
  _str_literal_2573 /* "d" */ = ret_tmp75;
  ret_to_arg_ref_tmp_76 = &ret_tmp76;
  string4(((c_ptr_uint8_t)("e")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_76);
  _str_literal_2575 /* "e" */ = ret_tmp76;
  ret_to_arg_ref_tmp_77 = &ret_tmp77;
  string4(((c_ptr_uint8_t)("f")), INT64(1), INT64(2), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_77);
  _str_literal_2577 /* "f" */ = ret_tmp77;
  ret_to_arg_ref_tmp_78 = &ret_tmp78;
  string4(((c_ptr_uint8_t)("in channel.write(")), INT64(17), INT64(18), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_78);
  _str_literal_2615 /* "in channel.write(" */ = ret_tmp78;
  ret_to_arg_ref_tmp_79 = &ret_tmp79;
  string4(((c_ptr_uint8_t)("")), INT64(0), INT64(0), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_79);
  _str_literal_2617 /* "" */ = ret_tmp79;
  ret_to_arg_ref_tmp_80 = &ret_tmp80;
  string4(((c_ptr_uint8_t)("in channel.close")), INT64(16), INT64(17), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_80);
  _str_literal_2629 /* "in channel.close" */ = ret_tmp80;
  ret_to_arg_ref_tmp_81 = &ret_tmp81;
  string4(((c_ptr_uint8_t)("bad remote channel.readBytes")), INT64(28), INT64(29), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_81);
  _str_literal_2631 /* "bad remote channel.readBytes" */ = ret_tmp81;
  ret_to_arg_ref_tmp_82 = &ret_tmp82;
  string4(((c_ptr_uint8_t)("in channel.readBytes")), INT64(20), INT64(21), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_82);
  _str_literal_2633 /* "in channel.readBytes" */ = ret_tmp82;
  ret_to_arg_ref_tmp_83 = &ret_tmp83;
  string4(((c_ptr_uint8_t)(" with path ")), INT64(11), INT64(12), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_83);
  _str_literal_2821 /* " with path " */ = ret_tmp83;
  ret_to_arg_ref_tmp_84 = &ret_tmp84;
  string4(((c_ptr_uint8_t)(" offset ")), INT64(8), INT64(9), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_84);
  _str_literal_2823 /* " offset " */ = ret_tmp84;
  ret_to_arg_ref_tmp_85 = &ret_tmp85;
  string4(((c_ptr_uint8_t)("string")), INT64(6), INT64(7), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_85);
  _str_literal_3382 /* "string" */ = ret_tmp85;
  ret_to_arg_ref_tmp_86 = &ret_tmp86;
  string4(((c_ptr_uint8_t)("int(64)")), INT64(7), INT64(8), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_86);
  _str_literal_3384 /* "int(64)" */ = ret_tmp86;
  ret_to_arg_ref_tmp_87 = &ret_tmp87;
  string4(((c_ptr_uint8_t)("ioNewline")), INT64(9), INT64(10), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_87);
  _str_literal_3386 /* "ioNewline" */ = ret_tmp87;
  ret_to_arg_ref_tmp_88 = &ret_tmp88;
  string4(((c_ptr_uint8_t)("_array(DefaultRectangularArr(uint(64),1,int(64),false,int(64)))")), INT64(63), INT64(64), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_88);
  _str_literal_3585 /* "_array(DefaultRectangularArr(uint(64),1,int(64),false,int(64)))" */ = ret_tmp88;
  ret_to_arg_ref_tmp_89 = &ret_tmp89;
  string4(((c_ptr_uint8_t)("(bool,int(64))")), INT64(14), INT64(15), UINT8(false), UINT8(false), ret_to_arg_ref_tmp_89);
  _str_literal_3596 /* "(bool,int(64))" */ = ret_tmp89;
  return;
}
