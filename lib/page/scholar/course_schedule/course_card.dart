import '../course_detail/course_detail_view.dart';
import 'package:flutter/cupertino.dart';

import 'package:celechron/model/session.dart';

class SessionCard extends StatefulWidget {
  final Session session;
  final CupertinoDynamicColor backgroundColor;

  const SessionCard({
    super.key,
    required this.session,
    this.backgroundColor = const CupertinoDynamicColor.withBrightness(
      color: Color.fromRGBO(109, 204, 255, 1.0),
      darkColor: Color.fromRGBO(44, 116, 162, 1.0),
    ),
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard>
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
          _animationController.reverse();
          isCancel = false;
        }
      },
      onTapUp: (_) async {
        isCancel = true;
        if (!isDown) _animationController.reverse();
      },
      onTapCancel: () => _animationController.reverse(),
      onTap: () async => Navigator.of(context).push(CupertinoPageRoute(
          builder: (context) => CourseDetailPage(courseId: widget.session.id),
          title: widget.session.name)),
      child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding:
                const EdgeInsets.only(top: 0, bottom: 1, left: 0, right: 1),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: CupertinoDynamicColor.resolve(
                    widget.backgroundColor, context),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.session.name,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 8),
                  Flexible(
                      child: Text(
                    widget.session.location ?? '未知地点',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 10,
                            ),
                  )),
                ],
              ),
            ),
          )),
    );
  }
}
