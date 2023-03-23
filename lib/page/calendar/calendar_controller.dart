import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../model/period.dart';
import '../../model/user.dart';

class CalendarController extends GetxController {

  final selectedDay = DateTime.now().obs;
  final focusedDay = DateTime.now().obs;
  final calendarFormat = CalendarFormat.month.obs;
  final events = <DateTime, List<Period>>{}.obs;

  final user = Get.find<Rx<User>>(tag: 'user');

  @override
  void onInit() {
    refreshEvents();
    ever(user, (callback) => refreshEvents());
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  void refreshEvents(){
    events.clear();
    for (var element in Get.find<Rx<User>>(tag: 'user').value.coursePeriods) {
      DateTime chop = chopDate(element.startTime);
      if (events[chop] == null) events[chop] = <Period>[];
      events[chop]!.add(element);
    }
  }

  DateTime chopDate(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<Period> getEventsForDay(DateTime day) {
    DateTime chop = chopDate(day);
    return events[chop] ?? [];
  }
}
