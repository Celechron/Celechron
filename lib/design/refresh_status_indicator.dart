import 'package:flutter/cupertino.dart';

import 'rolling_shimmer_text.dart';

/// 下拉刷新指示区内容：复刻 CupertinoSliverRefreshControl 默认 builder 的
/// 各状态转圈（框架 cupertino/refresh.dart 的 buildRefreshIndicator），并在
/// 转圈右侧附加滚动状态文案，转圈+文案作为整体水平居中。
/// message 为 null 时输出与原生逐像素一致。
class RefreshStatusIndicator extends StatefulWidget {
  const RefreshStatusIndicator({
    super.key,
    required this.refreshState,
    required this.pulledExtent,
    required this.refreshTriggerPullDistance,
    required this.refreshIndicatorExtent,
    required this.message,
  });

  final RefreshIndicatorMode refreshState;
  final double pulledExtent;
  final double refreshTriggerPullDistance;
  final double refreshIndicatorExtent;
  final String? message;

  @override
  State<RefreshStatusIndicator> createState() => _RefreshStatusIndicatorState();
}

class _RefreshStatusIndicatorState extends State<RefreshStatusIndicator> {
  // 与框架 _kActivityIndicatorRadius / _kActivityIndicatorMargin 一致
  static const double _radius = 14.0;
  static const double _margin = 16.0;

  // 刷新结束时 message 会先被置空、随后才进入 done 收起动画，
  // 缓存末条文案让文字随转圈一起淡出，而不是瞬间消失
  String? _lastShown;

  Widget _buildSpinner(double percentageComplete) {
    switch (widget.refreshState) {
      case RefreshIndicatorMode.drag:
        const Curve opacityCurve = Interval(0.0, 0.35, curve: Curves.easeInOut);
        return Opacity(
          opacity: opacityCurve.transform(percentageComplete),
          child: CupertinoActivityIndicator.partiallyRevealed(
              radius: _radius, progress: percentageComplete),
        );
      case RefreshIndicatorMode.armed:
      case RefreshIndicatorMode.refresh:
        return const CupertinoActivityIndicator(radius: _radius);
      case RefreshIndicatorMode.done:
        return CupertinoActivityIndicator(radius: _radius * percentageComplete);
      case RefreshIndicatorMode.inactive:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentageComplete =
        (widget.pulledExtent / widget.refreshTriggerPullDistance)
            .clamp(0.0, 1.0)
            .toDouble();

    if (widget.refreshState == RefreshIndicatorMode.inactive ||
        widget.refreshState == RefreshIndicatorMode.drag) {
      // 新一轮下拉不残留上一轮文案
      _lastShown = widget.message;
    } else if (widget.message != null) {
      _lastShown = widget.message;
    }
    final showText = _lastShown != null &&
        (widget.refreshState == RefreshIndicatorMode.armed ||
            widget.refreshState == RefreshIndicatorMode.refresh ||
            widget.refreshState == RefreshIndicatorMode.done);
    // done 阶段随 sliver 收起同步淡出。刷新驻留时 pulledExtent 恰为
    // refreshIndicatorExtent，以其为分母，淡出起点正好是 1.0
    final textOpacity = widget.refreshState == RefreshIndicatorMode.done
        ? (widget.pulledExtent / widget.refreshIndicatorExtent)
            .clamp(0.0, 1.0)
            .toDouble()
        : 1.0;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _margin,
            left: 0.0,
            right: 0.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 固定转圈槽位，done 态转圈收缩时文案不横移
                SizedBox(
                  width: _radius * 2,
                  height: _radius * 2,
                  child: Center(child: _buildSpinner(percentageComplete)),
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    child: showText
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Opacity(
                              opacity: textOpacity,
                              child: RollingShimmerText(_lastShown!),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
