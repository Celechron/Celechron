class Todo {
  String id;
  String name;
  String course;
  DateTime endTime;

  Todo.fromJson(Map<String, dynamic> json)
      : id = json["id"].toString(),
        name = json["title"],
        course = json["course_name"],
        endTime = DateTime.parse(json["end_time"]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': name,
        'course_name': course,
        'end_time': endTime.toIso8601String()
      };

  static List<Todo> getAllFromCourses(Map<String, dynamic> json) {
    return (json["todo_list"] as List)
        .map<Todo>((e) => Todo.fromJson(e))
        .toList();
  }

  bool isInOneDay() =>
      endTime.subtract(const Duration(days: 1)).isBefore(DateTime.now());

  bool isInOneWeek() =>
      endTime.subtract(const Duration(days: 7)).isBefore(DateTime.now());
}
