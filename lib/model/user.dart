import 'dart:convert';
import 'dart:io';

import 'grade.dart';
import 'semester.dart';
import '../http/spider.dart';
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
    _spider = Spider(username, _password);
    try {
      await _spider.login();
      await refresh();
      return isLogin = true;
    } on SocketException {
      throw Exception('网络错误');
    }
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
    return deleteFromDb().then((value) => true).catchError((e) => false);
  }

  // 刷新数据
  Future<bool> refresh() async {
    var semesters = <Semester>[]; // 临时变量，用于存储从爬虫获取到的数据
    var grades = <String, List<Grade>>{}; // 临时变量，用于存储从爬虫获取到的数据
    var majorGpaAndCredit = [0.0, 0.0]; // 临时变量，用于存储从爬虫获取到的数据
    return await _spider
        .getSemesterDetails(semesters, grades, majorGpaAndCredit)
        .then((value) async {
      this.semesters = semesters;
      this.grades = grades;
      this.majorGpaAndCredit = majorGpaAndCredit;
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
      await saveToDb();
      return true;
    }).catchError((e) {
      print(e);
      return false;
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
    };
  }

  Future<void> saveToDb() async {
    await db.setUser(this);
  }

  Future<bool> loadFromDb() async {
    var user = db.getUser();
    if (user == null) {
      return false;
    }
    var json = jsonDecode(user) as Map<String, dynamic>;
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
    return true;
  }

  Future<void> deleteFromDb() async {
    db.removeUser();
  }
}
