import 'package:celechron/utils/json_utils.dart';

class Session {
  String? id;
  late String name;
  late String teacher;
  String? teacherId; // GRS teacher ID for detail API calls
  String? location;
  bool confirmed;
  int dayOfWeek;
  late List<int> time;

  // firstHalf : 秋/春 需要上课
  // secondHalf: 夏/冬 需要上课
  // 举例：秋冬学期的课程，firstHalf为true，secondHalf也为true
  bool firstHalf = false;
  bool secondHalf = false;

  // oddWeek:  单周 需要上课
  // evenWeek: 双周 需要上课
  // 举例：单双周的课程，oddWeek为true，evenWeek也为true
  bool oddWeek;
  bool evenWeek;

  // 自定义单双周。目前仅在研究生课程中出现。
  bool customRepeat = false;
  List<int> customRepeatWeeks = [];

  // GRS course metadata (used when creating Course)
  double? credit;
  bool? online;
  String? type;

  String get semesterId => id!.substring(1, 12);
  bool get showOnTimetable => !customRepeat || customRepeatWeeks.length >= 3;

  static const String dayMap = '零一二三四五六日';

  Session.empty()
      : confirmed = true,
        oddWeek = false,
        evenWeek = false,
        dayOfWeek = 1;

  /*Session.fromAppService(Map<String, dynamic> json)
      : id = RegExp(r'(.*?-){5}\d+(?=.*\d{10})')
            .firstMatch(json['kcid'] as String)!
            .group(0)!,
        name = json['mc'],
        teacher = json['jsxm'],
        confirmed = (json['sfqd'] as int) == 1,
        dayOfWeek = json['xqj'],
        oddWeek = !json['zcxx'].contains("双"),
        evenWeek = !json['zcxx'].contains("单"),
        time = (json['jc'] as List<dynamic>).map((e) => int.parse(e)).toList(),
        location = json['skdd'] {
    if (json.containsKey('xq')) {
      var semester = json['xq'] as String;
      firstHalf = semester.contains("秋") || semester.contains("春");
      secondHalf = semester.contains("冬") || semester.contains("夏");
    }
  }*/

  factory Session.fromZdbk(Map<String, dynamic> json) {
    // kcb 将课程名、教学班、教师和地点编码在 HTML 换行块中；
    // xxq 表示半学期，djj/skcd 分别提供起始节次和连续节数。
    final session = Session.empty()
      ..confirmed = asString(json['sfqd']) == '1'
      ..dayOfWeek = asInt(json['xqj']) ?? 1
      ..oddWeek = asString(json['dsz']) != '1'
      ..evenWeek = asString(json['dsz']) != '0'
      ..name = '未知课程'
      ..teacher = '未知教师'
      ..time = <int>[];
    //名称、教师、地点
    final courseBlock = asString(json['kcb']);
    if (courseBlock != null) {
      var nameTeacherPosition = RegExp(r'(.*?)<br>(.*?)<br>(.*?)<br>(.*?)zwf')
          .firstMatch(courseBlock);
      if (nameTeacherPosition != null) {
        // ZDBK上，课程名称中的括号有时会变成英文括号，此处统一改成中文括号
        session.name = nameTeacherPosition
            .group(1)!
            .replaceAll('(', '（')
            .replaceAll(')', '）');
        session.teacher = nameTeacherPosition.group(3) ?? '未知教师';
        session.location = nameTeacherPosition.group(4) == ''
            ? null
            : nameTeacherPosition.group(4);
      }
    }
    // 短学期 or 长学期
    final semester = asString(json['xxq']);
    if (semester != null) {
      session.firstHalf = semester.contains("秋") || semester.contains("春");
      session.secondHalf = semester.contains("冬") || semester.contains("夏");
    }
    // 第几节
    final initial = asInt(json['djj']);
    final duration = asInt(json['skcd']);
    if (initial != null && duration != null && duration > 0) {
      session.time =
          List<int>.generate(duration, (index) => initial + index);
    }
    if (session.time.isEmpty) {
      throw const FormatException('课表条目缺少有效节次');
    }
    return session;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'teacherId': teacherId,
        'confirmed': confirmed,
        'firstHalf': firstHalf,
        'secondHalf': secondHalf,
        'oddWeek': oddWeek,
        'evenWeek': evenWeek,
        'day': dayOfWeek,
        'time': time,
        'location': location,
        'customRepeat': customRepeat,
        'customRepeatWeeks': customRepeatWeeks,
        'credit': credit,
        'online': online,
        'type': type,
      };

  Session.fromJson(Map<String, dynamic> json)
      : id = asString(json['id']),
        name = asString(json['name']) ?? '未知课程',
        teacher = asString(json['teacher']) ?? '未知教师',
        teacherId = asString(json['teacherId']),
        confirmed = asBool(json['confirmed']) ?? true,
        firstHalf = asBool(json['firstHalf']) ?? false,
        secondHalf = asBool(json['secondHalf']) ?? false,
        oddWeek = asBool(json['oddWeek']) ?? true,
        evenWeek = asBool(json['evenWeek']) ?? true,
        dayOfWeek = asInt(json['day']) ?? 1,
        time = (asDynamicList(json['time']) ?? const [])
            .map(asInt)
            .whereType<int>()
            .toList(),
        location = asString(json['location']),
        customRepeat = asBool(json['customRepeat']) ?? false,
        customRepeatWeeks =
            (asDynamicList(json['customRepeatWeeks']) ?? const [])
                .map(asInt)
                .whereType<int>()
                .toList(),
        credit = asDouble(json['credit']),
        online = asBool(json['online']),
        type = asString(json['type']);

  String get chineseTime {
    var timeString =
        '${(oddWeek & evenWeek) ? '' : oddWeek ? '单 - ' : '双 - '}周${dayMap[dayOfWeek]}第';
    for (var i = 0; i < time.length; i++) {
      timeString += time[i].toString();
      if (i != time.length - 1) {
        timeString += ', ';
      }
    }
    timeString.trimRight();
    timeString += '节';
    return timeString;
  }
}
