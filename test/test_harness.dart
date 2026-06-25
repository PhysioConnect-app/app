import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clinic_telehealth_app/core/providers/language_provider.dart';

/// Standard phone viewport used across the mobile-overflow audit.
const phoneSize = Size(390, 844);

/// Standard desktop viewport used for golden/regression checks.
const desktopSize = Size(1400, 900);

/// Initializes Supabase against an unreachable local endpoint so widgets that
/// touch `Supabase.instance` during construction don't throw, while any
/// network calls fail fast (connection refused) instead of hanging.
Future<void> ensureSupabaseInitialized() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // supabase_flutter's deep-link handling listens on the app_links plugin's
  // event channel, which has no platform implementation in the test
  // environment. Without a mock, that listen() throws a MissingPluginException
  // asynchronously, which fails any test that awaits real async work
  // afterwards (e.g. golden-file capture via tester.runAsync).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel('com.llfbandit.app_links/events'),
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );

  try {
    // Throws if not yet initialized.
    Supabase.instance;
    return;
  } catch (_) {
    // Not initialized yet - fall through.
  }
  await Supabase.initialize(
    url: 'http://127.0.0.1:54321',
    // ignore: deprecated_member_use
    anonKey: 'test-anon-key-not-real',
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    httpClient: http_testing.MockClient((request) async {
      return http.Response('[]', 200,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '*/0',
          });
    }),
  );
  // Supabase Realtime auto-connects a WebSocket on initialize and retries on
  // failure. The retry timers keep tester.runAsync's async zone alive, causing
  // matchesGoldenFile (which uses runAsync for file I/O) to hang indefinitely.
  // Disconnecting here stops all retry timers before any test can be affected.
  Supabase.instance.client.realtime.disconnect();
}

/// Recovers a fake (non-expired, non-JWT-token) session locally so screens
/// that read `Supabase.instance.client.auth.currentUser!.id` during
/// construction don't throw. No network call is made: a non-JWT access
/// token makes `Session.isExpired` return false, so `recoverSession` takes
/// the local "save session" path instead of attempting a token refresh.
Future<String> signInFakeUser({String userId = 'test-user-id'}) async {
  final sessionJson = jsonEncode({
    'access_token': 'fake-access-token',
    'token_type': 'bearer',
    'refresh_token': 'fake-refresh-token',
    'expires_in': 3600,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'email': 'test@example.com',
      'created_at': '2024-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    },
  });
  await Supabase.instance.client.auth.recoverSession(sessionJson);
  return userId;
}

/// Pumps [child] inside a MaterialApp + LanguageProvider at the given
/// viewport [size], then pumps a few extra frames to let initial async
/// work (SharedPreferences load, failed network calls, etc.) settle without
/// risking the indefinite hang `pumpAndSettle` can hit on retry timers.
Future<void> pumpAtSize(
  WidgetTester tester,
  Widget child, {
  Size size = phoneSize,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    ),
  );

  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
