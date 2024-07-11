// ignore: depend_on_referenced_packages
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/pigeon/flow_messenger.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Runner/FlowMessenger.swift',
  swiftOptions: SwiftOptions(),
))
enum PeriodTypeDto {
  classes, // 课程
  test, // 考试
  user, // 日程
  flow, // 用Celechron安排的（一个DDL被分解成若干个flow来完成）
}

class PeriodDto {
  String uid;
  PeriodTypeDto type;
  String? name;
  int startTime;
  int endTime;
  String? location;

  PeriodDto({
    required this.uid,
    required this.type,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.location,
  });
}

class FlowMessage {
  FlowMessage({required this.flowListDto});

  List<PeriodDto?> flowListDto;
}

@HostApi()
abstract class FlowMessenger {
  @async
  bool transfer(FlowMessage data);
}
