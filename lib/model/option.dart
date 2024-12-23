import 'package:get/get.dart';
import 'package:celechron/utils/utils.dart';

class Option {
  Rx<Duration> workTime;
  Rx<Duration> restTime;
  RxMap<DateTime, DateTime> allowTime;
  Rx<GpaStrategy> gpaStrategy;
  RxBool pushOnGradeChange;
  Rx<BrightnessMode> brightnessMode;

  Option({
    required this.workTime,
    required this.restTime,
    required this.allowTime,
    required this.gpaStrategy,
    required this.pushOnGradeChange,
    required this.brightnessMode,
  });
}