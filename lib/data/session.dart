class Session {
  String id;
  String name;
  String teacher;
  bool confirmed;

  // firstHalf: 秋/春
  // secondHalf: 春/秋
  // 举例：秋冬学期的课程，firstHalf为true，secondHalf也为true
  bool firstHalf = false;
  bool secondHalf = false;

  // oddWeek: 单周
  // evenWeek: 双周
  bool oddWeek;
  bool evenWeek;

  int day;
  List<int> time;
  String location;

  Session(Map<String, dynamic> json)
      : id = RegExp(r'(.*?-){5}\d+(?=.*\d{10})')
            .firstMatch(json['kcid'] as String)!
            .group(0)!,
        name = json['mc'],
        teacher = json['jsxm'],
        confirmed = (json['sfqd'] as int) == 1,
        day = json['xqj'],
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
}
