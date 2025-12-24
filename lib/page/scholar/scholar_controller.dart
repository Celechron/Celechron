import 'dart:async';

import 'package:get/get.dart';

import 'package:celechron/model/todo.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';

class ScholarController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _option = Get.find<Option>(tag: 'option');

  final Rx<Duration> _durationToLastUpdateGrade = const Duration().obs;
  final Rx<Duration> _durationToLastUpdateCourse = const Duration().obs;
  final Rx<Duration> _durationToLastUpdateHomework = const Duration().obs;

  // 直接初始化为 0，避免 late final 的初始化时机问题
  final RxInt semesterIndex = 0.obs;

  Scholar get scholar => _scholar.value;

  List<Semester> get semesters => _scholar.value.semesters;

  // Getter 保持纯净，不包含任何副作用（不修改状态）
  Semester get selectedSemester {
    final index = semesterIndex.value;

    // 如果学期列表为空，返回当前学期
    if (semesters.isEmpty) {
      return _scholar.value.thisSemester;
    }

    // 如果索引无效，返回当前学期
    if (index < 0 || index >= semesters.length) {
      return _scholar.value.thisSemester;
    }

    // 索引有效，返回对应的学期
    return semesters[index];
  }

  Duration get durationToLastUpdateGrade => _durationToLastUpdateGrade.value;
  Duration get durationToLastUpdateCourse => _durationToLastUpdateCourse.value;
  Duration get durationToLastUpdateHomework =>
      _durationToLastUpdateHomework.value;

  List<double> get gpa => _option.gpaStrategy.value == GpaStrategy.first
      ? _scholar.value.gpa
      : _scholar.value.aboardGpa;

  List<Todo> get todos => _scholar.value.todos
    ..sort((a, b) {
      if (a.endTime == null) return 1;
      if (b.endTime == null) return -1;
      return a.endTime!.compareTo(b.endTime!);
    });

  // 获取当前学期的未完成作业
  List<Todo> get currentSemesterPendingTodos {
    final thisSemester = _scholar.value.thisSemester;
    final currentSemesterCourseNames =
        thisSemester.courses.values.map((course) => course.name).toSet();

    return todos.where((todo) {
      // 检查作业是否属于当前学期的课程
      final isCurrentSemester =
          currentSemesterCourseNames.contains(todo.course);
      // 检查作业是否未完成（截止时间未过或没有截止时间）
      final isPending =
          todo.endTime == null || !todo.endTime!.isBefore(DateTime.now());
      return isCurrentSemester && isPending;
    }).toList();
  }

  List<Todo> get todosInOneDay =>
      currentSemesterPendingTodos.where((e) => e.isInOneDay()).toList();

  List<Todo> get todosInOneWeek =>
      currentSemesterPendingTodos.where((e) => e.isInOneWeek()).toList();

  Future<List<String?>> fetchData() async {
    return await _scholar.value.refresh().then((value) {
      _scholar.refresh();

      _durationToLastUpdateGrade.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeGrade);
      _durationToLastUpdateCourse.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeCourse);
      _durationToLastUpdateHomework.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeHomework);
      return value;
    });
  }

  @override
  void onReady() {
    super.onReady();
    // 在生命周期方法中正确初始化 semesterIndex
    final thisSemesterIndex =
        semesters.indexWhere((e) => e.name == _scholar.value.thisSemester.name);
    semesterIndex.value = thisSemesterIndex >= 0 ? thisSemesterIndex : 0;

    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdateGrade.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeGrade);
      _durationToLastUpdateCourse.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeCourse);
      _durationToLastUpdateHomework.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeHomework);
    });
  }
}
