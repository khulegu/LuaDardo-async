import 'dart:typed_data';

import '../state/lua_userdata.dart';

import 'lua_type.dart';

abstract class LuaBasicAPI {
/* basic stack manipulation */
  int getTop();

  int absIndex(int idx);

  bool checkStack(int n);

  void pop(int n);

  void copy(int fromIdx, int toIdx);

  void pushValue(int idx);

  void replace(int idx);

  void insert(int idx);

  void remove(int idx);

  void rotate(int idx, int n);

  void setTop(int idx);

/* access functions (stack -> Go); */
  String typeName(LuaType tp);

  LuaType type(int idx);

  bool isNone(int idx);

  bool isNil(int idx);

  bool isNoneOrNil(int idx);

  bool isBoolean(int idx);

  bool isInteger(int idx);

  bool isNumber(int idx);

  bool isString(int idx);

  bool isTable(int idx);

  bool isThread(int idx);

  bool isFunction(int idx);

  bool isDartFunction(int idx);

  bool isUserdata(int idx);

  bool toBoolean(int idx);

  int toInteger(int idx);

  int? toIntegerX(int idx);

  double toNumber(int idx);

  double? toNumberX(int idx);

  String? toStr(int idx);

  DartFunction? toDartFunction(int idx);

  Object? toPointer(int idx);

  Userdata? toUserdata<T>(int idx);

  int rawLen(int idx);

/* push functions (Go -> stack); */
  void pushNil();

  void pushBoolean(bool b);

  void pushInteger(int? n);

  void pushNumber(double n);

  void pushString(String? s);

  void pushFString(String fmt, [List<Object>? a]);

  void pushDartFunction(DartFunctionAsync f);

  void pushDartClosure(DartFunctionAsync f, int n);

  void pushGlobalTable();

/* comparison and arithmetic functions */
  Future<void> arith(ArithOp op);

  Future<bool> compare(int idx1, int idx2, CmpOp op);

  Future<bool> rawEqual(int idx1, int idx2);

/* get functions (Lua -> stack) */
  void newTable();

  Userdata newUserdata<T>();

  void createTable(int nArr, int nRec);

  Future<LuaType> getTable(int idx);

  Future<LuaType> getField(int idx, String? k);

  Future<LuaType> getI(int idx, int i);

  Future<LuaType> rawGet(int idx);

  Future<LuaType> rawGetI(int idx, int i);

  Future<LuaType> getGlobal(String name);

  bool getMetatable(int idx);

/* set functions (stack -> Lua) */
  Future<void> setTable(int idx);

  Future<void> setField(int idx, String? k);

  Future<void> setI(int idx, int? i);

  Future<void> rawSet(int idx);

  Future<void> rawSetI(int idx, int i);

  void setMetatable(int idx);

  Future<void> setGlobal(String name);

  void register(String name, DartFunction f);

  void registerAsync(String name, DartFunctionAsync f);

/* 'load' and 'call' functions (load and run Lua code) */
  ThreadStatus load(Uint8List chunk, String chunkName, String? mode);

  Future<void> call(int nArgs, int nResults);

  Future<ThreadStatus> pCall(int nArgs, int nResults, int msgh);

/* miscellaneous functions */
  Future<void> len(int idx);

  Future<void> concat(int n);

  bool next(int idx);

  int error();

  bool stringToNumber(String s);
}
