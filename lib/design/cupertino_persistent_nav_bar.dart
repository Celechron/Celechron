import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class CupertinoPersistentNavigationBar extends StatelessWidget {
  final String? middle;
  final String? leading;
  late final String heroTag = middle ?? '';

  CupertinoPersistentNavigationBar({super.key, this.middle, this.leading});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
        pinned: true,
        delegate: _CupertinoPersistentNavigationBarBuilder(
            middle: middle ?? (ModalRoute.of(context)! as CupertinoRouteTransitionMixin<dynamic>).title,
            leading: leading ?? (ModalRoute.of(context)! as CupertinoRouteTransitionMixin<dynamic>).previousTitle.value,
            padding: MediaQuery.of(context).padding.top));
  }
}

class _CupertinoPersistentNavigationBarBuilder
    extends SliverPersistentHeaderDelegate {
  final String? middle;
  final String? leading;
  final double padding;

  _CupertinoPersistentNavigationBarBuilder(
      {required this.middle, this.leading, required this.padding});

  @override
  Widget build(BuildContext context, double shrinkOffset,
      bool overlapsContent) {
    return ClipRect(
        child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: shrinkOffset > 12 ? 10 : shrinkOffset / 1.2,
                sigmaY: shrinkOffset > 12 ? 10 : shrinkOffset / 1.2),
            child: Container(
                padding: EdgeInsets.only(top: padding),
                color: shrinkOffset > 12
                    ? CupertinoDynamicColor.resolve(
                    CupertinoColors.systemBackground, context)
                    .withOpacity(0.5)
                    : CupertinoDynamicColor.resolve(
                    CupertinoColors.systemBackground, context)
                    .withOpacity(shrinkOffset / 24),
                child: Row(children: [
                  Expanded(
                    child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: 'Back',
                          button: true,
                          child: DefaultTextStyle(
                            style: CupertinoTheme
                                .of(context)
                                .textTheme
                                .actionTextStyle,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 50),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Padding(
                                      padding: EdgeInsetsDirectional.only(
                                          start: 8.0)),
                                  Hero(transitionOnUserGestures: true,
                                      tag: '_CupertinoPersistentNavigationBarBackButton',
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .only(start: 6, end: 2),
                                        child: Text.rich(
                                          TextSpan(
                                            text: String.fromCharCode(
                                                CupertinoIcons.back.codePoint),
                                            style: TextStyle(
                                              inherit: false,
                                              fontSize: 30.0,
                                              fontFamily: CupertinoIcons.back
                                                  .fontFamily,
                                              package: CupertinoIcons.back
                                                  .fontPackage,
                                            ),
                                          ),
                                        ),
                                      )),
                                  const Padding(
                                      padding: EdgeInsetsDirectional.only(
                                          start: 6.0)),
                                  Flexible(
                                    child: Align(
                                        alignment: AlignmentDirectional
                                            .centerStart,
                                        widthFactor: 1.0,
                                        child: Hero(
                                            transitionOnUserGestures: true,
                                            createRectTween: _linearTranslateWithLargestRectSizeTween,
                                            placeholderBuilder: _navBarHeroLaunchPadBuilder,
                                            flightShuttleBuilder: myFlightShuttleBuilder,
                                            tag: leading ?? '',
                                            child: Text(
                                              leading ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ))
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.maybePop(context);
                        }
                    ),
                  ),
                  Container(
                      alignment: Alignment.center,
                      child: Hero(transitionOnUserGestures: true,
                          createRectTween: _linearTranslateWithLargestRectSizeTween,
                          placeholderBuilder: _navBarHeroLaunchPadBuilder,
                          flightShuttleBuilder: myFlightShuttleBuilder,
                          tag: middle ?? '',
                          child: Text(
                            middle ?? '',
                            style: CupertinoTheme
                                .of(context)
                                .textTheme
                                .navTitleTextStyle,
                          ))
                  ),
                  const Spacer(),
                ]))));
  }

  @override
  double get minExtent => 44 + padding;

  @override
  double get maxExtent => 44 + padding;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }

  RectTween _linearTranslateWithLargestRectSizeTween(Rect? begin, Rect? end) {
    final Size largestSize = Size(
      math.max(begin!.size.width, end!.size.width),
      math.max(begin.size.height, end.size.height),
    );
    return RectTween(
      begin: begin.topLeft & largestSize,
      end: end.topLeft & largestSize,
    );
  }

  Widget _navBarHeroLaunchPadBuilder(BuildContext context,
      Size heroSize,
      Widget child,) {
    return Visibility(
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      visible: false,
      child: child,
    );
  }
}

Widget myFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
    ) {
  // Retrieve the initial and final positions of the Hero widgets
  final Rect initialBounds = (fromHeroContext.findRenderObject() as RenderBox).paintBounds;
  final Rect finalBounds = (toHeroContext.findRenderObject() as RenderBox).paintBounds;

  // Calculate the linear movement based on the animation value
  final Rect? interpolatedBounds = Rect.lerp(initialBounds, finalBounds, animation.value);

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      return Positioned(
        left: interpolatedBounds?.left,
        top: interpolatedBounds?.top,
        right: interpolatedBounds?.right,
        bottom: interpolatedBounds?.bottom,
        child: Container(
          color: Color.lerp(
            (flightDirection == HeroFlightDirection.push)
                ? ((fromHeroContext.widget as Hero).child as Text).style?.color
                : ((toHeroContext.widget as Hero).child as Text).style?.color,
            (flightDirection == HeroFlightDirection.push)
                ? ((toHeroContext.widget as Hero).child as Text).style?.color
                : ((fromHeroContext.widget as Hero).child as Text).style?.color,
            animation.value,
          ),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        ),
      );
    },
    child: (flightDirection == HeroFlightDirection.push)
        ? (fromHeroContext.widget as Hero).child
        : (toHeroContext.widget as Hero).child,
  );
}

