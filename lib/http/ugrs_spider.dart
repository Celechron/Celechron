import 'dart:convert';
import 'dart:io';
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/model/todo.dart';
import 'package:get/get.dart';

import 'package:celechron/http/spider.dart';
import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';

// import 'zjuServices/appservice.dart';
import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';

class UgrsSpider implements Spider {
  late HttpClient _httpClient;
  late String _username;
  late String _password;
  // late AppService _appService;
  late Courses _courses;
  late Zdbk _zdbk;
  late GrsNew _grsNew;
  late TimeConfigService _timeConfigService;
  Cookie? _iPlanetDirectoryPro;
  DateTime _lastUpdateTime = DateTime(0);
  bool fetchGrs = false;
  Map<String, double>? _practiceScores;
  bool _isPracticeScoresGet = false; // 是否成功获取到二三四课堂分数

  UgrsSpider(String username, String password) {
    _httpClient = HttpClient();
    _httpClient.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    // _appService = AppService(db: _db);
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
    loginErrorMessages.addAll(await Future.wait(
        // 本科生需要登录钉钉工作台、教务网、研究生院网（为了看研究生课）
        [
          /*_appService
              .login(_httpClient, _iPlanetDirectoryPro)
              // ignore: unnecessary_cast
              .then((value) => null as String?)
              .timeout(const Duration(seconds: 8))
              .catchError((e) => "无法登录钉钉工作台，$e"),*/
          _courses
              .login(_httpClient, _iPlanetDirectoryPro)
              // ignore: unnecessary_cast
              .then((value) => null as String?)
              .timeout(const Duration(seconds: 8))
              .catchError((e) => "无法登录学在浙大，$e"),
          _zdbk
              .login(_httpClient, _iPlanetDirectoryPro)
              // ignore: unnecessary_cast
              .then((value) => null as String?)
              .timeout(const Duration(seconds: 8))
              .catchError((e) => "无法登录教务网，$e"),
          _grsNew
              .login(_httpClient, _iPlanetDirectoryPro)
              .then((value) {
                fetchGrs = true;
                // ignore: unnecessary_cast
                return null as String?;
              })
              .timeout(const Duration(seconds: 8))
              // 本科生一般不需要登录研究生院，所以不管登录成功与否都不会报错
              // ignore: unnecessary_cast
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
    _practiceScores = null;
    _isPracticeScoresGet = false;
  }

  Map<String, double>? get practiceScores => _practiceScores;
  bool get isPracticeScoresGet => _isPracticeScoresGet;

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
    // 请求顺序
    var fetches = <Future<String?>>[];
    List<String> fetchSequence = ['校历', '课表', '考试', '成绩', '主修', '作业', '实践'];

    // 返回值初始化
    var outSemesters = <Semester>[];
    var outGrades = <Grade>[];
    var outMajorGrade = <double>[];
    var outSpecialDates = <DateTime, String>{};
    var outTodos = <Todo>[];
    var loginErrorMessages = <String?>[null, null, null];
    // 暂存主修课程ID集合，待所有请求完成后再打标记
    var majorCourseIds = <String>{};

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
    // 查课表
    var timetableFetches = <Future<String?>>[];
    var cancelTimetableFetch = false;

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

      // 本科生课
      // 顺序获取课表
      for (var season in ['1|秋', '1|冬', '2|春', '2|夏']) {
        if (cancelTimetableFetch) {
          timetableFetches.add(Future.value("已取消"));
          continue;
        }
        try {
          var value = await _zdbk.getTimetable(_httpClient, yearStr, season);
          var semKey = season.startsWith('1') ? '$yearStr-1' : '$yearStr-2';
          for (var e in value.item2) {
            outSemesters[semesterIndexMap[semKey]!].addSession(e, semKey);
          }
          timetableFetches.add(Future.value(value.item1?.toString()));
          if (value.item1.toString().contains("验证码")) {
            cancelTimetableFetch = true;
          }
        } catch (e) {
          timetableFetches.add(Future.value(e.toString()));
        }
      }

      // 研究生课与考试
      if (fetchGrs) {
        timetableFetches.add(
            _grsNew.getTimetable(_httpClient, yearEnroll, 13).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-1']!]
                .addSession(e, '$yearStr-1');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
        timetableFetches.add(
            _grsNew.getTimetable(_httpClient, yearEnroll, 14).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-1']!]
                .addSession(e, '$yearStr-1');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
        timetableFetches.add(
            _grsNew.getTimetable(_httpClient, yearEnroll, 11).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-2']!]
                .addSession(e, '$yearStr-2');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
        timetableFetches.add(
            _grsNew.getTimetable(_httpClient, yearEnroll, 12).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-2']!]
                .addSession(e, '$yearStr-2');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
        // 研究生课的【考试】
        timetableFetches
            .add(_grsNew.getExamsDto(_httpClient, yearEnroll, 12).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-1']!]
                .addExamWithSemester(e, '$yearStr-1');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
        timetableFetches
            .add(_grsNew.getExamsDto(_httpClient, yearEnroll, 11).then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$yearStr-2']!]
                .addExamWithSemester(e, '$yearStr-2');
          }
          return value.item1?.toString();
        }).catchError((e) => e.toString()));
      }
      yearEnroll++;
    }

    // 配置
    fetches.add(Future.wait(semesterConfigFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    // 课表
    fetches.add(Future.wait(timetableFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    // 考试
    fetches.add(_zdbk.getExamsDto(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
      }
      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // 成绩
    fetches.add(_zdbk.getTranscript(_httpClient).then((value) {
      for (var e in value.item2) {
        outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addGrade(e);
        outGrades.add(e);
      }
      for (var e in outSemesters) {
        e.calculateGPA();
      }
      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // 主修
    fetches.add(_zdbk.getMajorGrade(_httpClient).then((value) {
      outMajorGrade.clear();
      outMajorGrade.addAll(value.item2.item1);

      // 获取主修课程的课程号列表并暂存
      var transcriptJson = RegExp('(?<="items":)\\[(.*?)\\](?=,"limit")')
              .firstMatch(value.item2.item2)
              ?.group(0) ??
          '[]';
      majorCourseIds = (jsonDecode(transcriptJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) => e['xkkh'] as String)
          .toSet();

      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // 作业（学在浙大）
    fetches.add(_courses.getTodo(_httpClient).then((value) {
      outTodos.clear();
      outTodos.addAll(value.item2);
      return value.item1?.toString();
    }).catchError((e) => e.toString()));

    // 实践学分（第二三四课堂）- 使用zdbk获取
    fetches.add(_zdbk.getPracticeScores(_httpClient, _username).then((value) {
      // 只有当没有错误时，才设置为 true
      if (value.item1 == null) {
        _practiceScores = value.item2;
        _isPracticeScoresGet = true;
      } else {
        _practiceScores = value.item2;
        _isPracticeScoresGet = false;
      }
      return value.item1?.toString();
    }).catchError((e) {
      _isPracticeScoresGet = false;
      return e.toString();
    }));

    // 等待所有请求完成。然后，删除不包含考试、成绩、课程的全空学期
    var fetchErrorMessages = await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere((e) =>
          e.grades.isEmpty &&
          e.sessions.isEmpty &&
          e.exams.isEmpty &&
          e.courses.isEmpty);

      // 所有请求完成后，统一给主修课程打标记
      for (var grade in outGrades) {
        if (majorCourseIds.contains(grade.id)) {
          grade.major = true;
        }
      }
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

    return Tuple7(loginErrorMessages, fetchErrorMessages, outSemesters,
        outGrades, outMajorGrade, outSpecialDates, outTodos);
  }
}

class MockSpider extends UgrsSpider {
  MockSpider() : super('3200000000', '');

  @override
  Future<List<String?>> login() async {
    await Future.delayed(const Duration(seconds: 4));
    return [null, null];
  }

  @override
  void logout() {}

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
    await Future.delayed(const Duration(seconds: 2));
    return Tuple7(
        [null, null],
        [null, null, null, null, null, null],
        [
          Semester.fromJson(jsonDecode(
              '{"name":"2024-2025春夏","courses":{"(2024-2025-2)-211G0280-0099160-1":{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},"teacher":"纪守领","sessions":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":false,"day":4,"time":[2,3],"location":"紫金港东1A-401(录播)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":4,"time":[1,2,3],"location":"紫金港机房","grsClass":null}],"exams":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","type":1,"time":["2021-01-20T15:30:00.000","2021-01-20T17:30:00.000"],"location":"紫金港机房","seat":null}]},"(2024-2025-2)-051F0020-0098350-2":{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","credit":3.0,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},"teacher":"符亦文","sessions":[{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[3,4],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[9,10],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","type":1,"time":["2021-01-21T10:30:00.000","2021-01-21T12:30:00.000"],"location":"紫金港西2-105(录播)","seat":"85"}]},"(2024-2025-2)-551E0020-0009771-1":{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","credit":3.0,"original":"92","fivePoint":4.8,"fourPoint":4.2,"fourPointLegacy":4.0,"hundredPoint":92,"gpaIncluded":true,"creditIncluded":true},"teacher":"甘均先","sessions":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","teacher":"甘均先","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[6,7,8],"location":"紫金港东1B-302(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","type":1,"time":["2021-01-21T14:00:00.000","2021-01-21T16:00:00.000"],"location":"紫金港西1-211(录播)","seat":"81"}]},"(2024-2025-2)-821T0150-0082403-1":{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","confirmed":true,"credit":5.0,"grade":{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","credit":5.0,"original":"83","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":83,"gpaIncluded":true,"creditIncluded":true},"teacher":"金显","sessions":[{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[9],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[1,2],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[3,4,5],"location":"紫金港东2-201(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":0,"time":["2020-11-16T14:00:00.000","2020-11-16T16:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"48"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":1,"time":["2021-01-22T08:00:00.000","2021-01-22T10:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"69"}]},"(2024-2025-2)-081C0130-0094011-2":{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","confirmed":true,"credit":2.5,"grade":{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","credit":2.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},"teacher":"费少梅","sessions":[{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","teacher":"费少梅","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":4,"time":[3,4,5],"location":"紫金港东1B-214(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","type":1,"time":["2021-01-25T10:30:00.000","2021-01-25T12:30:00.000"],"location":"紫金港西1-317(录播)*","seat":"26"}]},"(2024-2025-2)-551E0010-0014323-4":{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},"teacher":"姚明明","sessions":[{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","teacher":"姚明明","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[1,2],"location":"紫金港东1B-302(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","type":1,"time":["2021-01-25T14:00:00.000","2021-01-25T16:00:00.000"],"location":"紫金港东1A-505(录播研)","seat":"72"}]},"(2024-2025-2)-821T0190-0086207-1":{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","confirmed":true,"credit":3.5,"grade":{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","credit":3.5,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},"teacher":"汪国军","sessions":[{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[9],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[3,4,5],"location":"紫金港东2-202(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":0,"time":["2020-11-18T14:00:00.000","2020-11-18T16:00:00.000"],"location":"紫金港西2-104(录播)","seat":"58"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":1,"time":["2021-01-26T08:00:00.000","2021-01-26T10:00:00.000"],"location":"紫金港西2-104(录播)","seat":"3"}]},"(2024-2025-2)-0113N001-0086337-1":{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","confirmed":true,"credit":1.5,"grade":{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","credit":1.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},"teacher":"朱柏铭","sessions":[{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","teacher":"朱柏铭","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":3,"time":[6,7,8],"location":"紫金港东1B-206(录播)#","grsClass":null}],"exams":[]},"(2024-2025-2)-371E0010-0008303-2":{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","confirmed":true,"credit":1.0,"grade":null,"teacher":"项淑芳/吴维东","sessions":[{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","teacher":"项淑芳/吴维东","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":7,"time":[11,12],"location":"紫金港东1B-210(录播.4)#","grsClass":null}],"exams":[]},"(2024-2025-2)-40103200-0087355-1":{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","confirmed":true,"credit":1.0,"grade":{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","credit":1.0,"original":"91","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":91,"gpaIncluded":true,"creditIncluded":true},"teacher":"董育平","sessions":[{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[6,7],"location":"紫金港田径场（东）","grsClass":null}],"exams":[]},"(2024-2025-2)-41100001-0087355-2":{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","confirmed":true,"credit":0.0,"grade":null,"teacher":"董育平","sessions":[{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[10],"location":"紫金港东田径场","grsClass":null}],"exams":[]},"(2024-2025-2)-8517N001-0082046-3":{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","confirmed":true,"credit":1.5,"grade":{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","credit":1.5,"original":"97","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":97,"gpaIncluded":true,"creditIncluded":true},"teacher":"金心宇/史笑兴","sessions":[{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","teacher":"金心宇/史笑兴","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":4,"time":[9,10,11,12,13],"location":"紫金港东4-418","grsClass":null}],"exams":[]}},"exams":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","type":1,"time":["2021-01-20T15:30:00.000","2021-01-20T17:30:00.000"],"location":"紫金港机房","seat":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","type":1,"time":["2021-01-21T10:30:00.000","2021-01-21T12:30:00.000"],"location":"紫金港西2-105(录播)","seat":"85"},{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","type":1,"time":["2021-01-21T14:00:00.000","2021-01-21T16:00:00.000"],"location":"紫金港西1-211(录播)","seat":"81"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":0,"time":["2020-11-16T14:00:00.000","2020-11-16T16:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"48"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":1,"time":["2021-01-22T08:00:00.000","2021-01-22T10:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"69"},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","type":1,"time":["2021-01-25T10:30:00.000","2021-01-25T12:30:00.000"],"location":"紫金港西1-317(录播)*","seat":"26"},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","type":1,"time":["2021-01-25T14:00:00.000","2021-01-25T16:00:00.000"],"location":"紫金港东1A-505(录播研)","seat":"72"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":0,"time":["2020-11-18T14:00:00.000","2020-11-18T16:00:00.000"],"location":"紫金港西2-104(录播)","seat":"58"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":1,"time":["2021-01-26T08:00:00.000","2021-01-26T10:00:00.000"],"location":"紫金港西2-104(录播)","seat":"3"}],"sessions":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","teacher":"甘均先","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[6,7,8],"location":"紫金港东1B-302(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[9],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[1,2],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[3,4],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[9],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[10],"location":"紫金港东田径场","grsClass":null},{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[6,7],"location":"紫金港田径场（东）","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[3,4,5],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","teacher":"朱柏铭","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":3,"time":[6,7,8],"location":"紫金港东1B-206(录播)#","grsClass":null},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","teacher":"姚明明","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[1,2],"location":"紫金港东1B-302(录播)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[9,10],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[3,4,5],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":false,"day":4,"time":[2,3],"location":"紫金港东1A-401(录播)","grsClass":null},{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","teacher":"金心宇/史笑兴","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":4,"time":[9,10,11,12,13],"location":"紫金港东4-418","grsClass":null},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","teacher":"费少梅","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":4,"time":[3,4,5],"location":"紫金港东1B-214(录播.4)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":4,"time":[1,2,3],"location":"紫金港机房","grsClass":null},{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","teacher":"项淑芳/吴维东","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":7,"time":[11,12],"location":"紫金港东1B-210(录播.4)#","grsClass":null}],"grades":[{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","credit":1.5,"original":"97","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":97,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","credit":3.0,"original":"92","fivePoint":4.8,"fourPoint":4.2,"fourPointLegacy":4.0,"hundredPoint":92,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","credit":1.0,"original":"91","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":91,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","credit":3.5,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","credit":3.0,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","credit":2.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","credit":1.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","credit":5.0,"original":"83","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":83,"gpaIncluded":true,"creditIncluded":true}],"gpa":[4.472222222222222,4.1000000000000005,3.9666666666666663,89.72222222222223],"credits":27.0,"sessionToTime":[[0,0],[480,525],[530,575],[600,645],[650,695],[700,745],[805,850],[855,900],[905,950],[975,1020],[1025,1070],[1130,1175],[1180,1225],[1230,1275],[1280,1325]],"dayOfWeekToDays":[[[[],["2024-02-26T00:00:00.000","2024-03-11T00:00:00.000","2024-03-25T00:00:00.000","2024-04-08T00:00:00.000"],["2024-02-27T00:00:00.000","2024-03-12T00:00:00.000","2024-03-26T00:00:00.000","2024-04-09T00:00:00.000"],["2024-02-28T00:00:00.000","2024-03-13T00:00:00.000","2024-03-27T00:00:00.000","2024-04-10T00:00:00.000"],["2024-02-29T00:00:00.000","2024-03-14T00:00:00.000","2024-03-28T00:00:00.000","2024-04-11T00:00:00.000"],["2024-03-01T00:00:00.000","2024-03-15T00:00:00.000","2024-03-29T00:00:00.000","2024-04-12T00:00:00.000"],["2024-03-02T00:00:00.000","2024-03-16T00:00:00.000","2024-03-30T00:00:00.000","2024-04-13T00:00:00.000"],["2024-03-03T00:00:00.000","2024-03-17T00:00:00.000","2024-03-31T00:00:00.000","2024-04-14T00:00:00.000"]],[[],["2024-03-04T00:00:00.000","2024-03-18T00:00:00.000","2024-04-01T00:00:00.000","2024-04-15T00:00:00.000"],["2024-03-05T00:00:00.000","2024-03-19T00:00:00.000","2024-04-02T00:00:00.000","2024-04-16T00:00:00.000"],["2024-03-06T00:00:00.000","2024-03-20T00:00:00.000","2024-04-03T00:00:00.000","2024-04-17T00:00:00.000"],["2024-03-07T00:00:00.000","2024-03-21T00:00:00.000","2024-04-04T00:00:00.000","2024-04-18T00:00:00.000"],["2024-03-08T00:00:00.000","2024-03-22T00:00:00.000","2024-04-07T00:00:00.000","2024-04-19T00:00:00.000"],["2024-03-09T00:00:00.000","2024-03-23T00:00:00.000","2024-04-06T00:00:00.000","2024-04-20T00:00:00.000"],["2024-03-10T00:00:00.000","2024-03-24T00:00:00.000","2024-04-07T00:00:00.000","2024-04-21T00:00:00.000"]]],[[[],["2024-04-22T00:00:00.000","2024-05-06T00:00:00.000","2024-05-20T00:00:00.000","2024-06-03T00:00:00.000"],["2024-04-23T00:00:00.000","2024-05-07T00:00:00.000","2024-05-21T00:00:00.000","2024-06-04T00:00:00.000"],["2024-04-24T00:00:00.000","2024-05-08T00:00:00.000","2024-05-22T00:00:00.000","2024-06-05T00:00:00.000"],["2024-04-25T00:00:00.000","2024-05-09T00:00:00.000","2024-05-23T00:00:00.000","2024-06-06T00:00:00.000"],["2024-04-26T00:00:00.000","2024-05-10T00:00:00.000","2024-05-24T00:00:00.000","2024-06-07T00:00:00.000"],["2024-04-27T00:00:00.000","2024-05-11T00:00:00.000","2024-05-25T00:00:00.000","2024-06-08T00:00:00.000"],["2024-04-28T00:00:00.000","2024-05-12T00:00:00.000","2024-05-26T00:00:00.000","2024-06-09T00:00:00.000"]],[[],["2024-04-29T00:00:00.000","2024-05-13T00:00:00.000","2024-05-27T00:00:00.000","2024-06-10T00:00:00.000"],["2024-04-30T00:00:00.000","2024-05-14T00:00:00.000","2024-05-28T00:00:00.000","2024-06-11T00:00:00.000"],["2024-05-01T00:00:00.000","2024-05-15T00:00:00.000","2024-05-29T00:00:00.000","2024-06-12T00:00:00.000"],["2024-05-11T00:00:00.000","2024-05-16T00:00:00.000","2024-05-30T00:00:00.000","2024-06-13T00:00:00.000"],["2024-06-17T00:00:00.000","2024-05-17T00:00:00.000","2024-05-31T00:00:00.000","2024-06-14T00:00:00.000"],["2024-05-04T00:00:00.000","2024-05-18T00:00:00.000","2024-06-01T00:00:00.000","2024-06-15T00:00:00.000"],["2024-05-05T00:00:00.000","2024-05-19T00:00:00.000","2024-06-02T00:00:00.000","2024-06-16T00:00:00.000"]]]],"holidays":{"2024-04-04T00:00:00.000":"清明节","2024-05-01T00:00:00.000":"劳动节","2024-06-10T00:00:00.000":"端午节"},"exchanges":{"2024-04-05T00:00:00.000":"2024-04-07T00:00:00.000","2024-05-02T00:00:00.000":"2024-05-11T00:00:00.000","2024-05-03T00:00:00.000":"2024-06-17T00:00:00.000"}}'))
        ],
        (jsonDecode('[ { "id": "(2024-2025-2)-821T0150-0082403-1", "name": "微积分（甲）Ⅰ", "credit": 5.0, "original": "83", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 83, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-821T0150-0082403-1", "name": "微积分（甲）Ⅰ", "credit": 5.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-081C0130-0094011-2", "name": "工程图学", "credit": 2.5, "original": "85", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 85, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-081C0131-0094011-2", "name": "工程图学", "credit": 2.5, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-0113N001-0086337-1", "name": "公共经济分析导论", "credit": 1.5, "original": "85", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 85, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-821T0190-0086207-1", "name": "线性代数（甲）", "credit": 3.5, "original": "90", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 90, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-051F0020-0098350-2", "name": "大学英语Ⅲ", "credit": 3.0, "original": "90", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 90, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-40103200-0087355-1", "name": "无线电测向（初级班）", "credit": 1.0, "original": "91", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 91, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-551E0020-0009771-1", "name": "中国近现代史纲要", "credit": 3.0, "original": "92", "fivePoint": 4.8, "fourPoint": 4.2, "fourPointLegacy": 4.0, "hundredPoint": 92, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-551E0010-0014323-4", "name": "思想道德修养与法律基础", "credit": 3.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-211G0280-0099160-1", "name": "C程序设计基础", "credit": 3.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-8517N001-0082046-3", "name": "无线网络应用", "credit": 1.5, "original": "97", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 97, "gpaIncluded": true, "creditIncluded": true } ]')
                as List)
            .map((e) => Grade.fromJson(e))
            .toList(),
        [4.631297709923665, 131.0],
        {},
        Todo.getAllFromCourses((jsonDecode(
            '{"todo_list":[{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T06:00:00Z","id":908844,"is_locked":false,"is_student":true,"prerequisites":[],"title":"Project-资料","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T04:50:00Z","id":924799,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验四","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T04:53:00Z","id":924802,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业三","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:13:00Z","id":929150,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验五","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:18:00Z","id":929152,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验六","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:20:00Z","id":929153,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业四","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:21:00Z","id":929154,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业五","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T11:50:00Z","id":933292,"is_locked":false,"is_student":true,"prerequisites":[],"title":"期末project-提交通道","type":"homework"},{"course_code":"(2024-2025-1)-21192040-0001038-1A","course_id":74535,"course_name":"量子计算理论基础与软件系统","course_type":1,"end_time":"2025-01-09T15:59:00Z","id":928371,"is_locked":false,"is_student":true,"prerequisites":[],"title":"期末大作业","type":"homework"},{"course_code":"(2024-2025-1)-21121500-0003412-1","course_id":78036,"course_name":"优化基本理论与方法","course_type":1,"end_time":"2025-01-18T15:59:00Z","id":932896,"is_locked":false,"is_student":true,"prerequisites":[],"title":"Final Report","type":"homework"}]}'))));
  }
}
