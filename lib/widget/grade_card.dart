import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../model/grade.dart';

class GradeCard extends StatefulWidget {
  final Grade grade;
  final VoidCallback? onTap;
  final CupertinoDynamicColor backgroundColor;

  const GradeCard({
    required this.grade,
    this.onTap,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  _GradeCardState createState() => _GradeCardState();
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
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
        reverseCurve: Curves.easeInQuint,
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

    return GestureDetector(
      //onTapDown: (_) => _animationController.forward(),
      //onTapUp: (_) => _animationController.reverse(),
      //onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: brightness == Brightness.dark ? CupertinoColors.secondarySystemFill : CupertinoDynamicColor.resolve(widget.backgroundColor, context),
            // boxShadow
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.grade.name,
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color,
                            ),
                          ),
                          Text(
                              '${widget.grade.id.substring(0,22)} / ${widget.grade.credit.toStringAsFixed(1)}学分',
                              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                color: CupertinoTheme.of(context).textTheme.textStyle.color!.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              )),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${widget.grade.original} / ${widget.grade.fivePoint.toStringAsFixed(1)}',
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoTheme.of(context).textTheme.textStyle.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 8,
                    width: max((context.width - 60) * (widget.grade.fivePoint - 1.2) / 3.8, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(CupertinoColors.systemTeal, context),
                        borderRadius: BorderRadius.circular(2),
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
