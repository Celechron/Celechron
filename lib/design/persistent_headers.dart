import 'dart:ui';


import 'package:flutter/cupertino.dart';

class CelechronSliverTextHeader extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double fontSize;
  final bool firstPage;

  CelechronSliverTextHeader(
      {super.key,
      required this.subtitle,
      this.right,
      this.fontSize = 20,
      this.firstPage = false});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
        pinned: true,
        delegate: CelechronHeader(
            fontSize: fontSize,
            firstPage: firstPage,
            subtitle: subtitle,
            right: right,
            padding: MediaQuery.of(context).padding.top));
  }
}

class CelechronHeader extends SliverPersistentHeaderDelegate {
  final String subtitle;
  final Widget? bottom;
  final Widget? right;
  final double padding;
  final double fontSize;
  final bool firstPage;

  CelechronHeader(
      {required this.subtitle,
      this.right,
      this.bottom,
      required this.padding,
      this.fontSize = 20,
      this.firstPage = false});

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
          child: Column(children: [
            Stack(
              children: [
                // Back button if not first page
                if (!firstPage)
                  Container(
                      alignment: Alignment.centerLeft,
                      child: CupertinoButton(
                          padding: const EdgeInsets.only(left: 2),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Icon(
                            CupertinoIcons.back,
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.label, context),
                          ))),
                // Title at the center
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Hero(
                        tag: subtitle,
                        child: Column(children: [
                          Text(
                            subtitle,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navTitleTextStyle
                                .copyWith(fontSize: fontSize - (bottom == null ? 0 : 2)),
                          ),
                          if (bottom != null) bottom!,
                        ]),
                      )),
                ]),
                // Right button
                if (right != null)
                  Container(
                      alignment: Alignment.centerRight,
                      child: right),
              ],
            )
          ])),
    ));
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
