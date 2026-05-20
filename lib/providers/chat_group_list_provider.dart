import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_chat_service.dart';

class ChatGroupListProvider extends ChangeNotifier {
  late final ApiChatService _chatService = ApiChatService(
    tokenProvider: _readAccessToken,
  );

  List<DriverChatGroupDto> groups = const [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;
  String accessToken = '';

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> loadGroups({bool refresh = false}) async {
    if (refresh) {
      isRefreshing = true;
      error = null;
    } else {
      isLoading = true;
      error = null;
    }
    notifyListeners();

    final token = await _readAccessToken() ?? '';

    if (token.isEmpty) {
      accessToken = '';
      groups = const [];
      error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      isLoading = false;
      isRefreshing = false;
      notifyListeners();
      return;
    }

    try {
      final loadedGroups = await _chatService.getDriverGroups();

      final sortedGroups = [...loadedGroups]
        ..sort((a, b) {
          if (a.isActive != b.isActive) {
            return a.isActive ? -1 : 1;
          }

          final aTime = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      accessToken = token;
      groups = sortedGroups;
      isLoading = false;
      isRefreshing = false;
    } catch (_) {
      accessToken = token;
      error = 'Không thể tải danh sách nhóm chat.';
      isLoading = false;
      isRefreshing = false;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
