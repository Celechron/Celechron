import 'package:flutter/cupertino.dart';

/// 刷新状态文案：浅灰小字，换字时新字自下而上顶掉旧字，
/// 字面周期性扫过一道白色流光（颜色作用于文字本身，而非背景）
class RollingShimmerText extends StatefulWidget {
  const RollingShimmerText(
    this.text, {
    super.key,
    this.fontSize = 13,
    this.shimmerPeriod = const Duration(milliseconds: 2500),
  });

  final String text;
  final double fontSize;
  final Duration shimmerPeriod;

  @override
  State<RollingShimmerText> createState() => _RollingShimmerTextState();
}

class _RollingShimmerTextState extends State<RollingShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: widget.shimmerPeriod)
      ..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 底色取与转圈同族的浅灰；流光为白色，深浅色模式下都比底色亮
    final base =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    const highlight = Color(0xFFFFFFFF);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            // 每个周期的前 45% 完成一次自左向右的扫掠，
            // 其余时间高光带停在文字之外，字面保持纯底色
            final t = (_shimmer.value / 0.45).clamp(0.0, 1.0);
            final dx = bounds.width * (t * 3.0 - 1.5);
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds.translate(dx, 0));
          },
          child: child,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // 此闭包必须内联：AnimatedSwitcher 只在 transitionBuilder 身份变化时
            // 才为旧字重建过渡（见框架 AnimatedSwitcher.didUpdateWidget），每次
            // build 产生新闭包恰好让旧字落入「从上方滑出」分支（其动画反向播放，
            // 即 0 → (0,-1) 向上顶出）。不要提成 static 或顶层函数。
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey<String>(widget.text);
              return ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: incoming ? const Offset(0, 1) : const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: Text(
              widget.text,
              key: ValueKey<String>(widget.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // srcIn 会用渐变整体替换字色，这里只需保证不透明
              style: TextStyle(
                fontSize: widget.fontSize,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
