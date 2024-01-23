import 'package:celechron/model/period.dart';
import 'package:celechron/utils/gpahelper.dart';
import 'package:get/get.dart';

import 'grade.dart';
import 'semester.dart';
import 'package:celechron/http/spider.dart';
import 'package:celechron/database/database_helper.dart';

class User {
  // 构造用户对象
  User();

  final DatabaseHelper _db = Get.find<DatabaseHelper>(tag: 'db');
  // 登录状态
  bool isLogin = false;
  DateTime lastUpdateTime = DateTime.parse("20010101");

  // 爬虫区
  late String username;
  late String _password;
  late Spider _spider;

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

  set password(String password) {
    _password = password;
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
    _spider = Spider(username, _password);
    var loginErrorMessage = await _spider.login();
    if (loginErrorMessage.every((e) => e == null)) {
      isLogin = true;
      _db.setUser(this);
    }
    return loginErrorMessage;
  }

  Future<bool> logout() async {
    username = "";
    _password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0, 0.0];
    credit = 0.0;
    majorGpaAndCredit = [0.0, 0.0];
    isLogin = false;
    lastUpdateTime = DateTime.parse("20010101");
    _spider.logout();
    return _db.removeUser().then((value) => true).catchError((e) => false);
  }

  // 刷新数据
  Future<List<String?>> refresh() async {
    return await _spider.getEverything().then((value) async {
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
      }
      semesters = value.item3;
      grades = value.item4;
      majorGpaAndCredit = value.item5;
      specialDates = value.item6;
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

      await _db.setUser(this);
      return value.item1.every((e) => e == null) ? value.item2 : value.item1;
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': _password,
      'semesters': semesters,
      'grades': grades,
      'gpa': gpa,
      'aboardGpa': aboardGpa,
      'credit': credit,
      'majorGpaAndCredit': majorGpaAndCredit,
      'specialDates':
          specialDates.map((k, v) => MapEntry(k.toIso8601String(), v)),
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
    };
  }

  User.fromJson(Map<String, dynamic> json) {
    username = json['username'];
    _password = json['password'];
    _spider = Spider(username, _password);
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
    isLogin = true;
  }
}
