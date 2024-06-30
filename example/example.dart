

import 'package:lua_dardo_async/lua.dart';

Future<void> main(List<String> arguments) async {
  LuaState state = LuaState.newState();
  await state.openLibs();

  state.registerAsync("wait", (ls) => Future.delayed(Duration(seconds: 1), () => 0));

  state.loadString(r'''
   print("before the wait")
   wait()
   print("after the wait")
   ''');
  state.call(0, 0);
  print("end of the script");
}
