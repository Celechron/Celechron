import 'package:get/get.dart';

enum BrightnessMode { system, light, dark }

enum GpaStrategy { best, first }

class CourseIdMap {
  String id1, id2;
  String comment;

  CourseIdMap({required this.id1, required this.id2, required this.comment});

  Map<String, dynamic> toJson() => {
        'id1': id1,
        'id2': id2,
        'comment': comment,
      };

  CourseIdMap.fromJson(Map<String, dynamic> json)
      : id1 = json['id1'],
        id2 = json['id2'],
        comment = json['comment'];
}

class Option {
  Rx<Duration> workTime;
  Rx<Duration> restTime;
  RxMap<DateTime, DateTime> allowTime;
  Rx<GpaStrategy> gpaStrategy;
  RxBool pushOnGradeChange;
  Rx<BrightnessMode> brightnessMode;
  RxList<CourseIdMap> courseIdMappingList;

  Option({
    required this.workTime,
    required this.restTime,
    required this.allowTime,
    required this.gpaStrategy,
    required this.pushOnGradeChange,
    required this.brightnessMode,
    required this.courseIdMappingList,
  });
}
