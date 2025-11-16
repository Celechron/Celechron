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
  }

  // Options
  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';
  final String kGpaStrategy = 'gpaStrategy';
  final String kPushOnGradeChange = 'pushOnGradeChange';
  final String kBrightnessMode = 'brightnessMode';
  final String kCourseIdMappingList = 'courseIdMappingList';
  final String kHideHomeGpa = 'hideHomeGpa';

  Option getOption() {
    return Option(
      workTime: getWorkTime().obs,
      restTime: getRestTime().obs,
      allowTime: getAllowTime().obs,
      gpaStrategy: getGpaStrategy().obs,
      pushOnGradeChange: getPushOnGradeChange().obs,
      brightnessMode: getBrightnessMode().obs,
      courseIdMappingList: getCourseIdMappingList().obs,
      hideHomeGpa: getHideHomeGpa().obs,
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
