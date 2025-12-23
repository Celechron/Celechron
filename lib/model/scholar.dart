import 'dart:async';
import 'dart:io';

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
  DateTime lastUpdateTime = DateTime.parse("20010101");

  // 最后一次同步错误信息（null 表示同步成功）
  String? lastSyncError;

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
    isLogan = false;
    lastUpdateTime = DateTime.parse("20010101");
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
          if (value.item1.every((e) => e == null) &&
              value.item2.every((e) => e == null)) {
            lastUpdateTime = DateTime.now();
            lastSyncError = null;
          } else {
            lastSyncError = '数据同步失败';
          }

          // 获取失败时不覆盖本地数据
          if (value.item2.every((e) => e == null) || value.item3.isNotEmpty) {
            semesters = value.item3;
          }

          if (value.item2.every((e) => e == null) || value.item4.isNotEmpty) {
            grades = value.item4.fold(<String, List<Grade>>{}, (p, e) {
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
          }

          if (value.item2.every((e) => e == null) || value.item5.isNotEmpty) {
            majorGpaAndCredit = value.item5;
          }

          if (value.item2.every((e) => e == null) || value.item6.isNotEmpty) {
            specialDates = value.item6;
          }

          if (value.item2.every((e) => e == null) || value.item7.isNotEmpty) {
            todos = value.item7;
          }

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
          return value.item1.every((e) => e == null)
              ? value.item2
              : value.item1;
        }).catchError((e) {
          lastSyncError = '数据同步失败';
          if (e is SocketException) {
            return <String?>['无法连接到教务网，请检查网络连接'];
          } else if (e is TimeoutException) {
            return <String?>['连接教务网超时，请稍后重试'];
          }
          return <String?>['获取数据时发生错误：$e'];
        }).whenComplete(() => _mutex--) ??
        ['未登录'];
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
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
      'todos': todos,
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
    lastUpdateTime = DateTime.parse(json['lastUpdateTime']);
    todos = json.containsKey('todos') // back compatibility
        ? (json['todos'] as List).map((e) => Todo.fromJson(e)).toList()
        : [];
    isLogan = true;
    if (gpa.length == 3) {
      gpa.insert(2, 0);
    }
    if (aboardGpa.length == 3) {
      aboardGpa.insert(2, 0);
    }
  }
}
