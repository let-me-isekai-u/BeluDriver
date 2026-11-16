import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real TokenStorage interface backed by an in-memory native channel in tests.
Future<void> installDriverSessionFixture(String accessToken) async {
  SharedPreferences.setMockInitialValues({});
  final secure = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'write':
              secure[key!] = args['value'] as String;
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            case 'deleteAll':
              secure.clear();
              return null;
            case 'readAll':
              return secure;
            case 'containsKey':
              return secure.containsKey(key);
          }
          return null;
        },
      );
  await TokenStorage.instance.writeTokens(
    accessToken: accessToken,
    refreshToken: 'test-refresh',
  );
}
