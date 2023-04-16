import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/time_config_service.dart';
import 'package:get/get.dart';

import '../model/grade.dart';
import '../model/semester.dart';
import 'zjuServices/appservice.dart';
import 'zjuServices/jwbinfosys.dart';
import 'zjuServices/zjuam.dart';

class Spider {
  late HttpClient _httpClient;
  late String _username;
  late String _password;
  late AppService _appService;
  late JwbInfoSys _jwbInfoSys;
  Cookie? _iPlanetDirectoryPro;
  DateTime _lastUpdateTime = DateTime(0);

  Spider(String username, String password) {
    _httpClient = HttpClient();
    _httpClient.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    _appService = AppService();
    _jwbInfoSys = JwbInfoSys();
    _username = username;
    _password = password;
  }

  Future<bool> login() async {
    _iPlanetDirectoryPro =
        await ZjuAm.getSsoCookie(_httpClient, _username, _password)
            .timeout(const Duration(seconds: 5))
            .catchError((e) => throw Exception("无法登录统一身份认证，${e.toString()}"));
    return await Future.wait([
      _appService
          .login(_httpClient, _iPlanetDirectoryPro!)
          .timeout(const Duration(seconds: 5))
          .catchError((e) => throw Exception("无法登录钉工作台，${e.toString()}")),
      _jwbInfoSys
          .login(_httpClient, _iPlanetDirectoryPro!)
          .timeout(const Duration(seconds: 5))
          .catchError((e) => throw Exception("无法登录教务网，${e.toString()}")),
    ]).then((value) {
      _lastUpdateTime = DateTime.now();
      return value[0] && value[1];
    });
  }

  void logout() {
    _username = "";
    _password = "";
    _iPlanetDirectoryPro = null;
    _appService.logout();
    _jwbInfoSys.logout();
  }

  // 返回一堆错误信息，如果有的话。看看返回的List是不是空的就知道有没有成功了。
  Future<List<String?>> getEverything(List<Semester> outSemesters,
      Map<String, List<Grade>> outGrades, List<double> outMajorGrade, List<List<String>> outOriginalData) async {
    // Cookie过期，是有有效期的
    if (DateTime.now().difference(_lastUpdateTime).inMinutes > 15) {
      login();
    }

    // 建立学期号与学期列表的映射，如"2022-2023-1"对应第22年入学同学的第0个学期，即"2022-2023秋冬"。
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

    // 考试、时间配置要分学期查，用循环搞两个Future List
    var semesterConfigFetches = <Future<String?>>[];
    var examFetches = <Future<String?>>[];
    while (yearEnroll <= yearNow && yearEnroll <= yearGraduate) {
      var yearStr = '$yearEnroll-${yearEnroll + 1}';
      semesterConfigFetches.add(
          TimeConfigService.getConfig(_httpClient, '$yearStr-1').then((value) {
        if (value != null) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addTimeInfo(jsonDecode(value));
        }
        return null as String?;
      }).catchError((e) => e.toString()));
      semesterConfigFetches.add(
          TimeConfigService.getConfig(_httpClient, '$yearStr-2').then((value) {
        if (value != null) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addTimeInfo(jsonDecode(value));
        }
        return null as String?;
      }).catchError((e) => e.toString()));
      examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "1").then((value) {
        for (var e in value) {
          outSemesters[
                  semesterIndexMap[e.id.substring(1, 12)]!]
              .addExam(e);
        }
        return null as String?;
      }));
      examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "2").then((value) {
        for (var e in value) {
          outSemesters[
          semesterIndexMap[e.id.substring(1, 12)]!]
              .addExam(e);
        }
        return null as String?;
      }));
      yearEnroll++;
    }

    // 用于存储异步任务的Future List
    var fetches = <Future<String?>>[];
    fetches.add(Future.wait(semesterConfigFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    fetches.add(Future.wait(examFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    // 爬浙大钉API，查课表
    fetches.add(_appService.getTimetable(_httpClient).then((value) {
      for (var e in value) {
        outSemesters[semesterIndexMap[e.semesterId]!].addSession(e);
      }
      return null as String?;
    }).catchError((e) => e.toString()));

    // 爬教务网，查成绩
    fetches.add(
        _jwbInfoSys.getTranscript(_httpClient, _username).then((value) {
          for (var e in value) {
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
      return null as String?;
    }).catchError((e) => e.toString()));

    // 爬教务网，查主修成绩
    fetches.add(_jwbInfoSys.getMajorGrade(_httpClient, _username).then((value) {
      outMajorGrade.clear();
      outMajorGrade.addAll(value);
      return null as String?;
    }).catchError((e) => e.toString()));

    // 等所有请求完成后，去除没有任何信息的学期。
    return await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere(
          (e) => e.grades.isEmpty && e.sessions.isEmpty && e.exams.isEmpty);

      _lastUpdateTime = DateTime.now();
    });
  }
}
