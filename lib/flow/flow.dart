import 'package:flutter/material.dart';
import '../utils/utils.dart';
import '../data/period.dart';
import '../data/deadline.dart';
import '../options/options.dart';
import '../algorithm/arrange.dart';

List<Period> flowList = [];

/*

bool updateFlowList(DateTime startsAt) {
  List<Period> periods;
  List<Deadline> deadlines;
  Duration workTime = options.getWorkTime();
  Duration restTime = options.getRestTime();

  DateTime lastDeadlineEndsAt = startsAt;
  for (var x in deadlineList) {
    if (x.endTime.isAfter(lastDeadlineEndsAt)) {
      lastDeadlineEndsAt = x.endTime;
    }
  }

  for (var x in basePeriodList) {}
}

*/