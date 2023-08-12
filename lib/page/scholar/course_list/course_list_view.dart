import 'package:celechron/page/scholar/course_list/course_brief_card.dart';
import 'package:celechron/design/sub_title.dart';
import 'package:flutter/cupertino.dart';

import '../../../model/course.dart';
import '../../../model/semester.dart';

class CourseListPage extends StatelessWidget {
  final Semester semester;
  late final List<Course> courses = semester.courses.values.toList();

  CourseListPage({required this.semester, super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          SubtitlePersistentHeader(subtitle: '课程'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                padding: index == 0 ? const EdgeInsets.only(top: 0, bottom: 5, left: 16, right: 16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: CourseBriefCard(
                  course: courses[index],
                  allowDirect: true,
                ),
              ),
              childCount: courses.length,
            ),
          ),
        ],
      ),
    );
  }
}
