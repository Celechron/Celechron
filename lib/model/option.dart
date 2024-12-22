import 'package:get/get.dart';

class Option {
  Rx<Duration> workTime;
  Rx<Duration> restTime;
  RxMap<DateTime, DateTime> allowTime;
  RxInt gpaStrategy;
  RxBool pushOnGradeChange;
  RxInt brightnessMode;

  Option({
    required this.workTime,
    required this.restTime,
    required this.allowTime,
    required this.gpaStrategy,
    required this.pushOnGradeChange,
    required this.brightnessMode,
  });
}