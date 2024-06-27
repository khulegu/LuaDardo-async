# LuaDardo-async

![logo](https://github.com/arcticfox1919/ImageHosting/blob/master/language_logo.png?raw=true)

------

A Lua virtual machine written in [Dart](https://github.com/dart-lang/sdk), which implements [Lua5.3](http://www.lua.org/manual/5.3/) version.
This is a fork that implements async functions wrappers.

Original : [LuaDardo](https://github.com/arcticfox1919/LuaDardo)

## Example:

```yaml
dependencies:
  lua_dardo_async: ^0.0.1
```

```dart
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
```
