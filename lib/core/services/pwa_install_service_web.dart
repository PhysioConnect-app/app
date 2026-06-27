import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

// Chrome-specific event not in the standard DOM spec — defined here.
@JS('BeforeInstallPromptEvent')
extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external void prompt();
}

class PwaInstallService {
  PwaInstallService._();

  static _BeforeInstallPromptEvent? _deferredPrompt;

  /// Call once at app startup (before runApp) on web.
  static void initialize() {
    if (!kIsWeb) return;
    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event e) {
        e.preventDefault();
        _deferredPrompt = e as _BeforeInstallPromptEvent;
      }).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _deferredPrompt = null;
      }).toJS,
    );
  }

  /// True when Chrome has deferred its native install prompt (Android/desktop Chrome).
  static bool get isInstallAvailable => kIsWeb && _deferredPrompt != null;

  /// Show the native Chrome install dialog. Clears the deferred prompt afterwards.
  static void triggerInstallPrompt() {
    _deferredPrompt?.prompt();
    _deferredPrompt = null;
  }

  /// True when running in iOS Safari (not Chrome-on-iOS, not Firefox-on-iOS).
  static bool get isIosSafari {
    if (!kIsWeb) return false;
    final ua = web.window.navigator.userAgent.toLowerCase();
    return (ua.contains('iphone') || ua.contains('ipad')) &&
        ua.contains('safari') &&
        !ua.contains('crios') &&   // Chrome on iOS
        !ua.contains('fxios') &&   // Firefox on iOS
        !ua.contains('chrome');
  }

  /// True when the app is already running in standalone (installed PWA) mode.
  static bool get isInStandaloneMode {
    if (!kIsWeb) return false;
    return web.window.matchMedia('(display-mode: standalone)').matches;
  }
}
