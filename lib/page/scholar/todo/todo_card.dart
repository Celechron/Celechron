import 'package:celechron/model/todo.dart';
import 'package:celechron/utils/utils.dart';
import 'package:flutter/cupertino.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;

  const TodoCard({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    var brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: brightness == Brightness.dark
            ? CupertinoColors.secondarySystemFill
            : CupertinoColors.systemGroupedBackground,
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
        mainAxisAlignment: MainAxisAlignment.center,
        // add a colored edge
        children: [
          Text(
            todo.course,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(leading: 0.5, forceStrutHeight: true),
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoTheme.of(context)
                      .textTheme
                      .textStyle
                      .color!
                      .withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            todo.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(leading: 0.5, forceStrutHeight: true),
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: brightness == Brightness.dark
                      ? CupertinoColors.systemBackground
                      : CupertinoTheme.of(context).textTheme.textStyle.color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            todo.endTime != null ? toStringHumanReadable(todo.endTime!) : "无",
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: brightness == Brightness.dark
                      ? CupertinoColors.systemBackground
                      : CupertinoTheme.of(context).textTheme.textStyle.color,
                ),
          ),
        ],
      ),
    );
  }
}
