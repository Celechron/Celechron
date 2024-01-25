import 'package:celechron/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ArrowDecoration extends Decoration {
  final Color color;
  const ArrowDecoration({required this.color});
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return ArrowPainter(this, color);
  }
}

class ArrowPainter extends BoxPainter {
  final ArrowDecoration decoration;
  Paint? painter;
  final Color color;

  ArrowPainter(this.decoration, this.color)
      : painter = Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    var size = configuration.size!;

    final upleft = offset.translate(0, 0);
    final upmid = offset.translate(size.width / 2, 0);
    final right = offset.translate(size.width, size.height / 2);
    final downmid = offset.translate(size.width / 2, size.height);
    final downleft = offset.translate(0, size.height);
    final center = offset.translate(size.width / 2, size.height / 2);

    final path = Path()
      ..moveTo(upleft.dx, upleft.dy)
      ..moveTo(upmid.dx, upmid.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(downmid.dx, downmid.dy)
      ..lineTo(downleft.dx, downleft.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(upleft.dx, upleft.dy);

    canvas.drawPath(path, painter!..style = PaintingStyle.fill);
  }
}

enum DecorationShape { circle, rectangle, arrow }

Decoration customDecoration(
    {required Color color, required DecorationShape shape}) {
  if (shape == DecorationShape.circle || shape == DecorationShape.rectangle) {
    return BoxDecoration(
      color: color,
      shape: shape == DecorationShape.circle
          ? BoxShape.circle
          : BoxShape.rectangle,
    );
  }
  return ArrowDecoration(color: color);
}

const Map<PeriodType, DecorationShape> periodTypeShape = {
  PeriodType.classes: DecorationShape.circle,
  PeriodType.flow: DecorationShape.arrow,
  PeriodType.user: DecorationShape.arrow,
  PeriodType.test: DecorationShape.rectangle,
  PeriodType.virtual: DecorationShape.circle,
};
