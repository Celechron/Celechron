import 'dart:convert';

import 'package:celechron/model/deadline.dart';
import 'package:hive/hive.dart';
import '../model/user.dart';
import '../model/period.dart';
import 'adapters/duration_adapter.dart';
import 'adapters/user_adapter.dart';
import 'adapters/deadline_adapter.dart';
import 'adapters/period_adapter.dart';

class DatabaseHelper {
  late final Box optionsBox;
  late final Box userBox;
  late final Box deadlineBox;
  late final Box flowBox;

  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';

  final String dbDeadline = 'dbDeadline';
  final String kDeadlineList = 'deadlineList';
  final String kDeadlineListUpdateTime = 'deadlineListUpdateTime';

  final String dbFlow = 'dbFlow';
  final String kFlowList = 'flowList';
  final String kFlowListUpdateTime = 'flowListUpdateTime';

  final String dbUser = 'dbUser';

  Future<void> init() async {
    Hive.registerAdapter(DurationAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(DeadlineTypeAdapter());
    Hive.registerAdapter(DeadlineAdapter());
    Hive.registerAdapter(PeriodTypeAdapter());
    Hive.registerAdapter(PeriodAdapter());
    optionsBox = await Hive.openBox(dbOptions);
    userBox = await Hive.openBox(dbUser);
    deadlineBox = await Hive.openBox(dbDeadline);
    flowBox = await Hive.openBox(dbFlow);
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
      base[DateTime(0, 0, 0, 14, 15)] = DateTime(0, 0, 0, 23, 00);
      optionsBox.put(kAllowTime, base);
    }
    return optionsBox.get(kAllowTime);
  }

  void setAllowTime(Map<DateTime, DateTime> allowTime) {
    optionsBox.put(kAllowTime, allowTime);
  }

  List<Period> getFlowList() {
    return List<Period>.from(flowBox.get(kFlowList) ?? <Period>[]);
  }

  Future<void> setFlowList(List<Period> flowList) async {
    await flowBox.put(kFlowList, flowList);
  }

  DateTime getFlowListUpdateTime() {
    return flowBox.get(kFlowListUpdateTime) ??
        DateTime.fromMicrosecondsSinceEpoch(0);
  }

  Future<void> setFlowListUpdateTime(DateTime flowListUpdateTime) async {
    await flowBox.put(kFlowListUpdateTime, flowListUpdateTime);
  }

  List<Deadline> getDeadlineList() {
    return List<Deadline>.from(deadlineBox.get(kDeadlineList) ?? <Deadline>[]);
  }

  Future<void> setDeadlineList(List<Deadline> deadlineList) async {
    await deadlineBox.put(kDeadlineList, deadlineList);
  }

  DateTime getDeadlineListUpdateTime() {
    return deadlineBox.get(kDeadlineListUpdateTime) ??
        DateTime.fromMicrosecondsSinceEpoch(0);
  }

  Future<void> setDeadlineListUpdateTime(
      DateTime deadlineListUpdateTime) async {
    await deadlineBox.put(kDeadlineListUpdateTime, deadlineListUpdateTime);
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
