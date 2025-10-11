import 'package:flutter/cupertino.dart';

class AnimateButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final CupertinoDynamicColor backgroundColor;

  const AnimateButton({
    super.key,
    required this.text,
    this.onTap,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  State<AnimateButton> createState() => _AnimateButtonState();
}

class _AnimateButtonState extends State<AnimateButton>
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
    var brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;

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
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: brightness == Brightness.dark
                ? CupertinoColors.secondarySystemFill
                : CupertinoDynamicColor.resolve(
                    widget.backgroundColor, context),
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            // add a colored edge
            children: [
              Text(
                widget.text,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: brightness == Brightness.dark
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
        ),
      ),
    );
  }
}
