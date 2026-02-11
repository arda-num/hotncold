/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'HotNCold';
  // For iOS simulator use 127.0.0.1
  // For Android emulator use 10.0.2.2
  // For physical device use your Mac's IP (e.g. 192.168.1.100)
  static const String apiBaseUrl = 'http://192.168.1.5:8000';

  // Map defaults (Istanbul)
  static const double defaultLat = 41.0082;
  static const double defaultLng = 28.9784;
  static const double defaultZoom = 14.0;

  // Storage keys
  static const String tokenKey = 'firebase_token';
  static const String userKey = 'user_data';
}
