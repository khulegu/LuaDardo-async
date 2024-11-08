import '../api/lua_state.dart';
import '../api/lua_type.dart';

const MAX_LEN = 1000000; // TODO

///
/// Operations that an object must define to mimic a table
/// (some functions only need some of them)
const TAB_R = 1; /* read */
const TAB_W = 2; /* write */
const TAB_L = 4; /* length */
const TAB_RW = (TAB_R | TAB_W); /* read/write */

class TableLib {

  static final Map<String, DartFunctionAsync> _tabFuncs = {
    "move": _tabMove,
    "insert": _tabInsert,
    "remove": _tabRemove,
    "sort": _tabSort,
    "concat": _tabConcat,
    "pack": _tabPack,
    "unpack": _tabUnpack,
  };

  static Future<int> openTableLib(LuaState ls) async {


    //await ls.newLib(_tabFuncs);
    ls.pushGlobalTable();
    await ls.setFuncsAsync(_tabFuncs, 0); // Replace tablib with global because it's broken
    return 1;
  }

  // table.move (a1, f, e, t [,a2])
// http://www.lua.org/manual/5.3/manual.html#pdf-table.move
// lua-5.3.4/src/ltablib.c#tremove()
  static Future<int> _tabMove(LuaState ls) async {
    var f = (await ls.checkInteger(2))!;
    var e = (await ls.checkInteger(3))!;
    var t = await ls.checkInteger(4);
    var tt = 1; /* destination table */
    if (!ls.isNoneOrNil(5)) {
      tt = 5;
    }
    await _checkTab(ls, 1, TAB_R);
    await _checkTab(ls, tt, TAB_W);
    if (e >= f) {
      /* otherwise, nothing to move */
      int i;
      ls.argCheck(
          f > 0 || e < luaMaxInteger + f, 3, "too many elements to move");
      var n = e - f + 1; /* number of elements to move */
      ls.argCheck(t! <= luaMaxInteger - n + 1, 4, "destination wrap around");
      if (t > e || t <= f || (tt != 1 && !await ls.compare(1, tt, CmpOp.luaOpEq))) {
        for (i = 0; i < n; i++) {
          await ls.getI(1, f + i);
          await ls.setI(tt, t + i);
        }
      } else {
        for (i = n - 1; i >= 0; i--) {
          await ls.getI(1, f + i);
          await ls.setI(tt, t + i);
        }
      }
    }
    ls.pushValue(tt); /* return destination table */
    return 1;
  }

// table.insert (list, [pos,] value)
// http://www.lua.org/manual/5.3/manual.html#pdf-table.insert
// lua-5.3.4/src/ltablib.c#tinsert()
  static Future<int> _tabInsert(LuaState ls) async {
    var e = (await _auxGetN(ls, 1, TAB_RW))! + 1; /* first empty element */
    int? pos; /* where to insert new element */
    switch (ls.getTop()) {
      case 2:
        /* called with only 2 arguments */
        pos = e;
        /* insert new element at the end */
        break;
      case 3:
        pos = await ls.checkInteger(2);
        /* 2nd argument is the position */
        ls.argCheck(1 <= pos! && pos <= e, 2, "position out of bounds");
        for (var i = e; i > pos; i--) {
          /* move up elements */
          await ls.getI(1, i - 1);
          await ls.setI(1, i); /* t[i] = t[i - 1] */
        }
        break;
      default:
        return ls.error2("wrong number of arguments to 'insert'");
    }
    await ls.setI(1, pos); /* t[pos] = v */
    return 0;
  }

// table.remove (list [, pos])
// http://www.lua.org/manual/5.3/manual.html#pdf-table.remove
// lua-5.3.4/src/ltablib.c#tremove()
  static Future<int> _tabRemove(LuaState ls) async {
    var size = (await _auxGetN(ls, 1, TAB_RW))!;
    var pos = (await ls.optInteger(2, size))!;
    if (pos != size) {
      /* validate 'pos' if given */
      ls.argCheck(1 <= pos && pos <= size + 1, 1, "position out of bounds");
    }
    await ls.getI(1, pos); /* result = t[pos] */
    for (; pos < size; pos++) {
      await ls.getI(1, pos + 1);
      await ls.setI(1, pos); /* t[pos] = t[pos + 1] */
    }
    ls.pushNil();
    await ls.setI(1, pos); /* t[pos] = nil */
    return 1;
  }

// table.concat (list [, sep [, i [, j]]])
// http://www.lua.org/manual/5.3/manual.html#pdf-table.concat
// lua-5.3.4/src/ltablib.c#tconcat()
  static Future<int> _tabConcat(LuaState ls) async {
    var tabLen = await _auxGetN(ls, 1, TAB_R);
    var sep = ls.optString(2, "");
    var i = (await ls.optInteger(3, 1))!;
    var j = (await ls.optInteger(4, tabLen))!;

    if (i > j) {
      ls.pushString("");
      return 1;
    }

    var buf = List<String?>.filled(j - i + 1,null);
    for (var k = i; k > 0 && k <= j; k++) {
      await ls.getI(1, k);
      if (!ls.isString(-1)) {
        ls.error2("invalid value (%s) at index %d in table for 'concat'",
            [ls.typeName2(-1), i]);
      }
      buf[k - i] = ls.toStr(-1);
      ls.pop(1);
    }
    ls.pushString(buf.join(sep!));

    return 1;
  }

  static Future<int?> _auxGetN(LuaState ls, int n, int w) async {
    await _checkTab(ls, n, w | TAB_L);
    return await ls.len2(n);
  }

/*
** Check that 'arg' either is a table or can behave like one (that is,
** has a metatable with the required metamethods)
 */
  static _checkTab(LuaState ls, int arg, int what) async {
    if (ls.type(arg) != LuaType.luaTable) {
      /* is it not a table? */
      var n = 1; /* number of elements to pop */
      var nL = List<int>.filled(1,0)..[0] = n;
      if (ls.getMetatable(arg) && /* must have metatable */
          (what & TAB_R != 0 || await _checkField(ls, "__index", nL)) &&
          (what & TAB_W != 0 || await _checkField(ls, "__newindex", nL)) &&
          (what & TAB_L != 0 || await _checkField(ls, "__len", nL))) {
        ls.pop(n); /* pop metatable and tested metamethods */
      } else {
        ls.checkType(arg, LuaType.luaTable); /* force an error */
      }
    }
  }

  static Future<bool> _checkField(LuaState ls, String key, List<int> nL) async {
    ls.pushString(key);
    nL[0]++;
    return await ls.rawGet(-nL[0]) != LuaType.luaNil;
  }

/* Pack/unpack */

// table.pack (···)
// http://www.lua.org/manual/5.3/manual.html#pdf-table.pack
// lua-5.3.4/src/ltablib.c#pack()
  static Future<int> _tabPack(LuaState ls) async {
    var n = ls.getTop(); /* number of elements to pack */
    ls.createTable(n, 1); /* create result table */
    ls.insert(1); /* put it at index 1 */
    for (var i = n; i >= 1; i--) {
      /* assign elements */
      await ls.setI(1, i);
    }
    ls.pushInteger(n);
    await ls.setField(1, "n"); /* t.n = number of elements */
    return 1; /* return table */
  }

// table.unpack (list [, i [, j]])
// http://www.lua.org/manual/5.3/manual.html#pdf-table.unpack
// lua-5.3.4/src/ltablib.c#unpack()
  static Future<int> _tabUnpack(LuaState ls) async {
    var i = (await ls.optInteger(2, 1))!;
    var e = (await ls.optInteger(3, await ls.len2(1)))!;
    if (i > e) {
      /* empty range */
      return 0;
    }

    var n = e - i + 1;
    if (n <= 0 || n >= MAX_LEN || !ls.checkStack(n)) {
      return ls.error2("too many results to unpack");
    }

    for (; i < e; i++) {
      /* push arg[i..e - 1] (to avoid overflows) */
      await ls.getI(1, i);
    }
    await ls.getI(1, e); /* push last element */
    return n;
  }

/* sort */

// table.sort (list [, comp])
// http://www.lua.org/manual/5.3/manual.html#pdf-table.sort
  static Future<int> _tabSort(LuaState ls) async {
    var sort = _SortHelper(ls);
    var len = (await sort.len())!;
    ls.argCheck(len < MAX_LEN, 1, "array too big");
    await sort.quickSort(0, len - 1);
    return 0;
  }
}

class _SortHelper {
  LuaState ls;

  _SortHelper(this.ls);

  Future<int?> len() async {
    return await ls.len2(1);
  }

  Future<bool> _less(int i, int j) async {
    if (ls.isFunction(2)) {
      // cmp is given
      ls.pushValue(2);
      await ls.getI(1, i + 1);
      await ls.getI(1, j + 1);
      await ls.call(2, 1);
      var b = ls.toBoolean(-1);
      ls.pop(1);
      return b;
    } else {
      // cmp is missing
      await ls.getI(1, i + 1);
      await ls.getI(1, j + 1);
      var b = await ls.compare(-2, -1, CmpOp.luaOpLt);
      ls.pop(2);
      return b;
    }
  }

  Future<void> _swap(int i, int j) async {
    await ls.getI(1, i + 1);
    await ls.getI(1, j + 1);
    await ls.setI(1, i + 1);
    await ls.setI(1, j + 1);
  }

  Future<int> _partition(int low, int high) async {
    int i = low;
    int j = high + 1;

    while (true) {
      // find item on low to swap
      while (await _less(++i, low)) {
        if (i == high) {
          break;
        }
      }

      // find item on high to swap
      while (await _less(low, --j)) {
        if (j == low) {
          break;
        }
      }

      // check if pointers cross
      if (i >= j) {
        break;
      }

      await _swap(i, j);
    }
    await _swap(low, j);
    return j;
  }

  Future<void> quickSort(int low, int high) async {
    if (low < high) {
      int pi = await _partition(low, high);
      await quickSort(low, pi - 1);
      await quickSort(pi + 1, high);
    }
  }
}
