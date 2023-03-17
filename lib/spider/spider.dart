import 'dart:convert';
import 'dart:io';

import '../data/grade.dart';
import '../data/semester.dart';
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

  String get cookie => _iPlanetDirectoryPro.toString();

  Spider(String username, String password) {
    _httpClient = HttpClient();
    _httpClient.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    _appService = AppService();
    _jwbInfoSys = JwbInfoSys();
    _username = username;
    _password = password;
  }

  Future<bool> init() async {
    _iPlanetDirectoryPro =
        await ZjuAm.getSsoCookie(_httpClient, _username, _password);
    await Future.wait([
      _appService.init(_httpClient, _iPlanetDirectoryPro!),
      _jwbInfoSys.init(_httpClient, _iPlanetDirectoryPro!),
    ]);
    return true;
  }

  Future<dynamic> getTranscript() async {
    // Group 1: 课程代码
    // Group 2: 课程名称
    // Group 3: 成绩
    // Group 4: 学分
    // Group 5: 绩点
    var transcript = await _jwbInfoSys
        .getTranscriptHtml(_httpClient, _username)
        .then((value) => RegExp(
                r'<td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>&nbsp;</td>')
            .allMatches(value)
            .map((e) => {
                  'code': e.group(1),
                  'name': e.group(2),
                  'grade': e.group(3),
                  'credit': e.group(4),
                  'gpa': e.group(5),
                })
            .toList());
    return transcript;
  }

  Future<List<double>> getMajorGrade() async {
    var html = await _jwbInfoSys.getMajorGradeHtml(_httpClient, _username);
    var majorGpa =
        RegExp(r'平均绩点=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00";
    var majorCredit =
        RegExp(r'总学分=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00";
    return [double.parse(majorGpa), double.parse(majorCredit)];
  }

  Future<List<bool>> getSemesterDetails(List<Semester> outSemesters, Map<String, List<Grade>> outGrades) async {
    List<Semester> semesters = [];

    // 从考试查询API获取课程信息
    List<Future> fetches = [];
    var yearNow = DateTime.now().year;
    var yearEnroll = int.parse(_username.substring(1, 3)) + 2000;
    var yearGraduate = yearEnroll + 7;

    Map<String, int> semesterMap = {};
    for (var i = 0; i < 8; i++) {
      semesterMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', i * 2)]);
      semesterMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', i * 2 + 1)]);
      semesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
      semesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
    }

    // 查课表
    fetches.add(_appService.getTimetableJson(_httpClient).then((value) =>
        jsonDecode(value
                .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
                .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          if (e['kcid'] != null) {
            semesters[semesterMap[(e['kcid'] as String).substring(1, 12)]!]
                .addSession(e);
          }
        })));

    // 查成绩
    fetches.add(_jwbInfoSys
        .getTranscriptHtml(_httpClient, _username)
        .then((value) =>
            RegExp(r'<td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>&nbsp;</td>')
                .allMatches(value)
                .forEach((e) {
              semesters[semesterMap[(e.group(1) as String).substring(1, 12)]!]
                  .addGrade(e);
              //体育课
              var key = (e.group(1) as String).substring(14, 22);
              if (key.startsWith('401')) {
                key = (e.group(1) as String).substring(0, 22);
              }
              outGrades.putIfAbsent(key, () => <Grade>[]).add(Grade(e));
            }))
        .whenComplete(() {
      for (var e in semesters) {
        e.calculateGPA();
      }
    }));

    // 查考试
    while (yearEnroll <= yearNow && yearEnroll <= yearGraduate) {
      var yearStr = '$yearEnroll-${yearEnroll + 1}';
      fetches
          .add(_appService.getExamJson(_httpClient, yearStr, "1").then((value) {
        jsonDecode(value
                .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
                .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          semesters[semesterMap[(e['xkkh'] as String).substring(1, 12)]!]
              .addExam(e);
        });
      }).whenComplete(() {
        for (var e in semesters) {
          e.sortExams();
        }
      }));
      fetches
          .add(_appService.getExamJson(_httpClient, yearStr, "2").then((value) {
        jsonDecode(value
                .replaceAll(RegExp(r'\((?=[\u4e00-\u9fa5])'), '（')
                .replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])\)'), '）'))
            .forEach((e) {
          semesters[semesterMap[(e['xkkh'] as String).substring(1, 12)]!]
              .addExam(e);
        });
      }).whenComplete(() {
        for (var e in semesters) {
          e.sortExams();
        }
      }));
      yearEnroll++;
    }
    await Future.wait(fetches);

    outSemesters = semesters
        .where((e) => (e.exams.isNotEmpty ||
            e.grades.isNotEmpty ||
            e.sessions.isNotEmpty))
        .toList();

    return [true];
  }
}
