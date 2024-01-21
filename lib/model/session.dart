class Session {
  String id;
  String name;
  String teacher;
  bool confirmed;

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

  int dayOfWeek;
  List<int> time;
  String? location;

  String get semesterId => id.substring(1, 12);

  static const String dayMap = '零一二三四五六日';

  Session(Map<String, dynamic> json)
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
        location = json['location'];

  String get chineseTime {
    var timeString = '${(oddWeek & evenWeek) ? '' : oddWeek ? '单 - ' : '双 - '}周${dayMap[dayOfWeek]}第';
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
