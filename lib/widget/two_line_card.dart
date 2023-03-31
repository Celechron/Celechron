import 'package:flutter/cupertino.dart';

class TwoLineCard extends StatefulWidget {
  final String title;
  final String content;
  final bool withColoredFont;
  final VoidCallback? onTap;
  final CupertinoDynamicColor backgroundColor;

  const TwoLineCard({
    required this.title,
    required this.content,
    this.withColoredFont = false,
    this.onTap,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  _TwoLineCardState createState() => _TwoLineCardState();
}

class _TwoLineCardState extends State<TwoLineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
        reverseCurve: Curves.easeInQuint,
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

    var brightness = MediaQuery.of(context).platformBrightness;

    return GestureDetector(
      //onTapDown: (_) => _animationController.forward(),
      //onTapUp: (_) => _animationController.reverse(),
      //onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: brightness == Brightness.dark ? CupertinoColors.secondarySystemFill : CupertinoDynamicColor.resolve(widget.backgroundColor, context),
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
              Text(
                widget.title,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        color: CupertinoTheme.of(context).textTheme.textStyle.color!.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
              const SizedBox(height: 2),
              widget.withColoredFont ? const SizedBox(height: 4) : SizedBox(
                height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(widget.backgroundColor, context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.content,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: (widget.withColoredFont && brightness == Brightness.dark) ? CupertinoDynamicColor.resolve(widget.backgroundColor, context) : CupertinoTheme.of(context).textTheme.textStyle.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
