import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/tuple.dart';
import 'package:get/get.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'zjuServices/appservice.dart';
import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';

class Spider {
  late HttpClient _httpClient;
  late String _username;
  late String _password;
  late AppService _appService;
  late Zdbk _zdbk;
  late TimeConfigService _timeConfigService;
  Cookie? _iPlanetDirectoryPro;
  DateTime _lastUpdateTime = DateTime(0);
  static List<String> fetchSequence = ['配置', '考试', '课表', '成绩', '主修'];

  Spider(String username, String password) {
    _httpClient = HttpClient();
    _httpClient.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    _appService = AppService();
    _zdbk = Zdbk();
    _timeConfigService = TimeConfigService();
    _username = username;
    _password = password;
  }

  Future<List<String?>> login() async {
    var loginErrorMessages = <String?>[null];
    _iPlanetDirectoryPro =
        await ZjuAm.getSsoCookie(_httpClient, _username, _password)
            .timeout(const Duration(seconds: 8))
            .catchError((e) {
      loginErrorMessages[0] = "无法登录统一身份认证，$e";
      return null;
    });
    if (_iPlanetDirectoryPro == null) return loginErrorMessages;
    loginErrorMessages.addAll(await Future.wait([
      _appService
          .login(_httpClient, _iPlanetDirectoryPro)
          // ignore: unnecessary_cast
          .then((value) => null as String?)
          .timeout(const Duration(seconds: 8))
          .catchError((e) => "无法登录钉钉工作台，$e"),
      _zdbk
          .login(_httpClient, _iPlanetDirectoryPro)
          // ignore: unnecessary_cast
          .then((value) => null as String?)
          .timeout(const Duration(seconds: 8))
          .catchError((e) => "无法登录教务网，$e"),
    ]).then((value) {
      if (value.every((e) => e == null)) _lastUpdateTime = DateTime.now();
      return [value[0], value[1]];
    }));
    return loginErrorMessages;
  }

  void logout() {
    _username = "";
    _password = "";
    _iPlanetDirectoryPro = null;
    _appService.logout();
    _zdbk.logout();
    Get.find<DatabaseHelper>(tag: 'db').removeAllCachedWebPage();
  }

  // 返回一堆错误信息，如果有的话。看看返回的List是不是空的就知道刷新是否成功。
  Future<
      Tuple6<
          List<String?>,
          List<String?>,
          List<Semester>,
          Map<String, List<Grade>>,
          List<double>,
          Map<DateTime, String>>> getEverything() async {
    // 返回值初始化
    var outSemesters = <Semester>[];
    var outGrades = <String, List<Grade>>{};
    var outMajorGrade = <double>[];
    var outSpecialDates = <DateTime, String>{};
    var loginErrorMessages = <String?>[null, null, null];

    // 如果Cookie过期了，就重新登录
    if (DateTime.now().difference(_lastUpdateTime).inMinutes > 15) {
      loginErrorMessages = await login();
    }

    // 建立学期编号与“入学以来第几个学期”的映射。如"2022-2023-1"对应第22年入学同学的第1个学期，即"2022-2023秋冬"。
    var yearNow = DateTime.now().year;
    var yearEnroll = int.parse(_username.substring(1, 3)) + 2000;
    var yearGraduate = yearEnroll + 7;
    Map<String, int> semesterIndexMap = <String, int>{};
    for (var i = 7, j = 0; i >= 0; i--, j++) {
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', j * 2)]);
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', j * 2 + 1)]);
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
    }

    // 查校历（存在CDN上，JSON格式的，内含学期起止日期、单日时间表、放假调休等信息）
    var semesterConfigFetches = <Future<String?>>[];
    // 查考试
    var examFetches = <Future<String?>>[];
    // 查课表
    var timetableFetches = <Future<String?>>[];
    while (yearEnroll <= yearNow && yearEnroll <= yearGraduate) {
      var yearStr = '$yearEnroll-${yearEnroll + 1}';
      semesterConfigFetches.add(
          _timeConfigService.getConfig(_httpClient, '$yearStr-1').then((value) {
        if (value.item2 != null) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addZjuCalendar(jsonDecode(value.item2!));
          outSpecialDates.addAll((jsonDecode(value.item2!)['holiday'] as Map)
              .map((k, v) =>
                  MapEntry(DateTime.parse(k as String), '${v as String}放假')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['exchange'] as Map)
              .map((k, v) => MapEntry(
                  DateTime.parse((k as String).substring(0, 8)),
                  '${v as String}放假·调 ${DateTime.parse(k.substring(8, 16)).month} 月 ${DateTime.parse(k.substring(8, 16)).day} 日')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['exchange'] as Map)
              .map((k, v) => MapEntry(
                  DateTime.parse((k as String).substring(8, 16)),
                  '${v as String}调休·调 ${DateTime.parse(k.substring(0, 8)).month} 月 ${DateTime.parse(k.substring(0, 8)).day} 日')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['dummy'] as Map).map(
              (k, v) =>
                  MapEntry(DateTime.parse(k as String), '${v as String}放假')));
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      semesterConfigFetches.add(
          _timeConfigService.getConfig(_httpClient, '$yearStr-2').then((value) {
        if (value.item2 != null) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addZjuCalendar(jsonDecode(value.item2!));
          outSpecialDates.addAll((jsonDecode(value.item2!)['holiday'] as Map)
              .map((k, v) =>
                  MapEntry(DateTime.parse(k as String), '${v as String}放假')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['exchange'] as Map)
              .map((k, v) => MapEntry(
                  DateTime.parse((k as String).substring(0, 8)),
                  '${v as String}放假·调 ${DateTime.parse(k.substring(8, 16)).month} 月 ${DateTime.parse(k.substring(8, 16)).day} 日')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['exchange'] as Map)
              .map((k, v) => MapEntry(
                  DateTime.parse((k as String).substring(8, 16)),
                  '${v as String}调休·调 ${DateTime.parse(k.substring(0, 8)).month} 月 ${DateTime.parse(k.substring(0, 8)).day} 日')));
          outSpecialDates.addAll((jsonDecode(value.item2!)['dummy'] as Map).map(
              (k, v) =>
                  MapEntry(DateTime.parse(k as String), '${v as String}放假')));
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      // 查考试
      /*examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "1").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "2").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));*/
      // 查课表
      timetableFetches
          .add(_zdbk.getTimetable(_httpClient, yearStr, "1|秋").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1');
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      timetableFetches
          .add(_zdbk.getTimetable(_httpClient, yearStr, "1|冬").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1');
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      timetableFetches
          .add(_zdbk.getTimetable(_httpClient, yearStr, "2|春").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2');
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      timetableFetches
          .add(_zdbk.getTimetable(_httpClient, yearStr, "2|夏").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2');
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      yearEnroll++;
    }

    // 把 考试查询 和 校历查询 这两个任务分别加入 请求列表 。
    var fetches = <Future<String?>>[];
    fetches.add(Future.wait(semesterConfigFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    /*fetches.add(Future.wait(examFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));*/
    fetches.add(_zdbk.getExamsDto(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
      }
      return value.item1?.toString();
    }).catchError((e) => e.toString()));
    fetches.add(Future.wait(timetableFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

    // 查成绩，也加入请求列表
    fetches.add(_zdbk.getTranscript(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addGrade(e);
        //体育课
        var key = e.id.substring(14, 22);
        if (key.startsWith('401')) {
          key = e.id.substring(0, 22);
        }
        outGrades.putIfAbsent(key, () => <Grade>[]).add(e);
      }
      for (var e in outSemesters) {
        e.calculateGPA();
      }
      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // 查主修成绩，也加入请求列表
    fetches.add(_zdbk.getMajorGrade(_httpClient).then((value) {
      outMajorGrade.clear();
      outMajorGrade.addAll(value.item2);
      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // await一下，等待所有请求完成。然后，删除不包含考试、成绩、课程的空学期
    var fetchErrorMessages = await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere(
          (e) => e.grades.isEmpty && e.sessions.isEmpty && e.exams.isEmpty && e.courses.isEmpty);
    });

    // 检查是否有查询失败的情况
    if (fetchErrorMessages.every((e) => e == null)) {
      _lastUpdateTime = DateTime.now();
    }
    for (var i = 0; i < fetchErrorMessages.length; i++) {
      if (fetchErrorMessages[i] != null) {
        fetchErrorMessages[i] =
            '${fetchSequence[i]}查询出错：${fetchErrorMessages[i]}';
      }
    }

    for (var semester in outSemesters) {
      var toRemove = semester.courses.keys.toList();
      var toAdd = semester.courses.values
          .map((e) => MapEntry(e.id ?? e.name + e.toString(), e))
          .toList();
      semester.courses.addEntries(toAdd);
      for (var key in toRemove) {
        semester.courses.remove(key);
      }
    }

    return Tuple6(loginErrorMessages, fetchErrorMessages, outSemesters,
        outGrades, outMajorGrade, outSpecialDates);
  }
}
