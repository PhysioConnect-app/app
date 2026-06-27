@JS()
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('flutterInstallPromptAvailable')
external JSBoolean? get _promptAvailable;

@JS('triggerInstallPrompt')
external void _doTriggerInstall();

bool get isInstallPromptAvailable {
  try {
    return _promptAvailable?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

bool get isIos {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  } catch (_) {
    return false;
  }
}

bool get isStandalone {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

void triggerInstallPrompt() {
  try {
    _doTriggerInstall();
  } catch (_) {}
}
