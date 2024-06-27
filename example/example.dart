

import 'package:lua_dardo_async/lua.dart';

Future<void> main(List<String> arguments) async {
  LuaState state = LuaState.newState();
  await state.openLibs();

  state.registerAsync("wait", (ls) => Future.delayed(Duration(seconds: 1), () => 0));

  state.loadString(r'''
   print("before the wait")
   wait()
   print("after the wait")
   a = 1;
   b = 3;
   c = 2 + 2;
   print(c);
''');
  state.call(0, 0);
  print("end of the script");
}
