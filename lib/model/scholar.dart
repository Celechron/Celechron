import 'package:get/get.dart';

import 'package:celechron/page/option/option_controller.dart';

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
  Future<List<String?>> login() async {
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

  Future<List<String?>> refresh() async {
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
    return await _spider?.getEverything().then((value) async {
          for (var e in value.item1) {
            // ignore: avoid_print
            if (e != null) print(e);
          }
          for (var e in value.item2) {
            // ignore: avoid_print
            if (e != null) print(e);
          }
          if (value.item1.every((e) => e == null)) {
            updateLastUpdateTime(value.item2);
          }
          var tempSemester = value.item3;
          var tempGrades = value.item4.fold(<String, List<Grade>>{}, (p, e) {
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
          var tempMajorGpaAndCredit = value.item5;
          var tempSpecialDates = value.item6;
          var tempTodos = value.item7;

          var tempIsPracticeScoresGet = false;
          var tempPt2 = 0.0, tempPt3 = 0.0, tempPt4 = 0.0;
          // 获取实践学分数据（仅本科生）
          if (_spider is UgrsSpider && !isGrs) {
            var ugrsSpider = _spider as UgrsSpider;
            tempIsPracticeScoresGet = ugrsSpider.isPracticeScoresGet;
            if (tempIsPracticeScoresGet) {
              var practiceScores = ugrsSpider.practiceScores;
              if (practiceScores != null) {
                tempPt2 = practiceScores['pt2'] ?? 0.0;
                tempPt3 = practiceScores['pt3'] ?? 0.0;
                tempPt4 = practiceScores['pt4'] ?? 0.0;
              }
            }
          } else {
            tempIsPracticeScoresGet = false;
          }

          setScholar(
              value.item2,
              tempSemester,
              tempGrades,
              tempMajorGpaAndCredit,
              tempSpecialDates,
              tempTodos,
              tempIsPracticeScoresGet,
              tempPt2,
              tempPt3,
              tempPt4);

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
          }
          // 无成绩数据时不重置学分，保留之前的缓存值

          await _db?.setScholar(this);
          return value.item1.every((e) => e == null)
              ? value.item2
              : value.item1;
        }).whenComplete(() => _mutex--) ??
        ['未登录'];
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
      bool tempIsPracticeScoresGet,
      double tempPt2,
      double tempPt3,
      double tempPt4) {
    var errorItems = ["成绩", "主修", "课表", "作业", "实践"];
    var errorResult = [false, false, false, false, false];

    for (int i = 0; i < errorItems.length; i++) {
      for (var e in errorMessage) {
        if (e != null && e.contains(errorItems[i])) {
          errorResult[i] = true;
          break;
        }
      }
    }

    if (tempSpecialDates.isNotEmpty) {
      specialDates = tempSpecialDates;
    }
    // 无错误时更新数据；有错误但当前数据为空时，使用缓存数据作为回退
    if (tempGrades.isNotEmpty &&
        (errorResult[0] == false || grades.isEmpty)) {
      grades = tempGrades;
    }
    if (tempMajorGpaAndCredit.isNotEmpty &&
        (errorResult[1] == false ||
            (majorGpaAndCredit[0] == 0.0 && majorGpaAndCredit[1] == 0.0))) {
      majorGpaAndCredit = tempMajorGpaAndCredit;
    }
    if (tempSemesters.isNotEmpty &&
        (errorResult[2] == false || semesters.isEmpty)) {
      semesters = tempSemesters;
    }
    if (tempTodos.isNotEmpty &&
        (errorResult[3] == false || todos.isEmpty)) {
      todos = tempTodos;
    }
    if (errorResult[4] == false) {
      isPracticeScoresGet = tempIsPracticeScoresGet;
    }
    if (tempIsPracticeScoresGet &&
        (errorResult[4] == false ||
            (!isPracticeScoresGet && pt2 == 0.0 && pt3 == 0.0 && pt4 == 0.0))) {
      pt2 = tempPt2;
      pt3 = tempPt3;
      pt4 = tempPt4;
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
    username = json.containsKey('username')
        ? json['username']
        : null; // <=0.2.6 Compatibility
    password = json.containsKey('password')
        ? json['password']
        : null; // <=0.2.6 Compatibility
    semesters =
        (json['semesters'] as List).map((e) => Semester.fromJson(e)).toList();
    grades = (json['grades'] as Map<String, dynamic>).map((key, value) {
      return MapEntry(
          key, (value as List).map((e) => Grade.fromJson(e)).toList());
    });
    gpa = List<double>.from(json['gpa']);
    aboardGpa = List<double>.from(json['aboardGpa']);
    credit = json['credit'];
    majorGpaAndCredit = List<double>.from(json['majorGpaAndCredit']);
    specialDates = ((json['specialDates'] ?? {}) as Map)
        .map((k, v) => MapEntry(DateTime.parse(k as String), v as String));
    lastUpdateTimeGrade =
        DateTime.parse(json['lastUpdateTimeGrade'] ?? "20010101");
    lastUpdateTimeCourse =
        DateTime.parse(json['lastUpdateTimeCourse'] ?? "20010101");
    lastUpdateTimeHomework =
        DateTime.parse(json['lastUpdateTimeHomework'] ?? "20010101");
    todos = json.containsKey('todos') // back compatibility
        ? (json['todos'] as List).map((e) => Todo.fromJson(e)).toList()
        : [];
    pt2 = json.containsKey('pt2') ? (json['pt2'] as num).toDouble() : 0.0;
    pt3 = json.containsKey('pt3') ? (json['pt3'] as num).toDouble() : 0.0;
    pt4 = json.containsKey('pt4') ? (json['pt4'] as num).toDouble() : 0.0;
    isPracticeScoresGet = json.containsKey('isPracticeScoresGet')
        ? (json['isPracticeScoresGet'] as bool)
        : false;
    isLogan = true;
    if (gpa.length == 3) {
      gpa.insert(2, 0);
    }
    if (aboardGpa.length == 3) {
      aboardGpa.insert(2, 0);
    }
  }
}
