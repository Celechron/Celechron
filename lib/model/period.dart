import '../utils/utils.dart';
import 'package:const_date_time/const_date_time.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

// TZID=Asia/Shanghai

@HiveType(typeId: 8)
class Period {
  @HiveField(0)
  String uid;
  @HiveField(1)
  String? fromUid;
  @HiveField(2)
  PeriodType periodType;
  @HiveField(3)
  String description;
  @HiveField(4)
  DateTime startTime;
  @HiveField(5)
  DateTime endTime;
  @HiveField(6)
  String location;
  @HiveField(7)
  String summary;

  Period({
    this.uid = '1919810',
    this.fromUid,
    this.periodType = PeriodType.classes,
    this.description = "教师: 空之探险队的 Kate\n课程代码: PMD00001\n教学时间安排: 春夏 第1-2节",
    this.startTime = const ConstDateTime(2023, 3, 1, 8, 00),
    this.endTime = const ConstDateTime(2023, 3, 1, 9, 35),
    this.location = "胖可丁公会",
    this.summary = "不可思议迷宫导论",
  });

  Period copyWith({
    String? uid,
    String? fromUid,
    PeriodType? periodType,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? summary,
  }) {
    return Period(
      uid: uid ?? this.uid,
      fromUid: fromUid ?? this.fromUid,
      periodType: periodType ?? this.periodType,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
    );
  }

  void genUid() {
    uid = const Uuid().v4();
  }

  String getTimePeriodHumanReadable() {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }
}

int comparePeriod(Period a, Period b) {
  if (a.startTime.compareTo(b.startTime) == 0) {
    return a.endTime.compareTo(b.endTime);
  }
  return a.startTime.compareTo(b.startTime);
}

DateTime formatToDateTime(String val) {
  return DateTime(
      int.parse(val.substring(0, 4)),
      int.parse(val.substring(4, 6)),
      int.parse(val.substring(6, 8)),
      int.parse(val.substring(9, 11)),
      int.parse(val.substring(11, 13)),
      int.parse(val.substring(13, 15)));
}
