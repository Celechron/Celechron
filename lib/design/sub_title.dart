import 'dart:ui';

import 'package:flutter/cupertino.dart';

class SubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  late final String heroTag = subtitle;

  SubtitleRow({required this.subtitle, this.right, this.padHorizontal = 2});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: padHorizontal),
        child: Row(children: [
          Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Hero(
                tag: heroTag,
                child: Text(
                  subtitle,
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle
                      .copyWith(fontSize: 20),
                ),
              )),
          const Spacer(),
          right == null ? const SizedBox(height: 0) : right!,
        ]));
  }
}

class SubtitlePersistentHeader extends StatelessWidget {
  final String subtitle;
  final Widget? right;

  SubtitlePersistentHeader({super.key, required this.subtitle, this.right});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
        pinned: true,
        delegate: _SubtitlePersistentHeaderBuilder(
            subtitle: subtitle,
            right: right,
            padding: MediaQuery.of(context).padding.top));
  }
}

class _SubtitlePersistentHeaderBuilder extends SliverPersistentHeaderDelegate {
  final String subtitle;
  final Widget? right;
  final double padding;

  _SubtitlePersistentHeaderBuilder(
      {required this.subtitle, this.right, required this.padding});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
                child: SubtitleRow(
                    subtitle: subtitle,
                    right: right ??
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: //CupertinoIcon
                              const Icon(
                            CupertinoIcons.clear_circled_solid,
                            color: CupertinoColors.systemGrey,
                            size: 30,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                    padHorizontal: 18))));
  }

  @override
  double get minExtent => 48 + padding;

  @override
  double get maxExtent => 48 + padding;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class SubSubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  late final String heroTag = subtitle;

  SubSubtitleRow({required this.subtitle, this.right, this.padHorizontal = 2});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: padHorizontal),
        child: Row(children: [
          Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Hero(
                tag: heroTag,
                child: Text(
                  subtitle,
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle
                      .copyWith(fontSize: 18),
                ),
              )),
          const Spacer(),
          right == null ? const SizedBox(height: 0) : right!,
        ]));
  }
}
