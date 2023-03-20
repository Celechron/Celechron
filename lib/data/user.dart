import 'dart:convert';

import 'grade.dart';
import 'semester.dart';
import '../spider/spider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  // 单例模式，保证每次获取到的都是同一个User对象，不会重复创建
  static User? _user;

  factory User() => _user ??= User._internal();

  bool isLogin = false;
  // 爬虫区
  late String _username;
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

  // 通过用户名和密码构造用户对象
  User._internal();

  String get username => _username;

  // 输入用户名与密码
  configUser(String username, String password) {
    _username = username;
    _password = password;
    _spider = Spider(username, password);
  }

  // 初始化以获取Cookies
  Future<bool> init() async {
    await _spider.login();
    isLogin = true;
    return await refresh();
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
      saveToSp();
    });
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'username': _username,
      'password': _password,
      'semesters': semesters,
      'grades': grades,
      'gpa': gpa,
      'aboardGpa': aboardGpa,
      'credit': credit,
      'majorGpaAndCredit': majorGpaAndCredit,
    };
  }

  Future<bool> saveToSp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString('user', jsonEncode(toJson()));
  }

  Future<bool> loadFromSp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('user');
    if (jsonString == null) {
      return false;
    }
    Map<String, dynamic> json = jsonDecode(jsonString);
    _username = json['username'];
    _password = json['password'];
    _spider = Spider(_username, _password);
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

  Future<bool> deleteFromSp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    return true;
  }

  Future<bool> logout() async {
    _username = "";
    _password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0];
    credit = 0.0;
    majorGpaAndCredit = [0.0, 0.0];
    isLogin = false;
    _spider.logout();
    return await deleteFromSp();
  }
}
