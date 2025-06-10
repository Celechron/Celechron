import 'dart:io';

final class PlatformFeatures {
  static bool get hasBackgroundRefresh {
    return Platform.isIOS || Platform.isAndroid;
  }

  static bool get hasWidgetSupport {
    return Platform.isIOS || Platform.isAndroid;
  }
}
