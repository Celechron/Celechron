import 'dart:convert';

import 'package:hive/hive.dart';
import '../model/user.dart';
import 'adapters/duration_adapter.dart';
import 'adapters/user_adapter.dart';

class DatabaseHelper {
  late final Box optionsBox;
  late final Box userBox;

  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';

  final String dbUser = 'dbUser';

  Future<void> init() async {
    Hive.registerAdapter(DurationAdapter());
    Hive.registerAdapter(UserAdapter());
    optionsBox = await Hive.openBox(dbOptions);
    userBox = await Hive.openBox(dbUser);
  }

  Duration getWorkTime() {
    if (optionsBox.get(kWorkTime) == null) {
      optionsBox.put(kWorkTime, const Duration(minutes: 45));
    }
    return optionsBox.get(kWorkTime);
  }

  void setWorkTime(Duration workTime) {
    optionsBox.put(kWorkTime, workTime);
  }

  Duration getRestTime() {
    if (optionsBox.get(kRestTime) == null) {
      optionsBox.put(kRestTime, const Duration(minutes: 15));
    }
    return optionsBox.get(kRestTime);
  }

  void setRestTime(Duration restTime) {
    optionsBox.put(kRestTime, restTime);
  }

  Map<dynamic, dynamic> getAllowTime() {
    if (true || optionsBox.get(kAllowTime) == null) {
      Map<DateTime, DateTime> base = {};
      base[DateTime(0, 0, 0, 8, 0)] = DateTime(0, 0, 0, 11, 35);
      base[DateTime(0, 0, 0, 14, 15)] = DateTime(0, 0, 0, 22, 00);
      optionsBox.put(kAllowTime, base);
    }
    return optionsBox.get(kAllowTime);
  }

  void setAllowTime(Map<DateTime, DateTime> allowTime) {
    optionsBox.put(kAllowTime, allowTime);
  }

  String? getUser() {
    return userBox.get('user');
  }

  Future<void> setUser(User user) async {
    await userBox.put('user', jsonEncode(user));
  }

  Future<void> removeUser() async {
    await userBox.delete('user');
  }

}

DatabaseHelper db = DatabaseHelper();
