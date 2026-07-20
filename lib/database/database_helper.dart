import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:celechron/model/task.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/utils/utils.dart';
import 'adapters/duration_adapter.dart';
import 'adapters/scholar_adapter.dart';
import 'adapters/deadline_adapter.dart';
import 'adapters/period_adapter.dart';
import 'adapters/fuse_adapter.dart';
import 'adapters/course_id_map_adapter.dart';

class DatabaseHelper {
  late final Box optionsBox;
  late final Box scholarBox;
  late final Box taskBox;
  late final Box flowBox;
  late final Box originalWebPageBox;
  late final Box fuseBox;
  late final Box customGpaBox;
  late final FlutterSecureStorage secureStorage;

  Future<void> init() async {
    Hive.registerAdapter(DurationAdapter());
    Hive.registerAdapter(ScholarAdapter());
    Hive.registerAdapter(DeadlineStatusAdapter());
    Hive.registerAdapter(DeadlineTypeAdapter());
    Hive.registerAdapter(DeadlineRepeatTypeAdapter());
    Hive.registerAdapter(DeadlineAdapter());
    Hive.registerAdapter(PeriodTypeAdapter());
    Hive.registerAdapter(PeriodAdapter());
    Hive.registerAdapter(FuseAdapter());
    Hive.registerAdapter(CourseIdMapAdapter());
    optionsBox = await Hive.openBox(dbOptions);
    scholarBox = await Hive.openBox(dbScholar);
    taskBox = await Hive.openBox(dbTask);
    flowBox = await Hive.openBox(dbFlow);
    originalWebPageBox = await Hive.openBox(dbOriginalWebPage);
    fuseBox = await Hive.openBox(dbFuse);
    customGpaBox = await Hive.openBox(dbCustomGpa);
    secureStorage = const FlutterSecureStorage();
    // Migrate all items without groupID
    var secureStorageItems = await secureStorage.readAll(
        iOptions: const IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
            accountName: 'Celechron'));
    await Future.forEach(secureStorageItems.entries, (e) async {
      await secureStorage.delete(
          key: e.key,
          iOptions: const IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
              accountName: 'Celechron'));
      await secureStorage.write(
          key: e.key, value: e.value, iOptions: secureStorageIOSOptions);
    });
    // 多账号迁移：把既有单账号播种进账号列表，并把后台推送状态键复制到
    // 账号命名空间。最后写 accountList 作为提交点，中途崩溃则下次整体重跑。
    var accountListRaw = await secureStorage.read(
        key: kAccountList, iOptions: secureStorageIOSOptions);
    if (accountListRaw == null) {
      var legacyUsername = await secureStorage.read(
          key: kUsername, iOptions: secureStorageIOSOptions);
      var legacyPassword = await secureStorage.read(
          key: kPassword, iOptions: secureStorageIOSOptions);
      if (legacyUsername != null &&
          legacyUsername.isNotEmpty &&
          legacyPassword != null) {
        for (var key in backgroundStateKeys) {
          var value = await secureStorage.read(
              key: key, iOptions: secureStorageIOSOptions);
          if (value != null) {
            await secureStorage.write(
                key: '${key}_$legacyUsername',
                value: value,
                iOptions: secureStorageIOSOptions);
          }
        }
        await secureStorage.write(
            key: kAccountList,
            value: jsonEncode([
              {'username': legacyUsername, 'password': legacyPassword}
            ]),
            iOptions: secureStorageIOSOptions);
      }
    }
  }

  // Options
  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';
  final String kGpaStrategy = 'gpaStrategy';
  final String kPushOnGradeChange = 'pushOnGradeChange';
  final String kPushOnDdlReminder = 'pushOnDdlReminder';
  final String kBrightnessMode = 'brightnessMode';
  final String kCourseIdMappingList = 'courseIdMappingList';
  final String kHideHomeGpa = 'hideHomeGpa';
  final String kAsyncRefresh = 'asyncRefresh';

  Option getOption() {
    return Option(
      workTime: getWorkTime().obs,
      restTime: getRestTime().obs,
      allowTime: getAllowTime().obs,
      gpaStrategy: getGpaStrategy().obs,
      pushOnGradeChange: getPushOnGradeChange().obs,
      pushOnDdlReminder: getPushOnDdlReminder().obs,
      brightnessMode: getBrightnessMode().obs,
      courseIdMappingList: getCourseIdMappingList().obs,
      hideHomeGpa: getHideHomeGpa().obs,
      asyncRefresh: getAsyncRefresh().obs,
    );
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

  Map<DateTime, DateTime> getAllowTime() {
    if (optionsBox.get(kAllowTime) == null) {
      Map<DateTime, DateTime> base = {};
      base[DateTime(0, 0, 0, 8, 0)] = DateTime(0, 0, 0, 11, 35);
      base[DateTime(0, 0, 0, 14, 15)] = DateTime(0, 0, 0, 23, 00);
      optionsBox.put(kAllowTime, base);
    }
    return Map<DateTime, DateTime>.from(optionsBox.get(kAllowTime));
  }

  Future<void> setAllowTime(Map<DateTime, DateTime> allowTime) async {
    await optionsBox.put(kAllowTime, allowTime);
  }

  GpaStrategy getGpaStrategy() {
    if (optionsBox.get(kGpaStrategy) == null) {
      optionsBox.put(kGpaStrategy, 0);
    }
    return GpaStrategy.values[optionsBox.get(kGpaStrategy)];
  }

  Future<void> setGpaStrategy(GpaStrategy gpaStrategy) async {
    await optionsBox.put(kGpaStrategy, gpaStrategy.index);
  }

  bool getPushOnGradeChange() {
    if (optionsBox.get(kPushOnGradeChange) == null) {
      optionsBox.put(kPushOnGradeChange, true);
    }
    return optionsBox.get(kPushOnGradeChange);
  }

  Future<void> setPushOnGradeChange(bool pushOnGradeChange) async {
    await optionsBox.put(kPushOnGradeChange, pushOnGradeChange);
  }

  bool getPushOnDdlReminder() {
    if (optionsBox.get(kPushOnDdlReminder) == null) {
      optionsBox.put(kPushOnDdlReminder, true);
    }
    return optionsBox.get(kPushOnDdlReminder);
  }

  Future<void> setPushOnDdlReminder(bool pushOnDdlReminder) async {
    await optionsBox.put(kPushOnDdlReminder, pushOnDdlReminder);
  }

  Future<void> setBrightnessMode(BrightnessMode brightness) async {
    await optionsBox.put(kBrightnessMode, brightness.index);
  }

  BrightnessMode getBrightnessMode() {
    if (optionsBox.get(kBrightnessMode) == null) {
      optionsBox.put(kBrightnessMode, BrightnessMode.system.index);
    }
    return BrightnessMode.values[optionsBox.get(kBrightnessMode)];
  }

  bool getHideHomeGpa() {
    if (optionsBox.get(kHideHomeGpa) == null) {
      optionsBox.put(kHideHomeGpa, false);
    }
    return optionsBox.get(kHideHomeGpa);
  }

  Future<void> setHideHomeGpa(bool hideHomeGpa) async {
    await optionsBox.put(kHideHomeGpa, hideHomeGpa);
  }

  // 异步刷新：数据边刷出边显示。默认关闭，即等全部刷完后一次性更新
  bool getAsyncRefresh() {
    if (optionsBox.get(kAsyncRefresh) == null) {
      optionsBox.put(kAsyncRefresh, false);
    }
    return optionsBox.get(kAsyncRefresh);
  }

  Future<void> setAsyncRefresh(bool asyncRefresh) async {
    await optionsBox.put(kAsyncRefresh, asyncRefresh);
  }

  List<CourseIdMap> getCourseIdMappingList() {
    if (optionsBox.get(kCourseIdMappingList) == null) {
      optionsBox.put(kCourseIdMappingList, <CourseIdMap>[]);
    }
    return List<CourseIdMap>.from(optionsBox.get(kCourseIdMappingList));
  }

  Future<void> setCourseIdMappingList(
      List<CourseIdMap> courseIdMappingList) async {
    await optionsBox.put(kCourseIdMappingList, courseIdMappingList);
  }

  // Flow
  final String dbFlow = 'dbFlow';
  final String kFlowList = 'flowList';
  final String kFlowListUpdateTime = 'flowListUpdateTime';

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

  // Task
  final String dbTask = 'dbDeadline';
  final String kTaskList = 'deadlineList';
  final String kTaskListUpdateTime = 'deadlineListUpdateTime';

  List<Task> getTaskList() {
    return List<Task>.from(taskBox.get(kTaskList) ?? <Task>[]);
  }

  Future<void> setTaskList(List<Task> deadlineList) async {
    await taskBox.put(kTaskList, deadlineList);
  }

  DateTime getTaskListUpdateTime() {
    return taskBox.get(kTaskListUpdateTime) ??
        DateTime.fromMicrosecondsSinceEpoch(0);
  }

  Future<void> setTaskListUpdateTime(DateTime deadlineListUpdateTime) async {
    await taskBox.put(kTaskListUpdateTime, deadlineListUpdateTime);
  }

  // Scholar
  final String dbScholar = 'dbUser';
  final String kUsername = 'username';
  final String kPassword = 'password';
  final String kAccountList = 'accountList';

  /// 后台推送状态键（仅由 background_app_refresh 读写），迁移后按账号命名空间隔离
  static const List<String> backgroundStateKeys = [
    'gpa',
    'gradedCourseCount',
    'pushOnGradeChangeFuse',
    'notifiedDdlIds'
  ];

  Future<Scholar> getScholar() async {
    var scholar = scholarBox.get('user', defaultValue: Scholar());
    await Future.wait([
      secureStorage
          .read(key: kUsername, iOptions: secureStorageIOSOptions)
          .then((value) {
        if (value != null) scholar.username = value;
      }),
      secureStorage
          .read(key: kPassword, iOptions: secureStorageIOSOptions)
          .then((value) {
        if (value != null) scholar.password = value;
      })
    ]);
    scholar.db = this;
    return scholar;
  }

  Future<void> setScholar(Scholar scholar) async {
    await Future.wait([
      scholarBox.put('user', scholar),
      secureStorage.write(
          key: kUsername,
          value: scholar.username,
          iOptions: secureStorageIOSOptions),
      secureStorage.write(
          key: kPassword,
          value: scholar.password,
          iOptions: secureStorageIOSOptions)
    ]);
  }

  Future<void> removeScholar() async {
    await Future.wait([
      scholarBox.delete('user'),
      secureStorage.delete(key: kUsername, iOptions: secureStorageIOSOptions),
      secureStorage.delete(key: kPassword, iOptions: secureStorageIOSOptions)
    ]);
  }

  // 多账号：账号列表存 secure storage，MRU 排序，首元素恒为当前账号；
  // 非活跃账号的数据归档在各 box 的 <活动键>_<username> 键下

  Future<List<Map<String, String>>> getAccountList() async {
    var raw = await secureStorage.read(
        key: kAccountList, iOptions: secureStorageIOSOptions);
    if (raw == null) return <Map<String, String>>[];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  Future<void> setAccountList(List<Map<String, String>> accounts) async {
    await secureStorage.write(
        key: kAccountList,
        value: jsonEncode(accounts),
        iOptions: secureStorageIOSOptions);
    // 首元素为当前账号，镜像到 legacy 键位，后台刷新与 e-card 组件按原键读取；
    // 空表不动镜像键，由登出流程自行清理
    if (accounts.isNotEmpty) {
      await Future.wait([
        secureStorage.write(
            key: kUsername,
            value: accounts.first['username'],
            iOptions: secureStorageIOSOptions),
        secureStorage.write(
            key: kPassword,
            value: accounts.first['password'],
            iOptions: secureStorageIOSOptions),
      ]);
    }
  }

  /// 把活动槽位数据归档到 <key>_<username>，供切换账号时保存切出账号的档案
  Future<void> archiveActiveProfile(
      String username,
      Scholar scholar,
      List<Task> taskList,
      DateTime taskListUpdateTime,
      List<Period> flowList,
      DateTime flowListUpdateTime) async {
    await Future.wait([
      scholarBox.put('user_$username', scholar),
      taskBox.put('${kTaskList}_$username', taskList),
      taskBox.put('${kTaskListUpdateTime}_$username', taskListUpdateTime),
      flowBox.put('${kFlowList}_$username', flowList),
      flowBox.put('${kFlowListUpdateTime}_$username', flowListUpdateTime),
      customGpaBox.put('selectList_$username', getCustomGpa()),
      customGpaBox.put('weightedGpa_$username', getWeightedGpa()),
    ]);
  }

  ArchivedProfile readArchivedProfile(String username) {
    var weightedRaw = customGpaBox.get('weightedGpa_$username') as Map?;
    return ArchivedProfile(
      scholar: scholarBox.get('user_$username') as Scholar?,
      taskList:
          List<Task>.from(taskBox.get('${kTaskList}_$username') ?? <Task>[]),
      taskListUpdateTime: taskBox.get('${kTaskListUpdateTime}_$username') ??
          DateTime.fromMicrosecondsSinceEpoch(0),
      flowList: List<Period>.from(
          flowBox.get('${kFlowList}_$username') ?? <Period>[]),
      flowListUpdateTime: flowBox.get('${kFlowListUpdateTime}_$username') ??
          DateTime.fromMicrosecondsSinceEpoch(0),
      customGpa: Map<String, bool>.from(
          customGpaBox.get('selectList_$username') ?? {}),
      weightedGpa: weightedRaw == null
          ? <String, double>{}
          : Map<String, double>.from(weightedRaw.map((key, value) =>
              MapEntry(key.toString(), (value as num).toDouble()))),
    );
  }

  Future<void> deleteArchivedProfile(String username) async {
    await Future.wait([
      scholarBox.delete('user_$username'),
      taskBox.delete('${kTaskList}_$username'),
      taskBox.delete('${kTaskListUpdateTime}_$username'),
      flowBox.delete('${kFlowList}_$username'),
      flowBox.delete('${kFlowListUpdateTime}_$username'),
      customGpaBox.delete('selectList_$username'),
      customGpaBox.delete('weightedGpa_$username'),
    ]);
  }

  /// 删除某账号的后台推送状态键（成绩基线、首推熔断、已提醒 DDL 集合）
  Future<void> deleteBackgroundStateFor(String username) async {
    await Future.wait([
      for (var key in backgroundStateKeys)
        secureStorage.delete(
            key: '${key}_$username', iOptions: secureStorageIOSOptions)
    ]);
  }

  // Original Web Page
  final String dbOriginalWebPage = 'dbOriginalWebPage';

  String? getCachedWebPage(String key) {
    return originalWebPageBox.get(key);
  }

  Future<void> setCachedWebPage(String key, String value) async {
    await originalWebPageBox.put(key, value);
  }

  Future<void> removeCachedWebPage(String key) async {
    await originalWebPageBox.delete(key);
  }

  Future<void> removeAllCachedWebPage() async {
    await originalWebPageBox.clear();
  }

  // Fuse
  final String dbFuse = 'dbFuse';

  Fuse getFuse() {
    return fuseBox.get('fuse') ?? Fuse();
  }

  Future<void> setFuse(Fuse fuse) async {
    await fuseBox.put('fuse', fuse);
  }

  final String dbCustomGpa = 'dbCustomGpa';
  final String dbWeightedGpa = 'dbWeightedGpa';

  Map<String, bool> getCustomGpa() {
    return Map<String, bool>.from(customGpaBox.get('selectList') ?? {});
  }

  Future<void> setCustomGpa(Map<String, bool> selectList) async {
    await customGpaBox.put('selectList', selectList);
  }

  /// 获取加权绩点的加权比例数据
  ///
  /// 返回值：
  /// - Map<String, double>: key为grade.id，value为加权比例（默认1.0）
  Map<String, double> getWeightedGpa() {
    final data = customGpaBox.get('weightedGpa') as Map?;
    if (data == null) {
      return {};
    }
    return Map<String, double>.from(data.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble())));
  }

  /// 保存加权绩点的加权比例数据
  Future<void> setWeightedGpa(Map<String, double> weightedMap) async {
    await customGpaBox.put('weightedGpa', weightedMap);
  }
}

/// 一个非活跃账号的归档档案快照。scholar 为空表示该账号从未归档过（新添账号）
class ArchivedProfile {
  final Scholar? scholar;
  final List<Task> taskList;
  final DateTime taskListUpdateTime;
  final List<Period> flowList;
  final DateTime flowListUpdateTime;
  final Map<String, bool> customGpa;
  final Map<String, double> weightedGpa;

  ArchivedProfile({
    required this.scholar,
    required this.taskList,
    required this.taskListUpdateTime,
    required this.flowList,
    required this.flowListUpdateTime,
    required this.customGpa,
    required this.weightedGpa,
  });
}
