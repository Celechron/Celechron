import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:celechron/main.dart' show navigatorKey;

class ImageCodePortal {
  static final TextEditingController _inputController = TextEditingController();

  /// 异步显示弹窗，返回用户输入的字符串。若取消则返回 null。
  static Future<String?> show({
    required Uint8List imageBytes,
    required Future<Uint8List> Function() onRefresh,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    // 创建一个 Completer 来管理异步返回
    final Completer<String?> completer = Completer<String?>();

    Uint8List currentImage = imageBytes;
    _inputController.clear();

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false, // 强制用户点击按钮
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoPopupSurface(
              child: Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("安全验证",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // 图片展示与刷新
                    GestureDetector(
                      onTap: () async {
                        final newImage = await onRefresh();
                        setDialogState(() => currentImage = newImage);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          currentImage,
                          height: 60,
                          width: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(CupertinoIcons.refresh_thick),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("点击图片刷新",
                        style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel)),

                    const SizedBox(height: 20),

                    // 输入框
                    CupertinoTextField(
                      controller: _inputController,
                      placeholder: "请输入验证码",
                      autofocus: true,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 10),
                      textAlign: TextAlign.center,
                      decoration: BoxDecoration(
                        color: CupertinoColors.quaternarySystemFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 按钮组
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            child: const Text("取消"),
                            onPressed: () {
                              Navigator.pop(context);
                              if (!completer.isCompleted)
                                completer.complete(null);
                            },
                          ),
                        ),
                        Expanded(
                          child: CupertinoButton.filled(
                            padding: EdgeInsets.zero,
                            child: const Text("确定"),
                            onPressed: () {
                              final text = _inputController.text;
                              Navigator.pop(context);
                              if (!completer.isCompleted)
                                completer.complete(text);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return completer.future;
  }
}
