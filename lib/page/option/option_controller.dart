import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/page/scholar/scholar_controller.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/worker/background_app_refresh.dart';
import 'package:celechron/utils/platform_features.dart';
import 'package:celechron/utils/global.dart';
import 'package:celechron/model/calendar_to_system.dart';
import 'package:celechron/model/calendar_to_ical.dart';

import 'package:celechron/utils/utils.dart';

const _backgroundScholarFetchTask =
    'top.celechron.celechron.backgroundScholarFetch';
const _backgroundScholarFetchInterval = Duration(minutes: 15);

class OptionController extends GetxController {
  final _option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  final _taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final _taskListLastUpdate = Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _flowList = Get.find<RxList<Period>>(tag: 'flowList');
  final _flowListLastUpdate = Get.find<Rx<DateTime>>(tag: 'flowListLastUpdate');
  late final RxInt allowTimeLength = _option.allowTime.length.obs;

  /// 已存账号，MRU 排序，首元素恒为当前账号；密码仅在切换/登录时使用
  final accounts = <Map<String, String>>[].obs;

  /// 账号切换/添加/退出进行中，串行化防并发
  final accountBusy = false.obs;

  // 日历管理器
  late final CalendarToSystemManager _calendarManager;

  @override
  void onInit() {
    super.onInit();
    _calendarManager = CalendarToSystemManager(scholar);
    _db.getAccountList().then(accounts.assignAll);

    if (PlatformFeatures.hasBackgroundRefresh) {
      if (_option.pushOnGradeChange.value || _option.pushOnDdlReminder.value) {
        unawaited(_ensureBackgroundWorkerScheduled());
      } else {
        unawaited(_cancelBackgroundWorker());
      }
    }

    ever(courseIdMappingList, (value) {
      _db.setCourseIdMappingList(value);
    });

    // 初始化时检查日历权限和同步状态（不显示提示框）
    _calendarManager.checkInitialCalendarSyncStatus();
  }

  Duration get workTime => _option.workTime.value;

  set workTime(Duration value) {
    _option.workTime.value = value;
    _db.setWorkTime(value);
  }

  Duration get restTime => _option.restTime.value;

  set restTime(Duration value) {
    _option.restTime.value = value;
    _db.setRestTime(value);
  }

  Map<DateTime, DateTime> get allowTime => _option.allowTime;

  set allowTime(Map<DateTime, DateTime> value) {
    _option.allowTime.value = value;
    _db.setAllowTime(value);
    allowTimeLength.value = value.length;
  }

  GpaStrategy get gpaStrategy => _option.gpaStrategy.value;

  set gpaStrategy(GpaStrategy value) {
    _option.gpaStrategy.value = value;
    _db.setGpaStrategy(value);
  }

  bool get pushOnGradeChange => _option.pushOnGradeChange.value;

  set pushOnGradeChange(bool value) {
    _option.pushOnGradeChange.value = value;
    _db.setPushOnGradeChange(value);
    // 同步到 SecureStorage 供后台任务读取
    _db.secureStorage.write(
        key: 'pushOnGradeChange',
        value: value.toString(),
        iOptions: secureStorageIOSOptions);

    if (!PlatformFeatures.hasBackgroundRefresh) {
      return;
    }

    unawaited(_updateBackgroundWorker(value || pushOnDdlReminder));
  }

  bool get pushOnDdlReminder => _option.pushOnDdlReminder.value;

  set pushOnDdlReminder(bool value) {
    _option.pushOnDdlReminder.value = value;
    _db.setPushOnDdlReminder(value);
    // 同步到 SecureStorage 供后台任务读取
    _db.secureStorage.write(
        key: 'pushOnDdlReminder',
        value: value.toString(),
        iOptions: secureStorageIOSOptions);

    if (!PlatformFeatures.hasBackgroundRefresh) {
      return;
    }

    unawaited(_updateBackgroundWorker(value || pushOnGradeChange));
  }

  Future<void> _ensureBackgroundWorkerScheduled() async {
    try {
      final workmanager = Workmanager();
      await workmanager.initialize(callbackDispatcher);
      // Android 的周期任务会跨 App 启动持久化；不要每次页面控制器初始化时
      // 重新排一个 10 秒后的任务。iOS 仍需提交 BGAppRefresh 请求，但最早
      // 执行时间与正常周期一致，并由前台租约做最终保护。
      if (Platform.isAndroid &&
          await workmanager
              .isScheduledByUniqueName(_backgroundScholarFetchTask)) {
        return;
      }
      await workmanager.registerPeriodicTask(
        _backgroundScholarFetchTask,
        _backgroundScholarFetchTask,
        frequency: _backgroundScholarFetchInterval,
        initialDelay: _backgroundScholarFetchInterval,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '后台刷新',
        operation: 'schedule',
        message: '后台刷新任务注册失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _cancelBackgroundWorker() async {
    try {
      await Workmanager().cancelByUniqueName(_backgroundScholarFetchTask);
      if (Platform.isIOS) await Workmanager().printScheduledTasks();
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '后台刷新',
        operation: 'cancel',
        message: '后台刷新任务取消失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _updateBackgroundWorker(bool enabled) async {
    await _cancelBackgroundWorker();
    if (!enabled) return;
    try {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      const initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      await _ensureBackgroundWorkerScheduled();
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '后台刷新',
        operation: 'enable',
        message: '启用后台刷新任务失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  BrightnessMode get brightnessMode => _option.brightnessMode.value;

  set brightnessMode(BrightnessMode value) {
    _option.brightnessMode.value = value;
    _db.setBrightnessMode(value);
  }

  RxList<CourseIdMap> get courseIdMappingList => _option.courseIdMappingList;

  bool get hideHomeGpa => _option.hideHomeGpa.value;

  set hideHomeGpa(bool value) {
    _option.hideHomeGpa.value = value;
    _db.setHideHomeGpa(value);
  }

  bool get asyncRefresh => _option.asyncRefresh.value;

  set asyncRefresh(bool value) {
    _option.asyncRefresh.value = value;
    _db.setAsyncRefresh(value);
  }

  String get celechronVersion => _fuse.value.displayVersion;

  bool get hasNewVersion => _fuse.value.hasNewVersion;

  // —— 多账号 ——
  // 活动槽位 + 归档：当前账号数据在各 box 的原键位，非活跃账号归档在
  // <键>_<username> 下。切换的核心是一个不含 await 的同步交换块，
  // 保证 TaskController/FlowController 的秒级 tick 观察不到混合态。

  /// 账号管理页展示用：按学号从小到大排序，不随切换变化。
  /// 底层 accounts 仍为 MRU 序——首元素镜像凭据、退出后回退都依赖它
  List<Map<String, String>> get accountsSortedById {
    var sorted = accounts.toList();
    sorted.sort((a, b) {
      var ua = a['username'] ?? '';
      var ub = b['username'] ?? '';
      // 学号均为数字串，先比长度再比字典序即数值序
      return ua.length != ub.length ? ua.length - ub.length : ua.compareTo(ub);
    });
    return sorted;
  }

  /// 切换到已存账号。瞬间换上其缓存档案，随后复刻启动逻辑后台登录刷新
  Future<void> switchAccount(String username) async {
    if (accountBusy.value) return;
    accountBusy.value = true;
    try {
      await _switchAccountLocked(username);
    } finally {
      accountBusy.value = false;
    }
  }

  Future<void> _switchAccountLocked(String username) async {
    var target = accounts.firstWhereOrNull((e) => e['username'] == username);
    if (target == null || username == scholar.value.username) return;

    var writes = <Future>[];
    var next = _activateProfile(target, writes);
    accounts.remove(target);
    accounts.insert(0, target);

    // 先等归档与活动槽位落盘，再写 accountList 作为提交点；
    // 目标账号的归档键等提交完成后再删，中途被杀不丢档案
    await Future.wait(writes);
    await _db.setAccountList(accounts.toList());
    await _db.deleteArchivedProfile(username);
    await _db.removeAllCachedWebPage();
    if (Get.isRegistered<ScholarController>()) {
      Get.find<ScholarController>().resetSemesterIndex();
    }

    _refreshInBackground(next);
  }

  /// 添加新账号或更新已存账号的密码。返回登录错误列表（全 null 为成功）。
  /// 试登录用不挂 db 的临时 Scholar，失败不碰当前账号任何状态
  Future<List<String?>> addOrUpdateAccount(
      String username, String password) async {
    if (username.isEmpty || password.isEmpty) return ['请输入学号与密码'];
    if (accountBusy.value) return ['正在处理其他账号操作，请稍后再试'];
    accountBusy.value = true;
    try {
      var probe = Scholar();
      probe.username = username;
      probe.password = password;
      var errors = await probe.login();
      if (errors.any((e) => e != null)) return errors;

      var entry = {'username': username, 'password': password};
      var index = accounts.indexWhere((e) => e['username'] == username);

      if (username == scholar.value.username) {
        // 当前账号改密码：换上新凭据。旧 spider 缓存着旧密码，而 refresh
        // 只在无会话时才内部重登，须显式 login 重建会话后再刷新
        scholar.value.password = password;
        if (index >= 0) {
          accounts[index] = entry;
        } else {
          accounts.insert(0, entry);
        }
        await _db.setScholar(scholar.value);
        await _db.setAccountList(accounts.toList());
        var s = scholar.value;
        unawaited(() async {
          try {
            var loginErrors = await s.login();
            if (loginErrors.every((e) => e == null)) {
              await _refreshAccountScholar(s);
            }
          } on Object catch (error, stackTrace) {
            DiagnosticLogService.instance.record(
              level: CelechronLogLevel.warning,
              module: 'refresh',
              operation: 'passwordUpdateRelogin',
              message: '更新密码后的重新登录异常结束',
              error: error,
              stackTrace: stackTrace,
            );
          } finally {
            unawaited(ECardWidgetMessenger.update());
          }
        }());
        return errors;
      }

      if (index >= 0) {
        // 已存账号：原位更新密码（位次交给切换流程调整），随后切换过去
        accounts[index] = entry;
        await _db.setAccountList(accounts.toList());
        await _switchAccountLocked(username);
        return errors;
      }

      // 新账号：归档当前账号（若有），probe 转正为活动 Scholar
      var writes = <Future>[];
      _adoptNewAccount(probe, writes);
      accounts.insert(0, entry);
      await Future.wait(writes);
      await _db.setAccountList(accounts.toList());
      await _db.removeAllCachedWebPage();
      if (Get.isRegistered<ScholarController>()) {
        Get.find<ScholarController>().resetSemesterIndex();
      }
      pushOnGradeChange = PlatformFeatures.hasBackgroundRefresh;
      // probe 已持有登录会话，refresh 不会重复登录
      _refreshInBackground(probe);
      return errors;
    } finally {
      accountBusy.value = false;
    }
  }

  /// 退出当前账号并删除其本机全部数据（含任务与规划）。
  /// 还有其他账号时自动切到最近使用的一个，否则回到未登录空态
  Future<void> signOutCurrent() async {
    if (accountBusy.value) return;
    accountBusy.value = true;
    try {
      var old = scholar.value;
      var oldUsername = old.username;
      accounts.removeWhere((e) => e['username'] == oldUsername);

      if (accounts.isNotEmpty) {
        var target = accounts.first;
        var writes = <Future>[];
        var next = _activateProfile(target, writes, archiveCurrent: false);
        await Future.wait(writes);
        await _db.setAccountList(accounts.toList());
        await _db.deleteArchivedProfile(target['username']!);
        if (oldUsername != null && oldUsername.isNotEmpty) {
          await _db.deleteArchivedProfile(oldUsername); // 常态不存在，防残档
          await _db.deleteBackgroundStateFor(oldUsername);
        }
        await _db.removeAllCachedWebPage();
        if (Get.isRegistered<ScholarController>()) {
          Get.find<ScholarController>().resetSemesterIndex();
        }
        _refreshInBackground(next);
        return;
      }

      // 无剩余账号：回到未登录空态。old.db 已置空，在途刷新不可能把
      // 旧账号数据写回槽位；db 侧清理在此直接做，不再调用 old.logout()
      old.db = null;
      var epoch = DateTime.fromMicrosecondsSinceEpoch(0);
      _flowListLastUpdate.value = epoch;
      _flowList.clear();
      _taskListLastUpdate.value = epoch;
      _taskList.clear();
      scholar.value = Scholar()..db = _db;
      var clearWrites = <Future>[
        _db.setCustomGpa({}),
        _db.setWeightedGpa({}),
        _db.setTaskList([]),
        _db.setTaskListUpdateTime(epoch),
        _db.setFlowList([]),
        _db.setFlowListUpdateTime(epoch),
      ];
      await Future.wait(clearWrites);
      // 写空表保留 accountList 键，后台刷新维持「已迁移」门控
      await _db.setAccountList([]);
      await _db.removeScholar();
      if (oldUsername != null && oldUsername.isNotEmpty) {
        await _db.deleteArchivedProfile(oldUsername);
        await _db.deleteBackgroundStateFor(oldUsername);
      }
      await _db.removeAllCachedWebPage();
      scholar.refresh();
      pushOnGradeChange = false;
      ECardWidgetMessenger.logout();
    } finally {
      accountBusy.value = false;
    }
  }

  /// 删除一个非当前账号及其本机归档
  Future<void> deleteAccount(String username) async {
    if (accountBusy.value) return;
    if (username == scholar.value.username) return; // 当前账号走退出流程
    accountBusy.value = true;
    try {
      accounts.removeWhere((e) => e['username'] == username);
      await _db.setAccountList(accounts.toList());
      await _db.deleteArchivedProfile(username);
      await _db.deleteBackgroundStateFor(username);
      accounts.refresh();
    } finally {
      accountBusy.value = false;
    }
  }

  /// 同步交换块：归档当前账号（可选）、把目标账号档案装入内存与活动槽位。
  /// 全程无 await；产生的落盘 future 收集进 [writes] 由调用方统一等待
  Scholar _activateProfile(Map<String, String> target, List<Future> writes,
      {bool archiveCurrent = true}) {
    var old = scholar.value;
    // 切出账号在途刷新的落盘全部作废，防止旧账号数据写进新账号槽位
    old.db = null;
    if (archiveCurrent &&
        old.isLogan &&
        old.username != null &&
        old.username!.isNotEmpty) {
      writes.add(_db.archiveActiveProfile(
          old.username!,
          old,
          List<Task>.from(_taskList),
          _taskListLastUpdate.value,
          List<Period>.from(_flowList),
          _flowListLastUpdate.value));
    }

    var restored = _db.readArchivedProfile(target['username']!);
    // 从未归档过的账号（如中途被杀）兜底为空数据的已登录状态，等异步刷新填充
    var next = restored.scholar ?? (Scholar()..isLogan = true);
    next.username = target['username'];
    next.password = target['password'];
    next.db = _db;

    // scholar 最后赋值：ever(scholar) 触发的小组件推送拿到的是完整新态
    _flowListLastUpdate.value = restored.flowListUpdateTime;
    _flowList.assignAll(restored.flowList);
    _taskListLastUpdate.value = restored.taskListUpdateTime;
    _taskList.assignAll(restored.taskList);
    scholar.value = next;

    // 活动槽位持久化。Hive put 同步更新内存，磁盘刷写由 writes 兜底
    writes.add(_db.setCustomGpa(restored.customGpa));
    writes.add(_db.setWeightedGpa(restored.weightedGpa));
    writes.add(_db.setTaskList(restored.taskList));
    writes.add(_db.setTaskListUpdateTime(restored.taskListUpdateTime));
    writes.add(_db.setFlowList(restored.flowList));
    writes.add(_db.setFlowListUpdateTime(restored.flowListUpdateTime));
    writes.add(_db.setScholar(next));
    return next;
  }

  /// 同步交换块（添加新账号）：归档当前账号后 probe 转正。
  /// 首登（此前未登录）不清任务——离线期建的任务归属首个账号
  void _adoptNewAccount(Scholar probe, List<Future> writes) {
    var old = scholar.value;
    old.db = null;
    if (old.isLogan && old.username != null && old.username!.isNotEmpty) {
      writes.add(_db.archiveActiveProfile(
          old.username!,
          old,
          List<Task>.from(_taskList),
          _taskListLastUpdate.value,
          List<Period>.from(_flowList),
          _flowListLastUpdate.value));
      var epoch = DateTime.fromMicrosecondsSinceEpoch(0);
      _flowListLastUpdate.value = epoch;
      _flowList.clear();
      _taskListLastUpdate.value = epoch;
      _taskList.clear();
      writes.add(_db.setCustomGpa({}));
      writes.add(_db.setWeightedGpa({}));
      writes.add(_db.setTaskList([]));
      writes.add(_db.setTaskListUpdateTime(epoch));
      writes.add(_db.setFlowList([]));
      writes.add(_db.setFlowListUpdateTime(epoch));
    }
    probe.db = _db;
    scholar.value = probe;
    writes.add(_db.setScholar(probe));
  }

  /// 复刻 main.dart 的启动逻辑：先展示缓存，后台完成刷新（会话重建由
  /// Scholar.refresh 内部完成）。捕获局部 [s]：若刷新途中账号又被切走，
  /// s.db 已被置空，落盘自动作废。校园卡走另一套 CAS 链路，等刷新收尾
  /// 后再更新，避免两条认证链路互相干扰
  void _refreshInBackground(Scholar s) {
    scholar.refresh();
    unawaited(_refreshAccountScholar(s)
        .whenComplete(() => unawaited(ECardWidgetMessenger.update())));
  }

  Future<void> _refreshAccountScholar(Scholar s) async {
    GlobalStatus.isFirstScreenReq = true;
    try {
      await s.refresh(onPartialUpdate: scholar.refresh);
      await _calendarManager.resyncSilently();
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.error,
        module: 'refresh',
        operation: 'accountRefresh',
        message: '账号切换/添加后的自动刷新异常结束',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      GlobalStatus.isFirstScreenReq = false;
      scholar.refresh();
    }
  }

  /// calendar_to_ical.dart: 显示导出课程表对话框
  void showExportDialog(BuildContext context) {
    CalendarToIcal.showExportDialog(context, scholar.value);
  }

  /// calendar_to_system.dart: 系统日历同步相关方法

  // 日历同步相关getter
  bool get calendarSyncEnabled => _calendarManager.calendarSyncEnabled;

  bool get hasCalendarPermission => _calendarManager.hasCalendarPermission;

  Future<void> toggleCalendarSync(BuildContext context, bool enabled) =>
      _calendarManager.toggleCalendarSync(context, enabled);

  void showCalendarSyncDialog(BuildContext context) =>
      _calendarManager.showCalendarSyncDialog(context);

  Map<String, dynamic> getCalendarSyncStatus() {
    final stats = _calendarManager.getSyncStats();
    return {
      'enabled': calendarSyncEnabled,
      'hasPermission': hasCalendarPermission,
      'isLoggedIn': scholar.value.isLogan,
      ...stats,
    };
  }
}
