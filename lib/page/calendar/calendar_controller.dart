import 'package:celechron/model/deadline.dart';
import 'package:celechron/utils/utils.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/user.dart';

class CalendarController extends GetxController {
  final selectedDay = DateTime.now().obs;
  final focusedDay = DateTime.now().obs;
  final calendarFormat = CalendarFormat.month.obs;
  final events = <DateTime, List<Period>>{}.obs;
  final user = Get.find<Rx<User>>(tag: 'user');
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');

  static List<String> numToChinese = ['一', '二', '三', '四', '五', '六', '七', '八'];

  String dayDescription(DateTime day) {
    var semester = user.value.semesters.firstWhereOrNull(
        (e) => !day.isBefore(e.firstDay) && !day.isAfter(e.lastDay));
    if (semester == null) return '考试周/假期';

    var toFirstWeek = day.difference(semester.firstDay).inDays ~/ 7;
    if (toFirstWeek < 8) {
      return '${semester.name[9]}${numToChinese[toFirstWeek]}周';
    }
    var toLastWeek = 7 - semester.lastDay.difference(day).inDays ~/ 7;
    if (toLastWeek < 8) {
      return '${semester.name[10]}${numToChinese[toLastWeek]}周';
    }
    return '考试周/假期';
  }

  @override
  void onInit() {
    refreshEvents();
    ever(user, (callback) => refreshEvents());
    super.onInit();
  }

  void refreshEvents() {
    events.clear();
    Set<DateTime> keySet = {};
    for (var element in Get.find<Rx<User>>(tag: 'user').value.periods) {
      DateTime chop = chopDate(element.startTime);
      if (events[chop] == null) events[chop] = <Period>[];
      events[chop]!.add(element);
      keySet.add(chop);
    }
    for (var i in keySet) {
      events[i]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  DateTime chopDate(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<Period> getEventsForDay(DateTime day) {
    DateTime chop = chopDate(day);
    var eventsOfDay = <Period>[];
    if (events[chop] != null) {
      for (var event in events[chop]!) {
        eventsOfDay.add(event.copyWith());
      }
    }
    for (var deadline in deadlineList) {
      if (deadline.deadlineType == DeadlineType.fixed ||
          deadline.deadlineType == DeadlineType.fixedlegacy) {
        List<Period> periods = deadline.getPeriodOfDay(dateOnly(day));
        for (var p in periods) {
          eventsOfDay.add(p);
        }
      }
    }
    eventsOfDay.sort((a, b) => a.startTime.compareTo(b.startTime));
    return eventsOfDay;
  }
}
