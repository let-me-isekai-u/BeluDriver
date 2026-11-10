import 'dart:async';
import 'dart:convert';

import 'package:beludriver_app/providers/chat_group_list_provider.dart';
import 'package:beludriver_app/providers/chat_provider.dart';
import 'package:beludriver_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestHub {
  static const separator = '\u001e';
  final _events = StreamController<String>();
  late final _polls = StreamIterator<String>(_events.stream);
  final List<String> invocations = [];
  bool _firstPoll = true;

  void emit(String event, Map<String, dynamic> payload) {
    _queue({
      'type': 1,
      'target': event,
      'arguments': [payload],
    });
  }

  void _queue(Map<String, dynamic> payload) {
    _events.add('${jsonEncode(payload)}$separator');
  }

  Future<http.Response> handle(http.Request request) async {
    expect(request.url.host, 'xeghepdongduong.com');
    expect(request.headers['Authorization'], 'Bearer fixture-access');
    if (request.url.path.endsWith('/negotiate')) {
      return http.Response(
        jsonEncode({
          'negotiateVersion': 1,
          'connectionId': 'fixture-id',
          'connectionToken': 'fixture-connection',
          'availableTransports': [
            {
              'transport': 'LongPolling',
              'transferFormats': ['Text'],
            },
          ],
        }),
        200,
      );
    }
    if (request.method == 'POST') {
      final payload = jsonDecode(request.body.split(separator).first) as Map;
      if (payload.containsKey('protocol')) {
        _queue({});
      } else if (payload['type'] == 1) {
        invocations.add(payload['target'] as String);
        _queue({'type': 3, 'invocationId': payload['invocationId']});
      }
    }
    if (request.method == 'GET') {
      if (_firstPoll) {
        _firstPoll = false;
      } else if (await _polls.moveNext()) {
        return http.Response.bytes(utf8.encode(_polls.current), 200);
      }
    }
    return http.Response('', 200);
  }

  Future<void> close() async {
    await _polls.cancel();
    await _events.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accept and cancel pass the chat action key to the server', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      await ApiService.acceptRide(
        accessToken: 'fixture-access',
        id: 7,
        rideSource: 2,
        idempotencyKey: 'accept-fixture-key',
      );
      await ApiService.cancelBrokerRide(
        accessToken: 'fixture-access',
        rideId: 7,
        idempotencyKey: 'cancel-fixture-key',
      );
    }, () => client);
    expect(requests.map((request) => request.headers['Idempotency-Key']), [
      'accept-fixture-key',
      'cancel-fixture-key',
    ]);
  });

  test(
    'driver group list refreshes when the hub reports group activity',
    () async {
      SharedPreferences.setMockInitialValues({'accessToken': 'fixture-access'});
      final hub = TestHub();
      var reads = 0;
      var preview = 'Tin nhắn trước';
      final client = MockClient((request) async {
        if (request.url.path.startsWith('/hubs/chat'))
          return hub.handle(request);
        expect(request.url.path, '/api/chat/driver-groups');
        reads++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'data': [
                {'id': 9, 'isActive': true, 'lastMessagePreview': preview},
              ],
            }),
          ),
          200,
        );
      });

      await http.runWithClient(() async {
        final provider = ChatGroupListProvider();
        final synced = Completer<void>();
        final updated = Completer<void>();
        provider.addListener(() {
          if (reads >= 2 && !synced.isCompleted) synced.complete();
          if (provider.groups.singleOrNull?.lastMessagePreview ==
                  'Tin nhắn mới' &&
              !updated.isCompleted) {
            updated.complete();
          }
        });
        try {
          await provider.loadGroups();
          await synced.future.timeout(const Duration(seconds: 5));
          preview = 'Tin nhắn mới';
          hub.emit('driver-group.group.changed', {'groupId': 9});
          await updated.future.timeout(const Duration(seconds: 5));
          expect(reads, 3);
          expect(hub.invocations, isEmpty);
        } finally {
          provider.dispose();
          await hub.close();
        }
      }, () => client);
    },
  );

  test(
    'driver group receives new messages and updates ride cards through SignalR',
    () async {
      final hub = TestHub();
      final card = {
        'id': 2,
        'groupId': 9,
        'messageType': 2,
        'content': 'Chờ nhận chuyến',
      };
      final httpClient = MockClient((request) async {
        if (request.url.path.startsWith('/hubs/chat'))
          return hub.handle(request);
        final data = switch (request.url.path) {
          '/api/chat/driver-groups/9' => {'id': 9, 'isActive': true},
          '/api/chat/driver-groups/9/messages' => {
            'items': [card],
            'hasMore': false,
          },
          _ => <String, dynamic>{},
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode({'success': true, 'data': data})),
          200,
        );
      });

      await http.runWithClient(() async {
        final provider = ChatProvider(
          tokenProvider: () async => 'fixture-access',
        );
        final received = Completer<void>();
        provider.addListener(() {
          if (!received.isCompleted &&
              provider.messages.any(
                (item) => item.content == 'Đã nhận chuyến',
              ) &&
              provider.messages.any(
                (item) => item.content == 'Tài xế nhắn mới',
              )) {
            received.complete();
          }
        });
        try {
          await provider.initChat(groupId: 9, autoMarkRead: false);
          await provider.connectRealtime(groupId: 9);
          expect(provider.isRealtimeConnected, true);
          expect(hub.invocations, ['JoinDriverGroup']);
          hub.emit('driver-group.message.created', {
            'id': 3,
            'groupId': 9,
            'content': 'Tài xế nhắn mới',
          });
          hub.emit('driver-group.message.updated', {
            ...card,
            'content': 'Đã nhận chuyến',
          });
          await received.future.timeout(const Duration(seconds: 5));
          expect(provider.messages.map((item) => item.id), [2, 3]);
        } finally {
          await provider.disconnectRealtime();
          await hub.close();
          provider.dispose();
        }
      }, () => httpClient);
    },
  );
}
