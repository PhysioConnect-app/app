/// Central configuration for third-party API keys.
///
/// GOOGLE MAPS
///  1. console.cloud.google.com → Create project → Enable "Maps SDK for Android" + "Maps SDK for iOS"
///  2. Credentials → Create API Key → restrict to your app package
///  3. Paste the key below, in android/app/src/main/AndroidManifest.xml, and in ios/Runner/AppDelegate.swift
class AppConfig {
  AppConfig._();

  static const googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  static bool get mapsReady =>
      googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
      googleMapsApiKey.isNotEmpty;
}
