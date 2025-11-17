class Todo {
  String id;
  String name;
  String course;
  DateTime? endTime;

  Todo.fromJson(Map<String, dynamic> json)
      : id = json["id"].toString(),
        name = json["title"],
        course = json["course_name"],
        endTime =
            json["end_time"] != null ? DateTime.parse(json["end_time"]) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': name,
        'course_name': course,
        'end_time': endTime?.toIso8601String(),
      };

  static List<Todo> getAllFromCourses(Map<String, dynamic> json) {
    return (json["todo_list"] as List)
        .where((e) => e["is_student"] == true) // 只显示用户身份为学生的作业，对于用户身份为助教/老师的不显示为作业
        .map<Todo>((e) => Todo.fromJson(e))
        .toList();
  }

  bool isInOneDay() => endTime != null
      ? endTime!.subtract(const Duration(days: 1)).isBefore(DateTime.now())
      : false;

  bool isInOneWeek() => endTime != null
      ? endTime!.subtract(const Duration(days: 7)).isBefore(DateTime.now())
      : false;
}
