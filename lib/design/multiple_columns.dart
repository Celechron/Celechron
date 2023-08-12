import 'package:flutter/cupertino.dart';

class MultipleColumns extends StatelessWidget {
  final List<Widget> contents;
  final List<String> titles;
  final List<VoidCallback?> onTaps;
  final Color color;

  const MultipleColumns({
    Key? key,
    required this.contents,
    required this.titles,
    required this.onTaps,
    this.color = CupertinoColors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final columnCount = titles.length;

    var children = <Widget>[];
    for (var i = 0; i < columnCount; i++) {
      children.add(_ColumnWidget(
          content: contents[i],
          title: titles[i],
          onTap: onTaps[i],
          color: color,
        ),
      );
      children.add(const _VerticalLine(color: CupertinoColors.systemFill));
    }
    children.removeLast();

    return SizedBox(
        child: Row(
      children: children,
    ));
  }
}

class _ColumnWidget extends StatelessWidget {
  final Widget content;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const _ColumnWidget({
    Key? key,
    required this.content,
    required this.title,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            content,
            Text(title,
                style: const TextStyle(
                    color: CupertinoColors.systemGrey, fontSize: 14)),
          ],
        )));
  }
}

class _VerticalLine extends StatelessWidget {
  final Color color;

  const _VerticalLine({Key? key, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: color,
    );
  }
}
