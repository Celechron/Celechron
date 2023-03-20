import 'dart:convert';

import 'grade.dart';
import 'semester.dart';
import '../http/spider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:celechron/database/database_helper.dart';

class User {
  // 单例模式，保证每次获取到的都是同一个User对象，不会重复创建
  static User? _user;

  factory User() => _user ??= User._internal();

  // 构造用户对象
  User._internal();

  // 登录状态
  bool isLogin = false;

  // 爬虫区
  late String username;
  late String _password;
  late Spider _spider;

  // 按学期整理好的详细数据，包括该学期的所有科目、考试、课表、均绩等
  List<Semester> semesters = <Semester>[];

  // 按课程号整理好的成绩单，方便算重修成绩
  Map<String, List<Grade>> grades = {};

  // 保研GPA, 三个数据依次为五分制，四分制，百分制
  List<double> gpa = [0.0, 0.0, 0.0];

  // 出国GPA, 三个数据依次为五分制，四分制，百分制
  List<double> aboardGpa = [0.0, 0.0, 0.0];

  // 所获学分
  double credit = 0.0;

  // 主修数据，两个数据依次为主修GPA，主修学分
  List<double> majorGpaAndCredit = [0.0, 0.0];

  set password(String password) {
    _password = password;
  }

  // 初始化以获取Cookies，并刷新数据
  Future<bool> login() async {
    Spider(username, _password);
    await _spider.login();
    isLogin = true;
    return await refresh();
  }

  Future<bool> logout() async {
    username = "";
    _password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0];
    credit = 0.0;
    majorGpaAndCredit = [0.0, 0.0];
    isLogin = false;
    _spider.logout();
    return await deleteFromDb();
  }

  // 刷新数据
  Future<bool> refresh() async {
    grades.clear();
    await _spider
        .getSemesterDetails(semesters, grades, majorGpaAndCredit)
        .then((value) {
      // 保研成绩，只取第一次
      var netGrades = grades.values.map((e) => e.first);
      if (netGrades.isNotEmpty) {
        gpa = Grade.calculateGpa(netGrades);
      }
      // 出国成绩，取最高的一次
      var aboardNetGrades = grades.values.map((e) {
        e.sort((a, b) => a.hundredPoint.compareTo(b.hundredPoint));
        return e.last;
      });
      if (aboardNetGrades.isNotEmpty) {
        aboardGpa = Grade.calculateGpa(aboardNetGrades);
      }
      // 这个算的是所获学分，不包括挂科的。因为出国成绩单取最高的一次成绩，所以就把挂科的学分算对了
      credit =
          aboardNetGrades.fold<double>(0.0, (p, e) => p + e.effectiveCredit);
      // 保存到本地
      saveToDb();
    });
    return true;
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
    isLogin = true;
  }

  Future<bool> saveToDb() async {
    return await db.setUser(this);
  }

  Future<bool> loadFromDb() async {
    return true;
  }

  Future<bool> deleteFromDb() async {
    var box = await Hive.openBox('user');
    return box.delete('user').then((value) => true).catchError((e) {
      return false;
    });
  }
}
