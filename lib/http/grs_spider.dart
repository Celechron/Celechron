import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/spider.dart';
import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';
import 'package:get/get.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
// import 'zjuServices/appservice.dart';
import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';

class GrsSpider implements Spider {
  late HttpClient _httpClient;
  late String _username;
  late String _password;
  // late AppService _appService;
  late Zdbk _zdbk;
  late GrsNew _grsNew;
  late Courses _courses;
  late TimeConfigService _timeConfigService;
  Cookie? _iPlanetDirectoryPro;
  DateTime _lastUpdateTime = DateTime(0);
  static List<String> fetchSequenceGrs = [
    '配置',
    '课表',
    '本科生课考试',
    '本科生课成绩',
    '研究生课考试',
    '研究生课成绩',
    '作业'
  ];

  GrsSpider(String username, String password) {
    _httpClient = HttpClient();
    _httpClient.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    // _appService = AppService();
    _courses = Courses();
    _zdbk = Zdbk();
    _grsNew = GrsNew();
    _timeConfigService = TimeConfigService();
    _username = username;
    _password = password;
  }

  @override
  set db(DatabaseHelper? db) {
    // _appService.db = db;
    _courses.db = db;
    _zdbk.db = db;
    _grsNew.db = db;
    _timeConfigService.db = db;
  }

  @override
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
      _grsNew
          .login(_httpClient, _iPlanetDirectoryPro)
          // ignore: unnecessary_cast
          .then((value) => null as String?)
          .timeout(const Duration(seconds: 8))
          .catchError((e) => "无法登录研究生院网，$e"),
      _courses
          .login(_httpClient, _iPlanetDirectoryPro)
          // ignore: unnecessary_cast
          .then((value) => null as String?)
          .timeout(const Duration(seconds: 8))
          .catchError((e) => "无法登录学在浙大，$e"),
      /* _appService
                    .login(_httpClient, _iPlanetDirectoryPro)
                    // ignore: unnecessary_cast
                    .then((value) => null as String?)
                    .timeout(const Duration(seconds: 8))
                    .catchError((e) => "无法登录钉钉工作台，$e"), */
      _zdbk
          .login(_httpClient, _iPlanetDirectoryPro)
          // ignore: unnecessary_cast
          .then((value) => null as String?)
          .timeout(const Duration(seconds: 8))
          // 研究生一般不需要登录zdbk，成功与否都不报错
          .catchError((e) => null as String?),
    ]).then((value) {
      if (value.every((e) => e == null)) _lastUpdateTime = DateTime.now();
      return value;
    }));
    return loginErrorMessages;
  }

  @override
  void logout() {
    _username = "";
    _password = "";
    _iPlanetDirectoryPro = null;
    // _appService.logout();
    _zdbk.logout();
    _grsNew.logout();
  }

  // 返回一堆错误信息，如果有的话。看看返回的List是不是空的就知道刷新是否成功。
  @override
  Future<
      Tuple7<
          List<String?>,
          List<String?>,
          List<Semester>,
          List<Grade>,
          List<double>,
          Map<DateTime, String>,
          List<Todo>>> getEverything() async {
    // 返回值初始化
    var outSemesters = <Semester>[];
    var outGrades = <Grade>[];
    var outMajorGrade = <double>[];
    var outSpecialDates = <DateTime, String>{};
    var outTodos = <Todo>[];
    var loginErrorMessages = <String?>[null, null, null];

    // 如果Cookie过期了，就重新登录
    if (DateTime.now().difference(_lastUpdateTime).inMinutes > 15) {
      loginErrorMessages = await login();
    }

    // 建立学期编号与“入学以来第几个学期”的映射。如"2022-2023-1"对应第22年入学同学的第1个学期，即"2022-2023秋冬"。
    var yearNow = DateTime.now().year;
    var yearEnroll = int.parse(_username.substring(1, 3)) + 2000;
    // 假设研究生在本科时提前两年选了研究生的课
    yearEnroll -= 2;
    // 岩壁加起来7年+本科2年
    var yearGraduate = yearEnroll + 9;
    Map<String, int> semesterIndexMap = <String, int>{};
    for (var i = 9, j = 0; i >= 0; i--, j++) {
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', j * 2)]);
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', j * 2 + 1)]);
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
    }

    // 查校历（存在CDN上，JSON格式的，内含学期起止日期、单日时间表、放假调休等信息）
    var semesterConfigFetches = <Future<String?>>[];
    // 查课表
    var timetableFetches = <Future<String?>>[];
    var cancelTimetableFetch = false;
    // 查考试（暂时只有研究生使用，本科生是一下子拿完所有的）
    var examFetches = <Future<String?>>[];

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
      }).catchError((e) => 'semesterConf($yearStr-1) $e'));
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
      }).catchError((e) => 'semesterConf($yearStr-2) $e'));

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

      // 本科生课
      Future<String?> handleTimetable(season) async {
        if (cancelTimetableFetch) {
          return Future.value("已取消");
        }
        try {
          var value = await _zdbk.getTimetable(_httpClient, yearStr, season);
          var semKey = season.startsWith('1') ? '$yearStr-1' : '$yearStr-2';
          var sessions = value.item2.toList();
          sessions.sort((a, b) {
            if (a.dayOfWeek != b.dayOfWeek) {
              return a.dayOfWeek.compareTo(b.dayOfWeek);
            } else {
              return a.time.first.compareTo(b.time.first);
            }
          });
          for (var e in sessions) {
            outSemesters[semesterIndexMap[semKey]!].addSession(e, semKey);
          }
          if (value.item1.toString().contains("验证码")) {
            cancelTimetableFetch = true;
          }
          return Future.value(value.item1?.toString());
        } catch (e) {
          return Future.value(e.toString());
        }
      }

      for (var season in ['1|秋', '1|冬', '2|春', '2|夏']) {
        if (timetableFetches.isEmpty) {
          timetableFetches.add(handleTimetable(season));
        } else {
          timetableFetches.first = timetableFetches.first.then((_) {
            return handleTimetable(season);
          });
        }
      }

      // 研究生课
      timetableFetches
          .add(_grsNew.getTimetable(_httpClient, yearEnroll, 13).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1', true);
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsNew($yearStr-1, 13) $e'));
      timetableFetches
          .add(_grsNew.getTimetable(_httpClient, yearEnroll, 14).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1', true);
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsNew($yearStr-1, 14) $e'));
      timetableFetches
          .add(_grsNew.getTimetable(_httpClient, yearEnroll, 11).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2', true);
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsNew($yearStr-2, 11) $e'));
      timetableFetches
          .add(_grsNew.getTimetable(_httpClient, yearEnroll, 12).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2', true);
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsNew($yearStr-2, 12) $e'));

      // 研究生课考试
      examFetches
          .add(_grsNew.getExamsDto(_httpClient, yearEnroll, 12).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addExamWithSemester(e, '$yearStr-1');
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsExam($yearStr-1) $e'));
      examFetches
          .add(_grsNew.getExamsDto(_httpClient, yearEnroll, 11).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addExamWithSemester(e, '$yearStr-2');
        }
        return value.item1?.toString();
      }).catchError((e) => 'grsExam($yearStr-2) $e'));
      yearEnroll++;
    }

    // 把 五个任务分别加入 请求列表 。
    var fetches = <Future<String?>>[];
    // 配置
    fetches.add(Future.wait(semesterConfigFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    // 课表
    fetches.add(Future.wait(timetableFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

    // 本科生课考试
    fetches.add(_zdbk.getExamsDto(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
      }
      return value.item1?.toString();
    }).catchError((e) => 'zdbkExam $e'));

    // 查成绩
    fetches.add(_zdbk.getTranscript(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addGrade(e);
        outGrades.add(e);
      }
      return value.item1?.toString();
    }).catchError((e) => 'zdbkGrade $e'));

    // 研究生课考试
    fetches.add(Future.wait(examFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

    // 研究生课成绩
    fetches.add(_grsNew.getGrade(_httpClient).then((value) {
      for (var e in value.item2) {
        if (e.id.length < 6) {
          continue;
        }
        int year = int.tryParse(e.id.substring(0, 4)) ?? 0;
        String semesterStr = "";
        if (e.id.contains("春学") ||
            e.id.contains("夏学") ||
            e.id.contains("春夏学")) {
          semesterStr = "-2";
        } else if (e.id.contains("秋学") ||
            e.id.contains("冬学") ||
            e.id.contains("秋冬学")) {
          semesterStr = "-1";
        } else {
          continue;
        }
        String yearStr = '$year-${year + 1}$semesterStr';
        e.id = RegExp(r'班级编号(\d{7})').firstMatch(e.id)!.group(1)!;
        outSemesters[semesterIndexMap[yearStr]!]
            .addGradeWithSemester(e, yearStr, true);
      }
      return value.item1?.toString();
    }).catchError((e) => 'grsGrade $e'));

    // 学在浙大
    fetches.add(_courses.getTodo(_httpClient).then((value) {
      outTodos.clear();
      outTodos.addAll(value.item2);
      return value.item1?.toString();
    }).catchError((e) => 'coursesTodo $e'));

    // await一下，等待所有请求完成。然后，删除不包含考试、成绩、课程的空学期
    var fetchErrorMessages = await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere((e) =>
          e.grades.isEmpty &&
          e.sessions.isEmpty &&
          e.exams.isEmpty &&
          e.courses.isEmpty);
    });

    // 检查是否有查询失败的情况
    if (fetchErrorMessages.every((e) => e == null)) {
      _lastUpdateTime = DateTime.now();
    }
    for (var i = 0; i < fetchErrorMessages.length; i++) {
      if (fetchErrorMessages[i] != null) {
        fetchErrorMessages[i] =
            '${fetchSequenceGrs[i]}查询出错：${fetchErrorMessages[i]}';
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

    return Tuple7(loginErrorMessages, fetchErrorMessages, outSemesters,
        outGrades, outMajorGrade, outSpecialDates, outTodos);
  }
}
