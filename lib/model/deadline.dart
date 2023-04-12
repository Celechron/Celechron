import '../utils/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 6)
class Deadline {
  @HiveField(0)
  String uid;
  @HiveField(1)
  DeadlineType deadlineType;
  @HiveField(2)
  String description;
  @HiveField(3)
  Duration timeSpent;
  @HiveField(4)
  Duration timeNeeded;
  @HiveField(5)
  DateTime endTime;
  @HiveField(6)
  String location;
  @HiveField(7)
  String summary;
  @HiveField(8)
  bool isBreakable;

  Deadline({
    this.uid = '114514',
    this.deadlineType = DeadlineType.running,
    this.description = "1. 到变隐龙商店购买一个苹果\n2. 把苹果存到袋兽阿姨仓库里",
    this.timeSpent = const Duration(minutes: 0),
    this.timeNeeded = const Duration(days: 0, hours: 2, minutes: 30),
    required this.endTime,
    this.location = "宝藏镇",
    this.summary = "作业：不可思议迷宫导论",
    this.isBreakable = false,
  });

  void reset() {
    genUid();
    deadlineType = DeadlineType.deleted;
    description = "";
    timeSpent = const Duration(minutes: 0);
    timeNeeded = const Duration(hours: 1);
    endTime = DateTime.now().add(const Duration(days: 1));
    endTime = DateTime(
        endTime.year, endTime.month, endTime.day, endTime.hour, endTime.minute);
    location = "";
    summary = "";
    isBreakable = true;
  }

  Deadline copyWith({
    String? uid,
    DeadlineType? deadlineType,
    String? description,
    Duration? timeSpent,
    Duration? timeNeeded,
    DateTime? endTime,
    String? location,
    String? summary,
    bool? isBreakable,
  }) {
    return Deadline(
      uid: uid ?? this.uid,
      deadlineType: deadlineType ?? this.deadlineType,
      description: description ?? this.description,
      timeSpent: timeSpent ?? this.timeSpent,
      timeNeeded: timeNeeded ?? this.timeNeeded,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
      isBreakable: isBreakable ?? this.isBreakable,
    );
  }

  void genUid() {
    uid = const Uuid().v4();
  }

  double getProgress() {
    return 100.00 * timeSpent.inMicroseconds / timeNeeded.inMicroseconds;
  }

  void updateTimeSpent(Duration length) {
    timeSpent = length;
    if (timeSpent > timeNeeded) {
      timeSpent = timeNeeded;
    }
    refreshType();
  }

  void refreshType() {
    if (timeSpent >= timeNeeded) {
      deadlineType = DeadlineType.completed;
    } else if (endTime.isBefore(DateTime.now())) {
      deadlineType = DeadlineType.failed;
    }
  }

  void forceRefreshType() {
    if (timeSpent >= timeNeeded) {
      deadlineType = DeadlineType.completed;
    } else if (endTime.isBefore(DateTime.now())) {
      deadlineType = DeadlineType.failed;
    } else {
      deadlineType = DeadlineType.running;
    }
  }
}
