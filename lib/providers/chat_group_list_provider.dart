import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_chat_service.dart';
import '../services/chat_session.dart';
import '../services/signalr_service.dart';

class ChatGroupListProvider extends ChangeNotifier {
  late final ApiChatService _chatService = ApiChatService(
    tokenProvider: ChatSession.accessToken,
  );
  final SignalRService _signalR = SignalRService();
  Timer? _realtimeRefresh;
  bool _disposed = false;
  bool _loadingGroups = false;
  bool _reloadPending = false;

  List<DriverChatGroupDto> groups = const [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;
  String accessToken = '';

  Future<void> loadGroups({bool refresh = false, bool silent = false}) async {
    if (_disposed) return;
    if (_loadingGroups) {
      _reloadPending = true;
      return;
    }
    _loadingGroups = true;
    if (!silent) {
      isRefreshing = refresh;
      isLoading = !refresh;
      error = null;
      notifyListeners();
    }

    try {
      final token = await ChatSession.accessToken();
      if (_disposed) return;
      accessToken = token;
      if (token.isEmpty) {
        groups = const [];
        error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        return;
      }

      final loadedGroups = await _chatService.getDriverGroups();
      if (_disposed) return;

      final sortedGroups = [...loadedGroups]
        ..sort((a, b) {
          if (a.isActive != b.isActive) {
            return a.isActive ? -1 : 1;
          }

          final aTime = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      groups = sortedGroups;
      error = null;
      unawaited(_connectRealtime());
    } catch (_) {
      if (!silent || groups.isEmpty)
        error = 'Không thể tải danh sách nhóm chat.';
    } finally {
      _loadingGroups = false;
      isLoading = false;
      isRefreshing = false;
      if (!_disposed) {
        notifyListeners();
        if (_reloadPending) {
          _reloadPending = false;
          _scheduleRefresh();
        }
      }
    }
  }

  void _scheduleRefresh() {
    if (_disposed || _realtimeRefresh?.isActive == true) return;
    _realtimeRefresh = Timer(const Duration(milliseconds: 250), () {
      unawaited(loadGroups(silent: true));
    });
  }

  Future<void> _connectRealtime() async {
    if (_disposed ||
        _signalR.isConnected ||
        _signalR.isConnecting ||
        _signalR.isReconnecting)
      return;
    try {
      await _signalR.connect(
        hubUrl: ApiChatService.chatHubUrl,
        accessTokenFactory: ChatSession.accessToken,
        configure: () {
          _signalR.on('driver-group.group.changed', (_) => _scheduleRefresh());
          _signalR.onReconnected(({connectionId}) => _scheduleRefresh());
          _signalR.onClose(({error}) {
            Future<void>.delayed(const Duration(seconds: 1), _connectRealtime);
          });
        },
      );
      _scheduleRefresh();
    } catch (_) {
      // Pull-to-refresh remains available if the transport is down.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeRefresh?.cancel();
    unawaited(_signalR.disconnect());
    _chatService.dispose();
    super.dispose();
  }
}
