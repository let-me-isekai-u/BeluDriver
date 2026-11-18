import 'package:shared_preferences/shared_preferences.dart';

enum SessionMode { driver, carrier }

/// Only a mode name goes in preferences. Credentials remain in Secure Storage.
class ActiveSessionMode {
  static const preferenceKey = 'lastActiveMode';

  static List<SessionMode> restoreOrder(String? lastMode) =>
      lastMode == SessionMode.driver.name
      ? const [SessionMode.driver, SessionMode.carrier]
      : const [SessionMode.carrier, SessionMode.driver];

  static Future<void> _writes = Future<void>.value();

  static Future<List<SessionMode>> readOrder() async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    return restoreOrder(prefs.getString(preferenceKey));
  }

  static Future<void> remember(SessionMode mode) {
    // Queue at the user event so later choices win even across async storage.
    final write = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(preferenceKey, mode.name);
      } catch (_) {
        // A preference failure must not turn a completed login into a failed one.
      }
    });
    _writes = write;
    return write;
  }
}
