class Session {
  String? id;
  late String name;
  late String teacher;
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

  Session.fromZdbk(Map<String, dynamic> json)
      : confirmed = (json['sfqd'] as String) == '1',
        dayOfWeek = int.parse(json['xqj']),
        oddWeek = (json['dsz'] as String) != '1',
        evenWeek = (json['dsz'] as String) != '0' {
    //名称、教师、地点
    if (json.containsKey('kcb')) {
      var nameTeacherPosition = RegExp(r'(.*?)<br>(.*?)<br>(.*?)<br>(.*?)zwf')
          .firstMatch(json['kcb'] as String);
      if (nameTeacherPosition != null) {
        // ZDBK上，课程名称中的括号有时会变成英文括号，此处统一改成中文括号
        name = nameTeacherPosition
            .group(1)!
            .replaceAll('(', '（')
            .replaceAll(')', '）');
        teacher = nameTeacherPosition.group(3)!;
        location = nameTeacherPosition.group(4) == ''
            ? null
            : nameTeacherPosition.group(4);
      }
    }
    // 短学期 or 长学期
    if (json.containsKey('xxq')) {
      var semester = json['xxq'] as String;
      firstHalf = semester.contains("秋") || semester.contains("春");
      secondHalf = semester.contains("冬") || semester.contains("夏");
    }
    // 第几节
    if (json.containsKey('djj') && json.containsKey('skcd')) {
      var initial = int.parse(json['djj'] as String);
      var duration = int.parse(json['skcd'] as String);
      time = List<int>.generate(duration, (index) => initial + index);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
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
      };

  Session.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        teacher = json['teacher'],
        confirmed = json['confirmed'],
        firstHalf = json['firstHalf'],
        secondHalf = json['secondHalf'],
        oddWeek = json['oddWeek'],
        evenWeek = json['evenWeek'],
        dayOfWeek = json['day'],
        time = List<int>.from(json['time']),
        location = json['location'],
        customRepeat = json['customRepeat'] ?? false,
        customRepeatWeeks = List<int>.from(json['customRepeatWeeks'] ?? []);

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
