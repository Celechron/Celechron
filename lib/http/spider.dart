import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/time_config_service.dart';

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
    await ZjuAm.getSsoCookie(_httpClient, _username, _password);
    return await Future.wait([
      _appService.login(_httpClient, _iPlanetDirectoryPro!),
      _jwbInfoSys.login(_httpClient, _iPlanetDirectoryPro!),
    ]).then((value) => value[0] && value[1]).catchError((e) => false);
  }

  void logout() {
    _username = "";
    _password = "";
    _iPlanetDirectoryPro = null;
    _appService.logout();
    _jwbInfoSys.logout();
  }

  Future<Iterable<List<String>>> getGrades() async {
    // Group 1: 课程代码
    // Group 2: 课程名称
    // Group 3: 成绩
    // Group 4: 学分
    // Group 5: 绩点
    return await _jwbInfoSys.getTranscriptHtml(_httpClient, _username).then(
            (value) =>
            RegExp(
                r'<td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>&nbsp;</td>')
                .allMatches(value)
                .map((e) =>
            [
              e.group(1)!,
              e.group(2)!,
              e.group(3)!,
              e.group(4)!,
              e.group(5)!
            ]));
  }

  Future<List<double>> getMajorGpaAndCredit() async {
    var html = await _jwbInfoSys.getMajorGradeHtml(_httpClient, _username);
    var majorGpa =
        RegExp(r'平均绩点=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00";
    var majorCredit =
        RegExp(r'总学分=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00";
    return [double.parse(majorGpa), double.parse(majorCredit)];
  }

  Future<List<bool>> getSemesterDetails(List<Semester> outSemesters,
      Map<String, List<Grade>> outGrades, List<double> outMajorGrade) async {
    // 从考试查询API获取课程信息
    List<Future> fetches = [];
    var yearNow = DateTime
        .now()
        .year;
    var yearEnroll = int.parse(_username.substring(1, 3)) + 2000;
    var yearGraduate = yearEnroll + 7;

    // 建立学期号与学期列表的映射，如"2022-2023-1"对应第22年入学同学的第0个学期，即"2022-2023秋冬"。
    Map<String, int> semesterIndexMap = <String, int>{};
    for (var i = 0; i < 8; i++) {
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', i * 2)]);
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', i * 2 + 1)]);
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
    }

    // 爬浙大钉API，查课表
    fetches.add(_appService.getTimetableJson(_httpClient).then((value) =>
        jsonDecode(value
            .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
            .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          if (e['kcid'] != null) {
            outSemesters[
            semesterIndexMap[(e['kcid'] as String).substring(1, 12)]!]
                .addSession(e);
          }
        })).catchError((e) => false));

    // 爬教务网，查成绩
    fetches.add(getGrades().then((value) {
      for (var e in value) {
        outSemesters[semesterIndexMap[e[0].substring(1, 12)]!].addGrade(e);
        //体育课
        var key = e[0].substring(14, 22);
        if (key.startsWith('401')) {
          key = e[0].substring(0, 22);
        }
        outGrades.putIfAbsent(key, () => <Grade>[]).add(Grade(e));
      }
      for (var e in outSemesters) {
        e.calculateGPA();
      }
      return true;
    }).catchError((e) => false));

    // 爬教务网，查主修成绩
    fetches.add(getMajorGpaAndCredit().then((value) {
      outMajorGrade.clear();
      outMajorGrade.addAll(value);
    }));

    // 考试、时间配置要分学期查，所以放在循环里
    while (yearEnroll <= yearNow && yearEnroll <= yearGraduate) {
      var yearStr = '$yearEnroll-${yearEnroll + 1}';
      fetches.add(TimeConfigService.getConfig(_httpClient, '$yearStr-1').then(
              (value) {
            if (value != null) {
              outSemesters[semesterIndexMap['$yearStr-1']!].addTimeInfo(jsonDecode(value));
            }
          }));
      fetches.add(TimeConfigService.getConfig(_httpClient, '$yearStr-2').then(
              (value) {
            if (value != null) {
              outSemesters[semesterIndexMap['$yearStr-2']!].addTimeInfo(jsonDecode(value));
            }
          }));
      fetches
          .add(_appService.getExamJson(_httpClient, yearStr, "1").then((value) {
        jsonDecode(value
            .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
            .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          outSemesters[
          semesterIndexMap[(e['xkkh'] as String).substring(1, 12)]!]
              .addExam(e);
        });
      }).whenComplete(() {
        for (var e in outSemesters) {
          e.sortExams();
        }
      }));
      fetches
          .add(_appService.getExamJson(_httpClient, yearStr, "2").then((value) {
        jsonDecode(value
            .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
            .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          outSemesters[
          semesterIndexMap[(e['xkkh'] as String).substring(1, 12)]!]
              .addExam(e);
        });
      }).whenComplete(() {
        for (var e in outSemesters) {
          e.sortExams();
        }
      }));
      yearEnroll++;
    }

    // 等所有请求完成后，去除没有任何信息的学期。
    await Future.wait(fetches);
    outSemesters.removeWhere(
            (e) => e.grades.isEmpty && e.sessions.isEmpty && e.exams.isEmpty);

    return [true];
  }
}
