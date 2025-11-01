// This Widget is a extension of CupertinoSwitch that supports time-consuming, asynchronous onChanged callback.
// When the switch is toggled, it changes state immediately to reflect the new value (but disabled), and also shows a loading indicator on its left until the asynchronous operation completes.

import 'package:flutter/cupertino.dart';

class CupertinoAsyncSwitch extends StatefulWidget {
  final bool value;
  final Future<void> Function(bool) onChanged;

  const CupertinoAsyncSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CupertinoAsyncSwitch> createState() => _CupertinoAsyncSwitchState();
}

class _CupertinoAsyncSwitchState extends State<CupertinoAsyncSwitch> {
  bool _isLoading = false;

  Future<void> _handleChanged(bool newValue) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.onChanged(newValue);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CupertinoActivityIndicator(),
            ),
          ),
        CupertinoSwitch(
          value: _isLoading ? !widget.value : widget.value,
          onChanged: _isLoading ? null : _handleChanged,
        ),
      ],
    );
  }
}
