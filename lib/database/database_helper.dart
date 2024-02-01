import 'package:celechron/model/deadline.dart';
import 'package:celechron/model/fuse.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/option.dart';
import 'adapters/duration_adapter.dart';
import 'adapters/scholar_adapter.dart';
import 'adapters/deadline_adapter.dart';
import 'adapters/period_adapter.dart';
import 'adapters/fuse_adapter.dart';

class DatabaseHelper {
  late final Box optionsBox;
  late final Box scholarBox;
  late final Box deadlineBox;
  late final Box flowBox;
  late final Box originalWebPageBox;
  late final Box fuseBox;

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
    optionsBox = await Hive.openBox(dbOptions);
    scholarBox = await Hive.openBox(dbScholar);
    deadlineBox = await Hive.openBox(dbDeadline);
    flowBox = await Hive.openBox(dbFlow);
    originalWebPageBox = await Hive.openBox(dbOriginalWebPage);
    fuseBox = await Hive.openBox(dbFuse);
  }

  // Options
  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';
  final String kGpaStrategy = 'gpaStrategy';

  Option getOption() {
    return Option(
      workTime: getWorkTime().obs,
      restTime: getRestTime().obs,
      allowTime: getAllowTime().obs,
      gpaStrategy: getGpaStrategy().obs,
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

  int getGpaStrategy() {
    if (optionsBox.get(kGpaStrategy) == null) {
      optionsBox.put(kGpaStrategy, 0);
    }
    return optionsBox.get(kGpaStrategy);
  }

  Future<void> setGpaStrategy(int gpaStrategy) async {
    await optionsBox.put(kGpaStrategy, gpaStrategy);
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

  // Deadline
  final String dbDeadline = 'dbDeadline';
  final String kDeadlineList = 'deadlineList';
  final String kDeadlineListUpdateTime = 'deadlineListUpdateTime';

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

  // Scholar
  final String dbScholar = 'dbUser';

  Scholar getScholar() {
    return scholarBox.get('user') ?? Scholar();
  }

  Future<void> setScholar(Scholar scholar) async {
    await scholarBox.put('user', scholar);
  }

  Future<void> removeScholar() async {
    await scholarBox.delete('user');
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
}
