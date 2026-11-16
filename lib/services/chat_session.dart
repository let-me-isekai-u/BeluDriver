import 'session_auth.dart';
import 'token_storage.dart';

class ChatSession {
  static Future<String> accessToken() async {
    final token = await TokenStorage.instance.readAccessToken();
    if (token == null) return '';
    if (!SessionAuth.expiresSoon(token)) return token;
    try {
      return await SessionAuth.refresh(token) ?? '';
    } catch (_) {
      // Retain credentials; reconnect can try again after a transient failure.
      return '';
    }
  }
}
