import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/page/option/option_controller.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/services/refresh_coordinator.dart';
import 'package:celechron/utils/json_utils.dart';
import 'package:celechron/model/practice_score_item.dart';

import 'period.dart';
import 'grade.dart';
import 'semester.dart';
import 'todo.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/http/spider.dart';
import 'package:celechron/http/ugrs_spider.dart';
import 'package:celechron/http/grs_spider.dart';
import 'package:celechron/database/database_helper.dart';

class Scholar {
  Scholar();

  // 构造用户对象
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  // 登录状态
  bool isLogan = false;
  DateTime lastUpdateTimeGrade = DateTime.parse("20010101");
  DateTime lastUpdateTimeCourse = DateTime.parse("20010101");
  DateTime lastUpdateTimeHomework = DateTime.parse("20010101");

  // 爬虫区
  String? username;
  String? password;
  Spider? _spider;

  bool get isGrs => !username!.startsWith('3');

  // 按学期整理好的学业信息，包括该学期的所有科目、考试、课表、均绩等
  List<Semester> semesters = <Semester>[];

  // 按课程号整理好的成绩单（方便算重修成绩）
  Map<String, List<Grade>> grades = {};

  // 保研 GPA, 四个数据依次为五分制、四分制（4.3 分制）、原始的四分制、百分制
  List<double> gpa = [0.0, 0.0, 0.0, 0.0];

  // 出国 GPA, 四个数据依次为五分制、四分制（4.3 分制）、原始的四分制、百分制
  List<double> aboardGpa = [0.0, 0.0, 0.0, 0.0];

  // 所获学分
  double credit = 0.0;

  // 主修成绩，两个数据依次为主修GPA，主修学分
  List<double> majorGpaAndCredit = [0.0, 0.0];

  // 特殊日期
  Map<DateTime, String> specialDates = {};

  // 作业（学在浙大）
  List<Todo> todos = [];

  // 实践学分（素质拓展）
  double pt2 = 0.0; // 二课分
  double pt3 = 0.0; // 三课分
  double pt4 = 0.0; // 四课分
  bool isPracticeScoresGet = false; // 是否成功获取到二三四课堂分数
  List<PracticeScoreItem> practiceScoreItems = [];
  PracticeDataSource practiceDataSource = PracticeDataSource.unavailable;
  DateTime? practiceUpdatedAt;
  bool practiceDetailsAvailable = false;
  bool practiceDetailsStale = false;

  int get gradedCourseCount {
    return grades.values.fold(0, (p, e) => p + e.length);
  }

  List<Period> get periods {
    return semesters.fold(<Period>[], (p, e) => p + e.periods);
  }

  Semester get thisSemester {
    if (semesters.length > 1) {
      if (semesters[1]
          .periods
          .last
          .endTime
          .isAfter(DateTime.now().subtract(const Duration(days: 14)))) {
        return semesters[1];
      } else {
        return semesters[0];
      }
    } else {
      return semesters.isEmpty ? Semester('未刷新') : semesters.first;
    }
  }

  bool get isNearExamWeek {
    var thisSem = thisSemester;
    for (var exam in thisSem.exams) {
      var now = DateTime.now();
      if (now.isAfter(exam.time[0].subtract(const Duration(days: 3))) &&
          now.isBefore(exam.time[0].add(const Duration(days: 3)))) {
        return true;
      }
    }
    return false;
  }

  // 初始化以获取Cookies，并刷新数据
  Future<List<String?>> login({
    RefreshOrigin origin = RefreshOrigin.foreground,
  }) {
    return DiagnosticLogService.instance.runRefresh(
      origin: origin,
      action: () => RefreshCoordinator.run(
        account: username ?? '<unknown>',
        origin: origin,
        refreshId: DiagnosticLogService.instance.currentRefreshId ?? 'unknown',
        action: _loginInternal,
        busyResult: [
          degradedRefreshText('登录：同一账号已有登录或刷新任务，本次已跳过'),
        ],
      ),
    );
  }

  Future<List<String?>> _loginInternal() async {
    if (username == null || password == null) {
      return ["未登录"];
    }
    if (username == '3200000000') {
      _spider = MockSpider();
    } else if (!isGrs) {
      _spider = UgrsSpider(username!, password!);
    } else {
      _spider = GrsSpider(username!, password!);
    }
    _spider!.db = _db;
    var loginErrorMessage = await _spider!.login();
    if (loginErrorMessage.every((e) => e == null)) {
      isLogan = true;
      _db?.setScholar(this);
    }
    return loginErrorMessage;
  }

  Future<bool> logout() async {
    username = "";
    password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0, 0.0];
    credit = 0.0;
    majorGpaAndCredit = [0.0, 0.0];
    pt2 = 0.0;
    pt3 = 0.0;
    pt4 = 0.0;
    isPracticeScoresGet = false;
    practiceScoreItems = [];
    practiceDataSource = PracticeDataSource.unavailable;
    practiceUpdatedAt = null;
    practiceDetailsAvailable = false;
    practiceDetailsStale = false;
    isLogan = false;
    lastUpdateTimeGrade = DateTime.parse("20010101");
    lastUpdateTimeCourse = DateTime.parse("20010101");
    lastUpdateTimeHomework = DateTime.parse("20010101");
    _spider?.logout();
    await _db?.removeScholar();
    await _db?.removeAllCachedWebPage();
    return true;
  }

  // 刷新数据
  var _mutex = 0;

  Future<List<String?>> refresh({
    RefreshOrigin origin = RefreshOrigin.foreground,
  }) async {
    return DiagnosticLogService.instance.runRefresh(
      origin: origin,
      action: () => RefreshCoordinator.run(
        account: username ?? '<unknown>',
        origin: origin,
        refreshId: DiagnosticLogService.instance.currentRefreshId ?? 'unknown',
        action: () async {
          if (!isLogan) {
            final loginErrors = await _loginInternal();
            if (loginErrors.any((error) => error != null)) {
              return loginErrors;
            }
          }
          return _refreshInternal();
        },
        busyResult: [
          degradedRefreshText('刷新：同一账号已有刷新任务，本次已跳过'),
        ],
      ),
    );
  }

  Future<List<String?>> _refreshInternal() async {
    if (!isLogan) {
      return ["未登录"];
    }
    if (_mutex > 0) {
      // Wait until the mutex is released.
      while (_mutex > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return [];
    }
    _mutex++;
    try {
      return await _spider?.getEverything().then((value) async {
            for (var e in value.item1) {
              if (e != null) {
                DiagnosticLogService.instance.record(
                  level: CelechronLogLevel.warning,
                  module: '登录',
                  operation: 'result',
                  message: e,
                );
              }
            }
            for (var e in value.item2) {
              if (e != null) {
                DiagnosticLogService.instance.record(
                  level: isDegradedRefreshText(e)
                      ? CelechronLogLevel.warning
                      : CelechronLogLevel.error,
                  module: '刷新聚合',
                  operation: 'moduleResult',
                  message: e,
                );
              }
            }
            if (value.item1.every((e) => e == null)) {
              updateLastUpdateTime(value.item2);
            }
            var tempSemester = value.item3;
            final tempGrades = <String, List<Grade>>{};
            final courseIdMappingList =
                Get.find<OptionController>(tag: 'optionController')
                    .courseIdMappingList;
            final courseIdMappingMap = {
              for (var mapping in courseIdMappingList) mapping.id1: mapping.id2
            };
            for (final grade in value.item4) {
              try {
                final matchClass =
                    RegExp(r'(\(.*\)-(.*?))-.*').firstMatch(grade.id);
                if (matchClass == null && grade.id.length < 22) {
                  throw const FormatException('成绩课程编号长度不足');
                }
                var key = matchClass?.group(2) ?? grade.id.substring(14, 22);
                if (key.startsWith('PPAE') || key.startsWith('401')) {
                  key = matchClass?.group(1) ?? grade.id.substring(0, 22);
                }
                key = courseIdMappingMap[key] ?? key;
                tempGrades.putIfAbsent(key, () => <Grade>[]).add(grade);
              } on Object catch (error, stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                      '跳过无法归类的成绩 ${grade.id}：${error.runtimeType}: $error\n$stackTrace');
                }
              }
            }
            var tempMajorGpaAndCredit = value.item5;
            var tempSpecialDates = value.item6;
            var tempTodos = value.item7;

            PracticeScoreSnapshot? tempPracticeSnapshot;
            // 获取实践学分数据（仅本科生）
            if (_spider is UgrsSpider && !isGrs) {
              tempPracticeSnapshot = (_spider as UgrsSpider).practiceSnapshot;
            }

            setScholar(
                value.item2,
                tempSemester,
                tempGrades,
                tempMajorGpaAndCredit,
                tempSpecialDates,
                tempTodos,
                tempPracticeSnapshot);

            // 保研成绩，只取第一次
            var netGrades = grades.values.map((e) => e.first);
            if (netGrades.isNotEmpty) {
              gpa = GpaHelper.calculateGpa(netGrades).item1;
            }
            // 出国成绩，取最高的一次
            var aboardNetGrades = grades.values.map((e) {
              e.sort((a, b) => a.hundredPoint.compareTo(b.hundredPoint));
              return e.last;
            });
            if (aboardNetGrades.isNotEmpty) {
              var result = GpaHelper.calculateGpa(aboardNetGrades);
              aboardGpa = result.item1;
              // 所获学分，不包括挂科的。
              credit = result.item2;
            } else {
              credit = 0.0;
            }

            await _db?.setScholar(this);
            return value.item2;
          }) ??
          ['未登录'];
    } on Object catch (error, stackTrace) {
      // 网络异常等情况下保留已有数据，不清空
      final exception = exceptionFrom(
        error,
        context: '刷新聚合',
        stackTrace: stackTrace,
      );
      return [exception.toString()];
    } finally {
      _mutex--;
    }
  }

  void updateLastUpdateTime(List<String?> errorMessage) {
    var errorItems = ["成绩", "课表", "作业"];
    var errorResult = [false, false, false];

    for (int i = 0; i < errorItems.length; i++) {
      for (var e in errorMessage) {
        if (e != null && e.contains(errorItems[i])) {
          errorResult[i] = true;
          break;
        }
      }
    }
    if (!errorResult[0]) {
      lastUpdateTimeGrade = DateTime.now();
    }
    if (!errorResult[1]) {
      lastUpdateTimeCourse = DateTime.now();
    }
    if (!errorResult[2]) {
      lastUpdateTimeHomework = DateTime.now();
    }
  }

  void setScholar(
      List<String?> errorMessage,
      List<Semester> tempSemesters,
      Map<String, List<Grade>> tempGrades,
      List<double> tempMajorGpaAndCredit,
      Map<DateTime, String> tempSpecialDates,
      List<Todo> tempTodos,
      PracticeScoreSnapshot? tempPracticeSnapshot) {
    var errorItems = ["成绩", "主修", "课表", "作业", "实践"];
    var errorResult = [false, false, false, false, false];

    for (int i = 0; i < errorItems.length; i++) {
      for (var e in errorMessage) {
        if (e != null &&
            !isDegradedRefreshText(e) &&
            e.contains(errorItems[i])) {
          errorResult[i] = true;
          break;
        }
      }
    }

    if (tempSpecialDates.isNotEmpty) {
      specialDates = tempSpecialDates;
    }
    if (errorResult[0] == false && tempGrades.isNotEmpty) {
      grades = tempGrades;
    }
    if (errorResult[1] == false && tempMajorGpaAndCredit.isNotEmpty) {
      majorGpaAndCredit = tempMajorGpaAndCredit;
    }
    if (errorResult[2] == false && tempSemesters.isNotEmpty) {
      semesters = tempSemesters;
    } else if (tempSemesters.isNotEmpty) {
      for (final incoming in tempSemesters) {
        final existingIndex =
            semesters.indexWhere((semester) => semester.name == incoming.name);
        if (existingIndex < 0) {
          semesters.add(incoming);
        } else {
          semesters[existingIndex].mergePartialFrom(incoming);
        }
      }
      semesters.sort((a, b) => b.name.compareTo(a.name));
    }
    if (errorResult[3] == false) {
      todos = tempTodos;
    }
    if (tempPracticeSnapshot != null) {
      final snapshot = tempPracticeSnapshot;
      if (snapshot.source == PracticeDataSource.unavailable) {
        isPracticeScoresGet = false;
        practiceDataSource = PracticeDataSource.unavailable;
        practiceDetailsStale = true;
      } else {
        isPracticeScoresGet = true;
        practiceDataSource = snapshot.source;
        practiceUpdatedAt = snapshot.updatedAt;
        practiceDetailsAvailable = snapshot.detailsAvailable;
        practiceDetailsStale = snapshot.stale;
        if (snapshot.detailsAvailable) {
          practiceScoreItems = List<PracticeScoreItem>.from(snapshot.items);
        } else {
          practiceScoreItems = [];
        }
        pt2 = snapshot.totalFor(1);
        pt3 = snapshot.totalFor(2);
        pt4 = snapshot.totalFor(3);
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'semesters': semesters,
      'grades': grades,
      'gpa': gpa,
      'aboardGpa': aboardGpa,
      'credit': credit,
      'majorGpaAndCredit': majorGpaAndCredit,
      'specialDates':
          specialDates.map((k, v) => MapEntry(k.toIso8601String(), v)),
      'lastUpdateTimeGrade': lastUpdateTimeGrade.toIso8601String(),
      'lastUpdateTimeCourse': lastUpdateTimeCourse.toIso8601String(),
      'lastUpdateTimeHomework': lastUpdateTimeHomework.toIso8601String(),
      'todos': todos,
      'pt2': pt2,
      'pt3': pt3,
      'pt4': pt4,
      'isPracticeScoresGet': isPracticeScoresGet,
      'practiceScoreItems':
          practiceScoreItems.map((item) => item.toJson()).toList(),
      'practiceDataSource': practiceDataSource.name,
      'practiceUpdatedAt': practiceUpdatedAt?.toIso8601String(),
      'practiceDetailsAvailable': practiceDetailsAvailable,
      'practiceDetailsStale': practiceDetailsStale,
    };
  }

  Future<void> recalculateGpa() async {
    grades =
        grades.values.expand((e) => e).fold(<String, List<Grade>>{}, (p, e) {
      // 体育课
      var matchClass = RegExp(r'(\(.*\)-(.*?))-.*').firstMatch(e.id);
      var key = matchClass?.group(2) ?? e.id.substring(14, 22);
      if (key.startsWith('PPAE') || key.startsWith('401')) {
        key = matchClass?.group(1) ?? e.id.substring(0, 22);
      }
      var courseIdMappingList =
          Get.find<OptionController>(tag: 'optionController')
              .courseIdMappingList;
      var courseIdMappingMap = {
        for (var e in courseIdMappingList) e.id1: e.id2
      };
      if (courseIdMappingMap.containsKey(key)) {
        key = courseIdMappingMap[key]!;
      }
      p.putIfAbsent(key, () => <Grade>[]).add(e);
      return p;
    });

    // 保研成绩，只取第一次
    var netGrades = grades.values.map((e) => e.first);
    if (netGrades.isNotEmpty) {
      gpa = GpaHelper.calculateGpa(netGrades).item1;
    }
    // 出国成绩，取最高的一次
    var aboardNetGrades = grades.values.map((e) {
      e.sort((a, b) => a.hundredPoint.compareTo(b.hundredPoint));
      return e.last;
    });
    if (aboardNetGrades.isNotEmpty) {
      var result = GpaHelper.calculateGpa(aboardNetGrades);
      aboardGpa = result.item1;
      // 所获学分，不包括挂科的。
      credit = result.item2;
    } else {
      credit = 0.0;
    }

    await _db?.setScholar(this);
  }

  Scholar.fromJson(Map<String, dynamic> json) {
    username = asString(json['username']); // <=0.2.6 Compatibility
    password = asString(json['password']); // <=0.2.6 Compatibility

    semesters = [];
    for (final rawSemester in asDynamicList(json['semesters']) ?? const []) {
      final semesterMap = asStringMap(rawSemester);
      if (semesterMap == null) continue;
      try {
        semesters.add(Semester.fromJson(semesterMap));
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('跳过损坏的本地学期数据：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }

    grades = {};
    final rawGrades = asStringMap(json['grades']) ?? const {};
    for (final entry in rawGrades.entries) {
      final parsedGrades = <Grade>[];
      for (final rawGrade in asDynamicList(entry.value) ?? const []) {
        final gradeMap = asStringMap(rawGrade);
        if (gradeMap == null) continue;
        try {
          final grade = Grade.fromJson(gradeMap);
          if (grade.id.isNotEmpty) parsedGrades.add(grade);
        } on Object catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint('跳过损坏的本地成绩数据：${error.runtimeType}: $error\n$stackTrace');
          }
        }
      }
      if (parsedGrades.isNotEmpty) grades[entry.key] = parsedGrades;
    }

    List<double> numberList(Object? value, int expectedLength) {
      final parsed = (asDynamicList(value) ?? const [])
          .map(asDouble)
          .whereType<double>()
          .toList();
      if (expectedLength == 4 && parsed.length == 3) {
        parsed.insert(2, 0.0);
      }
      return parsed.length == expectedLength
          ? parsed
          : List<double>.filled(expectedLength, 0.0);
    }

    gpa = numberList(json['gpa'], 4);
    aboardGpa = numberList(json['aboardGpa'], 4);
    credit = asDouble(json['credit']) ?? 0.0;
    majorGpaAndCredit = numberList(json['majorGpaAndCredit'], 2);

    specialDates = {};
    for (final entry
        in (asStringMap(json['specialDates']) ?? const {}).entries) {
      final date = asDateTime(entry.key);
      final description = asString(entry.value);
      if (date != null && description != null) {
        specialDates[date] = description;
      }
    }
    lastUpdateTimeGrade =
        asDateTime(json['lastUpdateTimeGrade']) ?? DateTime(2001);
    lastUpdateTimeCourse =
        asDateTime(json['lastUpdateTimeCourse']) ?? DateTime(2001);
    lastUpdateTimeHomework =
        asDateTime(json['lastUpdateTimeHomework']) ?? DateTime(2001);

    todos = [];
    for (final rawTodo in asDynamicList(json['todos']) ?? const []) {
      final todoMap = asStringMap(rawTodo);
      if (todoMap == null) continue;
      try {
        final todo = Todo.fromJson(todoMap);
        if (todo.id.isNotEmpty) todos.add(todo);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('跳过损坏的本地作业数据：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    pt2 = asDouble(json['pt2']) ?? 0.0;
    pt3 = asDouble(json['pt3']) ?? 0.0;
    pt4 = asDouble(json['pt4']) ?? 0.0;
    isPracticeScoresGet = asBool(json['isPracticeScoresGet']) ?? false;
    final hasPracticeItemsField = json.containsKey('practiceScoreItems');
    practiceScoreItems = [];
    for (final rawItem
        in asDynamicList(json['practiceScoreItems']) ?? const []) {
      final itemMap = asStringMap(rawItem);
      if (itemMap == null) continue;
      try {
        final item = PracticeScoreItem.fromJson(itemMap);
        if (!item.deleted) practiceScoreItems.add(item);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('跳过损坏的本地实践项目数据：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    practiceDataSource = PracticeDataSource.fromJson(
      json['practiceDataSource'],
    );
    practiceUpdatedAt = asDateTime(json['practiceUpdatedAt'])?.toLocal();
    practiceDetailsAvailable = asBool(json['practiceDetailsAvailable']) ??
        (hasPracticeItemsField && practiceScoreItems.isNotEmpty);
    practiceDetailsStale = asBool(json['practiceDetailsStale']) ?? false;
    if (!json.containsKey('practiceDataSource') && isPracticeScoresGet) {
      practiceDataSource = PracticeDataSource.zdbkCache;
      practiceDetailsAvailable = false;
      practiceDetailsStale = true;
    }
    if (hasPracticeItemsField && practiceDetailsAvailable) {
      final totals = PracticeScoreItem.approvedTotals(practiceScoreItems);
      pt2 = totals[1] ?? 0;
      pt3 = totals[2] ?? 0;
      pt4 = totals[3] ?? 0;
    }
    isLogan = true;
  }
}
