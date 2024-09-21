import 'period.dart';
import 'grade.dart';
import 'semester.dart';
import 'task.dart'; //引入和xzzd task有关
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

  //学在浙大的任务
  List<Task> xzzdTask= <Task>[];

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
    if(username == null || password == null) {
      return ["未登录"];
    }
    if (username == '3200000000') {
      _spider = MockSpider();
    } else if(!isGrs) {
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
    
    if(!isGrs){ //如果spider是ugrsSpider，则调用getXzzdTask
      //把spider特化为ugrsSpider，并调用getXzzdTask
      var ugrsSpider = _spider as UgrsSpider;
      var result = await ugrsSpider.getXzzdTask();
      xzzdTask = result; //todo:异常处理
    }
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

      await _db?.setScholar(this);
      return value.item1.every((e) => e == null) ? value.item2 : value.item1;
    }).whenComplete(() => _mutex--) ?? ['未登录'];
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
    };
  }

  Scholar.fromJson(Map<String, dynamic> json) {
    username = json.containsKey('username') ? json['username'] : null;    // <=0.2.6 Compatibility
    password = json.containsKey('password') ? json['password'] : null;   // <=0.2.6 Compatibility
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
    isLogan = true;
    if (gpa.length == 3) {
      gpa.insert(2, 0);
    }
    if (aboardGpa.length == 3) {
      aboardGpa.insert(2, 0);
    }
  }
}
