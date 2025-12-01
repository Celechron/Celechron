import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'package:flutter/cupertino.dart';

import 'package:celechron/model/session.dart';

class SessionCard extends StatefulWidget {
  final List<Session> sessionList;
  final CupertinoDynamicColor backgroundColor;
  final bool hideInfomation;

  const SessionCard({
    super.key,
    required this.sessionList,
    this.hideInfomation = false,
    this.backgroundColor = const CupertinoDynamicColor.withBrightness(
      color: Color.fromRGBO(0, 141, 236, 1.0),
      darkColor: Color.fromRGBO(0, 108, 180, 1.0),
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

    String sessionName = "";
    String sessionLocation = "";
    if (!widget.hideInfomation) {
      if (widget.sessionList.length == 1) {
        sessionName = widget.sessionList[0].name;
        sessionLocation = widget.sessionList[0].location ?? '未知地点';
      } else {
        sessionName = "冲突课程\n";
        for (var i in widget.sessionList) {
          sessionName =
              '$sessionName\n${i.time.first}-${i.time.last}: ${i.name}';
        }
      }
    }

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
      onTap: () async {
        if (widget.sessionList.length == 1) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  CourseDetailPage(courseId: widget.sessionList[0].id),
              title: widget.sessionList[0].name,
            ),
          );
        } else {
          await showCupertinoDialog(
            context: context,
            builder: (BuildContext context) {
              return CupertinoAlertDialog(
                title: const Text(
                  '要查看哪一个？',
                ),
                content: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var s in widget.sessionList)
                      CupertinoButton(
                        minimumSize: const Size(22.0, 22.0),
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
                        child: Text(
                          s.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) =>
                                  CourseDetailPage(courseId: s.id),
                              title: s.name,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('返回'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              );
            },
          );
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.only(
            top: 1.4,
            bottom: 1.4,
            left: 1.4,
            right: 1.4,
          ),
          child: Container(
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: CupertinoDynamicColor.resolve(
                  widget.backgroundColor, context),
            ),
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 2.0, right: 2.0, top: 2.0, bottom: 2.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        sessionName,
                        textAlign: TextAlign.center,
                        maxLines: widget.sessionList.length == 1
                            ? 3 // 单课程最多3行
                            : (widget.sessionList.length * 2)
                                .clamp(2, 6), // 冲突课程最多6行
                        overflow: TextOverflow.ellipsis,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(255, 255, 255, 1.0),
                            ),
                      ),
                    ),
                    if (!widget.hideInfomation &&
                        sessionLocation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          sessionLocation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                fontSize: 9,
                                color: const Color.fromRGBO(255, 255, 255, 0.9),
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
