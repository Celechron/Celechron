import 'dart:ui';

import 'package:flutter/cupertino.dart';

class TwoLineCard extends StatefulWidget {
  final String title;
  final String content;
  final String? extraContent;
  final bool withColoredFont;
  final bool animate;
  final VoidCallback? onTap;
  final CupertinoDynamicColor backgroundColor;
  final bool transparent;
  final double? height;
  final double? width;

  const TwoLineCard({
    super.key,
    required this.title,
    required this.content,
    this.extraContent,
    this.animate = false,
    this.withColoredFont = false,
    this.onTap,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.transparent = false,
    this.height,
    this.width,
  });

  static Widget dummy(String title, String content) =>
      const TwoLineCard(title: 'title', content: 'content');

  @override
  State<TwoLineCard> createState() => _TwoLineCardState();
}

class _TwoLineCardState extends State<TwoLineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
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
  }

  @override
  void dispose() {
    if (widget.animate) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isDown = false;
    var isCancel = false;
    var brightness = MediaQuery.of(context).platformBrightness;

    if (widget.transparent) {
      return Container(
        height: widget.height,
        width: widget.width,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // add a colored edge
          children: [
            Text(widget.title,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      color: const Color.fromRGBO(0, 0, 0, 0),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    )),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.content,
                  style:
                      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [const FontFeature.tabularFigures()],
                            color: const Color.fromRGBO(0, 0, 0, 0),
                          ),
                ),
                if (widget.extraContent != null)
                  Text(
                    ' / ${widget.extraContent}',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          fontSize: 12,
                          fontFeatures: [const FontFeature.tabularFigures()],
                          color: const Color.fromRGBO(0, 0, 0, 0),
                        ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    var core = Container(
      height: widget.height,
      width: widget.width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: brightness == Brightness.dark
            ? CupertinoColors.secondarySystemFill
            : CupertinoDynamicColor.resolve(widget.backgroundColor, context),
        // boxShadow
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // add a colored edge
        children: [
          Text(widget.title,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .color!
                        .withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  )),
          const SizedBox(height: 2),
          widget.withColoredFont
              ? const SizedBox(height: 4)
              : SizedBox(
                  height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                          widget.backgroundColor, context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.content,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (widget.withColoredFont &&
                              brightness == Brightness.dark)
                          ? CupertinoDynamicColor.resolve(
                              widget.backgroundColor, context)
                          : CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .color,
                    ),
              ),
              if (widget.extraContent != null)
                Text(
                  ' / ${widget.extraContent}',
                  style:
                      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            fontSize: 12,
                            color: (widget.withColoredFont &&
                                    brightness == Brightness.dark)
                                ? CupertinoDynamicColor.resolve(
                                    widget.backgroundColor, context)
                                : CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color,
                          ),
                ),
            ],
          ),
        ],
      ),
    );

    return widget.animate
        ? GestureDetector(
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
            onTap: widget.onTap,
            child: ScaleTransition(scale: _scaleAnimation, child: core),
          )
        : widget.onTap == null
            ? core
            : GestureDetector(
                onTap: () => widget.onTap!.call(),
                child: core,
              );
  }
}
