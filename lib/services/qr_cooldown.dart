import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// No automatic retry: callers may retry after the server's deadline.
class QrCooldown {
  DateTime? retryAt;

  bool get active => retryAt?.isAfter(DateTime.now()) ?? false;

  String get message {
    final seconds = retryAt?.difference(DateTime.now()).inSeconds ?? 0;
    return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ${seconds < 1 ? 1 : seconds + 1} giây.';
  }

  void record(http.Response response) {
    if (response.statusCode != 429) return;
    final now = DateTime.now();
    final value = response.headers['retry-after']?.trim();
    final seconds = int.tryParse(value ?? '');
    DateTime? deadline;
    if (seconds != null && seconds >= 0) {
      deadline = now.add(Duration(seconds: seconds));
    } else if (value != null) {
      try {
        deadline = DateFormat(
          "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
          'en_US',
        ).parseUtc(value);
      } on FormatException {
        // A missing/malformed header gets a conservative local cooldown.
      }
    }
    final next = deadline != null && deadline.isAfter(now)
        ? deadline
        : now.add(const Duration(seconds: 60));
    if (retryAt == null || next.isAfter(retryAt!)) retryAt = next;
  }
}
