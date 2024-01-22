import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../model/grade.dart';
import '../course_detail/course_detail_view.dart';

class GradeCard extends StatefulWidget {
  final Grade grade;
  final CupertinoDynamicColor backgroundColor;

  const GradeCard({
    super.key,
    required this.grade,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  State<GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<GradeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    var isDown = false;
    var isCancel = false;

    return GestureDetector(
      onTapDown: (_) async {
        isDown = true;
        isCancel = false;
        _animationController.forward();
        await Future.delayed(const Duration(milliseconds: 125));
        isDown = false;
        if (isCancel) {
          navigator!.push(CupertinoPageRoute(
              builder: (context) =>
                  CourseDetailPage(courseId: widget.grade.id)));
          _animationController.reverse();
          isCancel = false;
        }
      },
      onTapUp: (_) async {
        isCancel = true;
        if (!isDown) _animationController.reverse();
      },
      onTapCancel: () async => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding:
              const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: brightness == Brightness.dark
                ? CupertinoColors.systemFill
                : CupertinoDynamicColor.resolve(
                    widget.backgroundColor, context),
            // boxShadow
            boxShadow: [
              BoxShadow(
                // Only show shadow in light mode
                color: CupertinoColors.black.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 12,
                offset: const Offset(0, 6), // changes position of shadow
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.grade.name,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ),
                      Text(
                          '${widget.grade.id.substring(0, 22)} / ${widget.grade.credit.toStringAsFixed(1)}学分',
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                overflow: TextOverflow.ellipsis,
                              )),
                    ],
                  )),
                  Text(
                    '${widget.grade.original} / ${widget.grade.fivePoint.toStringAsFixed(1)}',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 8,
                width: max(
                    (context.width - 60) * (widget.grade.fivePoint - 1.4) / 3.6,
                    0),
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemTeal, context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
