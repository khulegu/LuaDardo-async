import 'dart:io';

import '../../lua.dart';

class OSLib {

  static Future<int> Function(LuaState) toAsyncFunction(DartFunction f) {
    return (LuaState ls) async {
      return await f(ls);
    };
  }

  static Map<String, DartFunctionAsync> _sysFuncs = {
    "clock": toAsyncFunction(_osClock),
    "difftime": _osDiffTime,
    "time": _osTime,
    "date": _osDate,
    "remove": toAsyncFunction(_osRemove),
    "rename": toAsyncFunction(_osRename),
    "tmpname": toAsyncFunction(_osTmpName),
    "getenv": toAsyncFunction(_osGetEnv),
    "execute": toAsyncFunction(_osExecute),
    "exit": _osExit,
    "setlocale": toAsyncFunction(_osSetLocale),
  };

  static Future<int> openOSLib(LuaState ls) async {
    await ls.newLib(_sysFuncs);
    return 1;
  }

  // os.clock ()
// http://www.lua.org/manual/5.3/manual.html#pdf-os.clock
// lua-5.3.4/src/loslib.c#os_clock()
  static int _osClock(LuaState ls) {
    ls.pushNumber(DateTime.now().millisecondsSinceEpoch/1000);
    return 1;
  }

// os.difftime (t2, t1)
// http://www.lua.org/manual/5.3/manual.html#pdf-os.difftime
// lua-5.3.4/src/loslib.c#os_difftime()
  static Future<int> _osDiffTime(LuaState ls) async {
    var t2 = (await ls.checkInteger(1))!;
    var t1 = (await ls.checkInteger(2))!;
    ls.pushInteger(t2 - t1);
    return 1;
  }

// os.time ([table])
// http://www.lua.org/manual/5.3/manual.html#pdf-os.time
// lua-5.3.4/src/loslib.c#os_time()
  static Future<int> _osTime(LuaState ls) async {
    if (ls.isNoneOrNil(1)) {
      /* called without args? */
      var t =
          DateTime.now().millisecondsSinceEpoch ~/ 1000; /* get current time */
      ls.pushInteger(t);
    } else {
      ls.checkType(1, LuaType.luaTable);
      var sec = await _getField(ls, "sec", 0);
      var min = await _getField(ls, "min", 0);
      var hour = await _getField(ls, "hour", 12);
      var day = await _getField(ls, "day", -1);
      var month = await _getField(ls, "month", -1);
      var year = await _getField(ls, "year", -1);
      // todo: isdst
      var t =
          DateTime(year, month, day, hour, min, sec).millisecondsSinceEpoch ~/
              1000;
      ls.pushInteger(t);
    }
    return 1;
  }

// lua-5.3.4/src/loslib.c#getfield()
  static Future<int> _getField(LuaState ls, String key, int dft) async {
    var t = await ls.getField(-1, key); /* get field and its type */
    var res = ls.toIntegerX(-1);
    if (res == null) {
      /* field is not an integer? */
      if (t != LuaType.luaNil) {
        /* some other value? */
        return ls.error2("field '%s' is not an integer", [key]);
      } else if (dft < 0) {
        /* absent field; no default? */
        return ls.error2("field '%s' missing in date table", [key]);
      }
      res = dft;
    }
    ls.pop(1);
    return res;
  }

// os.date ([format [, time]])
// http://www.lua.org/manual/5.3/manual.html#pdf-os.date
// lua-5.3.4/src/loslib.c#os_date()
  static Future<int> _osDate(LuaState ls) async {
    var format = ls.optString(1, "%c")!;
    DateTime t;
    if (ls.isInteger(2)) {
      t = DateTime.now().add(Duration(seconds: ls.toInteger(2)));
    } else {
      t = DateTime.now();
    }

    if (format.isNotEmpty && format[0] == '!') {
      /* UTC? */
      format = format.substring(1); /* skip '!' */
      t = t.toUtc();
    }

    if (format == "*t") {
      ls.createTable(0, 9); /* 9 = number of fields */
      await _setField(ls, "sec", t.second);
      await _setField(ls, "min", t.minute);
      await _setField(ls, "hour", t.hour);
      await _setField(ls, "day", t.day);
      await _setField(ls, "month", t.month);
      await _setField(ls, "year", t.year);
      await _setField(ls, "wday", t.weekday);
      await _setField(ls, "yday", _getYearDay(t));
    } else if (format == "%c") {
      ls.pushString(t.toString());
    } else {
      ls.pushString(format); // TODO
    }

    return 1;
  }

  static int _getYearDay(DateTime date){
    var monthDay = [31,28,31,30,31,30,31,31,30,31,30,31];

    if(date.year%4==0 && date.year%100!=0) monthDay[1] = 29;
    else if(date.year%400==0) monthDay[1] = 29;

    int sum=0;
    for(var i = 0;i<=date.month-2;i++){
      sum += monthDay[i];
    }

    return date.day + sum;
  }

  static Future<void> _setField(LuaState ls, String key, int value) async {
    ls.pushInteger(value);
    await ls.setField(-2, key);
  }

// os.remove (filename)
// http://www.lua.org/manual/5.3/manual.html#pdf-os.remove
  static int _osRemove(LuaState ls) {
    var filename = ls.checkString(1)!;

    try {
      File(filename).deleteSync();
      ls.pushBoolean(true);
      return 1;
    } catch (e) {
      ls.pushNil();
      ls.pushString(e.toString());
      return 2;
    }
  }

// os.rename (oldname, newname)
// http://www.lua.org/manual/5.3/manual.html#pdf-os.rename
  static int _osRename(LuaState ls) {
    var oldName = ls.checkString(1)!;
    var newName = ls.checkString(2)!;

    try {
      File(oldName).renameSync(newName);
      ls.pushBoolean(true);
      return 1;
    } catch (e) {
      ls.pushNil();
      ls.pushString(e.toString());
      return 2;
    }
  }

// os.tmpname ()
// http://www.lua.org/manual/5.3/manual.html#pdf-os.tmpname
  static int _osTmpName(LuaState ls) {
    throw ("todo: osTmpName!");
  }

// os.getenv (varname)
// http://www.lua.org/manual/5.3/manual.html#pdf-os.getenv
// lua-5.3.4/src/loslib.c#os_getenv()
  static int _osGetEnv(LuaState ls) {
    var key = ls.checkString(1);
    var env = Platform.environment[key!]!;

    if (env.isNotEmpty) {
      ls.pushString(env);
    } else {
      ls.pushNil();
    }
    return 1;
  }

// os.execute ([command])
// http://www.lua.org/manual/5.3/manual.html#pdf-os.execute
  static int _osExecute(LuaState ls) {
    var cmd = ls.checkString(1)!;
    var args = cmd.split(" ");
    if(args.length > 1){
      var comm = args.removeAt(0);
      Process.runSync(comm,args);
    }else{
      Process.runSync(cmd,[]);
    }
    return 0;
  }

// os.exit ([code [, close]])
// http://www.lua.org/manual/5.3/manual.html#pdf-os.exit
// lua-5.3.4/src/loslib.c#os_exit()
  static Future<int> _osExit(LuaState ls) async {
    if (ls.isBoolean(1)) {
      if (ls.toBoolean(1)) {
        exit(0);
      } else {
        exit(1); // todo
      }
    } else {
      var code = (await ls.optInteger(1, 1))!;
      exit(code);
    }
  }

// os.setlocale (locale [, category])
// http://www.lua.org/manual/5.3/manual.html#pdf-os.setlocale
  static int _osSetLocale(LuaState ls) {
    throw ("todo: osSetLocale!");
  }
}
