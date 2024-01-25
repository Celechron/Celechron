import 'package:celechron/utils/utils.dart';
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
  PeriodType type;
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

  @HiveField(8)
  DateTime? lastUpdateTime;

  Period({
    this.uid = '1919810',
    this.fromUid,
    this.type = PeriodType.classes,
    this.description = "教师: 空之探险队的 Kate\n课程代码: PMD00001\n教学时间安排: 春夏 第1-2节",
    required this.startTime,
    required this.endTime,
    this.location = "胖可丁公会",
    this.summary = "不可思议迷宫导论",
    this.lastUpdateTime,
  });

  Period copyWith({
    String? uid,
    String? fromUid,
    PeriodType? type,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? summary,
    DateTime? lastUpdateTime,
  }) {
    return Period(
      uid: uid ?? this.uid,
      fromUid: fromUid ?? this.fromUid,
      type: type ?? this.type,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  void genUid() {
    uid = const Uuid().v4();
  }

  String getTimePeriodHumanReadable() {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour == 0 && endTime.minute == 0 ? '次日 ' : ''}${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
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
