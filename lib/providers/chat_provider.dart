import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/driver_chat_message_model.dart';
import '../services/api_chat_service.dart';
import '../services/signalr_service.dart';

class ChatProvider extends ChangeNotifier {
  static const String _chatHubUrl = ApiChatService.chatHubUrl;
  static const String _joinGroupMethod = 'JoinDriverGroup';
  static const String _leaveGroupMethod = 'LeaveDriverGroup';
  static const String _newMessageEventName = 'driver-group.message.created';
  static const String _messageUpdatedEventName = 'driver-group.message.updated';
  static const String _groupChangedEventName = 'driver-group.group.changed';

  final SignalRService _signalRService = SignalRService();
  final Future<String?> Function() _tokenProvider;
  final ApiChatService _chatService;

  DriverChatGroupDto? _groupInfo;
  int? _groupId;
  List<DriverChatMessageModel> _messages = [];

  bool _isInitializing = false;
  bool _isLoadingMessages = false;
  bool _isLoadingOlderMessages = false;
  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _isRealtimeConnecting = false;
  bool _isRealtimeConnected = false;
  bool _isDisposed = false;
  bool _isGroupUnavailable = false;
  bool _hasExplicitGroupSelection = false;

  bool _hasMoreMessages = false;
  int? _nextBeforeMessageId;

  String? _error;

  ChatProvider({required Future<String?> Function() tokenProvider})
    : _tokenProvider = tokenProvider,
      _chatService = ApiChatService(tokenProvider: tokenProvider);

  int? get groupId => _groupId;
  List<DriverChatMessageModel> get messages => List.unmodifiable(_messages);

  bool get isInitializing => _isInitializing;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  bool get isSending => _isSending;
  bool get isMarkingRead => _isMarkingRead;
  bool get isRealtimeConnecting => _isRealtimeConnecting;
  bool get isRealtimeConnected => _isRealtimeConnected;
  bool get isGroupUnavailable => _isGroupUnavailable;

  bool get hasGroup => _groupId != null;
  bool get hasMessages => _messages.isNotEmpty;
  bool get hasMoreMessages => _hasMoreMessages;
  int? get nextBeforeMessageId => _nextBeforeMessageId;
  String? get error => _error;

  String get groupName {
    final name = _groupInfo?.name?.trim();
    if (name == null || name.isEmpty) {
      return 'Nhóm chat tài xế';
    }
    return name;
  }

  String? get groupDescription {
    final description = _groupInfo?.description?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }
    return description;
  }

  bool get isBusy =>
      _isInitializing ||
      _isLoadingMessages ||
      _isLoadingOlderMessages ||
      _isSending ||
      _isMarkingRead ||
      _isRealtimeConnecting;

  void _log(String message) {
    debugPrint('💬 DriverChatProvider: $message');
  }

  void safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  DriverChatMessageModel _mapMessage(DriverChatGroupMessageDto dto) {
    return DriverChatMessageModel.fromJson(dto.toJson());
  }

  DriverChatGroupDto? _pickPreferredGroup(List<DriverChatGroupDto> groups) {
    for (final group in groups) {
      if (group.isActive) {
        return group;
      }
    }

    if (groups.isEmpty) return null;
    return groups.first;
  }

  void _applySelectedGroup(
    DriverChatGroupDto group, {
    required bool explicitSelection,
  }) {
    if (_groupId != group.id) {
      _messages = [];
      _hasMoreMessages = false;
      _nextBeforeMessageId = null;
    }
    _groupId = group.id;
    _groupInfo = group;
    _isGroupUnavailable = !group.isActive;
    _hasExplicitGroupSelection = explicitSelection;
  }

  Future<void> _loadSelectedGroupDetailIfNeeded({
    bool forceRefresh = false,
  }) async {
    if (_groupId == null) return;
    if (!forceRefresh && _groupInfo?.id == _groupId) {
      return;
    }

    final detail = await _chatService.getDriverGroupDetail(_groupId!);
    _applySelectedGroup(detail, explicitSelection: _hasExplicitGroupSelection);
  }

  Future<int?> ensurePrimaryGroup({bool forceRefresh = false}) async {
    if (_hasExplicitGroupSelection && _groupId != null) {
      await _loadSelectedGroupDetailIfNeeded(forceRefresh: forceRefresh);
      return _groupId;
    }

    if (!forceRefresh && _groupId != null) {
      return _groupId;
    }

    final groups = await _chatService.getDriverGroups();
    final selected = _pickPreferredGroup(groups);

    if (selected == null) {
      _groupId = null;
      _groupInfo = null;
      _messages = [];
      _hasMoreMessages = false;
      _nextBeforeMessageId = null;
      _isGroupUnavailable = true;
      _hasExplicitGroupSelection = false;
      return null;
    }

    _applySelectedGroup(selected, explicitSelection: false);
    return _groupId;
  }

  Future<void> _refreshGroupState() async {
    if (_hasExplicitGroupSelection && _groupId != null) {
      try {
        await _loadSelectedGroupDetailIfNeeded(forceRefresh: true);
      } catch (e) {
        _log('refresh explicit group error: $e');
      }
      safeNotify();
      return;
    }

    final previousGroupId = _groupId;
    final resolvedGroupId = await ensurePrimaryGroup(forceRefresh: true);

    if (resolvedGroupId == null) {
      _error = 'Hiện chưa có nhóm chat hoạt động.';
      if (previousGroupId != null) {
        await disconnectRealtime();
      }
      return;
    }

    if (previousGroupId != null &&
        previousGroupId != resolvedGroupId &&
        _signalRService.isConnected) {
      try {
        await _signalRService.invoke(
          _leaveGroupMethod,
          args: [previousGroupId],
        );
      } catch (e) {
        _log('leave old group after refresh error: $e');
      }

      try {
        await _signalRService.invoke(_joinGroupMethod, args: [resolvedGroupId]);
      } catch (e) {
        _log('join refreshed group error: $e');
      }
    }
  }

  Future<void> initChat({
    int? groupId,
    DriverChatGroupDto? initialGroup,
    bool autoMarkRead = true,
    int take = 30,
  }) async {
    _log('initChat start');
    _isInitializing = true;
    _error = null;
    safeNotify();

    try {
      _groupId = groupId ?? initialGroup?.id;
      _groupInfo =
          initialGroup ?? (_groupInfo?.id == _groupId ? _groupInfo : null);
      _hasExplicitGroupSelection = _groupId != null;

      final int? resolvedGroupId;
      if (_groupId != null) {
        await _loadSelectedGroupDetailIfNeeded();
        resolvedGroupId = _groupId;
      } else {
        resolvedGroupId = await ensurePrimaryGroup();
      }

      if (resolvedGroupId == null) {
        _isInitializing = false;
        _error ??= 'Hiện chưa có nhóm chat hoạt động.';
        safeNotify();
        return;
      }

      final page = await _chatService.getDriverGroupMessages(
        groupId: resolvedGroupId,
        take: take,
      );

      _messages = _sortMessagesAscending(page.items.map(_mapMessage).toList());
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;
      _isInitializing = false;
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(silent: true);
      }
    } catch (e) {
      _error = 'Đã có lỗi xảy ra, vui lòng thử lại.';
      _isInitializing = false;
      _log('initChat error: $e');
      safeNotify();
    }
  }

  Future<void> loadMessages({
    int? groupId,
    bool autoMarkRead = false,
    int take = 30,
  }) async {
    if (groupId != null) {
      _groupId = groupId;
      _hasExplicitGroupSelection = true;
      if (_groupInfo?.id != groupId) {
        _groupInfo = null;
      }
      await _loadSelectedGroupDetailIfNeeded();
    }

    final resolvedGroupId = groupId ?? _groupId ?? await ensurePrimaryGroup();
    if (resolvedGroupId == null) {
      _error = 'Hiện chưa có nhóm chat hoạt động.';
      safeNotify();
      return;
    }

    _groupId = resolvedGroupId;
    _isLoadingMessages = true;
    _error = null;
    safeNotify();

    try {
      final before = {for (final message in _messages) message.id: message};
      final page = await _chatService.getDriverGroupMessages(
        groupId: resolvedGroupId,
        take: take,
      );

      if (_isDisposed || _groupId != resolvedGroupId) return;
      if (before.isEmpty) {
        _hasMoreMessages = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
      }
      final merged = {for (final message in _messages) message.id: message};
      for (final message in page.items.map(_mapMessage)) {
        if (identical(merged[message.id], before[message.id])) {
          merged[message.id] = message;
        }
      }
      _messages = _sortMessagesAscending(merged.values.toList());
      _isLoadingMessages = false;
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(silent: true);
      }
    } catch (e) {
      _error = 'Không thể tải tin nhắn.';
      _isLoadingMessages = false;
      _log('loadMessages error: $e');
      safeNotify();
    }
  }

  Future<void> loadOlderMessages({int take = 30}) async {
    if (_groupId == null) return;
    if (_isLoadingOlderMessages) return;
    if (!_hasMoreMessages) return;
    if (_nextBeforeMessageId == null) return;

    _isLoadingOlderMessages = true;
    _error = null;
    safeNotify();

    try {
      final page = await _chatService.getDriverGroupMessages(
        groupId: _groupId!,
        beforeMessageId: _nextBeforeMessageId,
        take: take,
      );

      final oldIds = _messages.map((e) => e.id).toSet();
      final olderItems = page.items
          .map(_mapMessage)
          .where((e) => !oldIds.contains(e.id))
          .toList();

      _messages = _sortMessagesAscending([...olderItems, ..._messages]);
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;
      _isLoadingOlderMessages = false;
      safeNotify();
    } catch (e) {
      _error = 'Không thể tải thêm tin nhắn cũ.';
      _isLoadingOlderMessages = false;
      _log('loadOlderMessages error: $e');
      safeNotify();
    }
  }

  Future<void> connectRealtime({int? groupId}) async {
    if (_isDisposed || _isRealtimeConnected || _isRealtimeConnecting) return;
    if (groupId != null) {
      _groupId = groupId;
      _hasExplicitGroupSelection = true;
    }

    _isRealtimeConnecting = true;
    safeNotify();

    try {
      final resolvedGroupId = _groupId ?? await ensurePrimaryGroup();
      if (_isDisposed || resolvedGroupId == null) return;

      await _signalRService.connect(
        hubUrl: _chatHubUrl,
        accessTokenFactory: () async => await _tokenProvider() ?? '',
        configure: () {
          _registerConnectionLifecycleListeners();
          _registerRealtimeListeners();
        },
      );
      if (_isDisposed) return;
      await _signalRService.invoke(_joinGroupMethod, args: [resolvedGroupId]);
      _isRealtimeConnected = true;
      await loadMessages(autoMarkRead: true);
    } catch (e) {
      _isRealtimeConnected = false;
      _log('connectRealtime failed: ${e.runtimeType}');
    } finally {
      _isRealtimeConnecting = false;
      safeNotify();
    }
  }

  void _registerConnectionLifecycleListeners() {
    _signalRService.onReconnecting(({error}) {
      _isRealtimeConnected = false;
      _isRealtimeConnecting = true;
      safeNotify();
    });

    _signalRService.onReconnected(({connectionId}) async {
      if (_isDisposed || _groupId == null) {
        return;
      }

      try {
        await _signalRService.invoke(_joinGroupMethod, args: [_groupId!]);
        _isRealtimeConnected = true;
        _isRealtimeConnecting = false;
        safeNotify();

        await _refreshGroupState();
        if (_groupId != null) {
          await loadMessages(autoMarkRead: true);
        }
      } catch (e) {
        _isRealtimeConnected = false;
        _isRealtimeConnecting = false;
        _log('rejoin after reconnect error: $e');
        safeNotify();
      }
    });

    _signalRService.onClose(({error}) {
      _isRealtimeConnected = false;
      _isRealtimeConnecting = false;
      safeNotify();
      Future<void>.delayed(const Duration(seconds: 1), connectRealtime);
    });
  }

  int? _extractEventGroupId(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return null;
    final raw = arguments.first;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final value = map['groupId'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final value = decoded['groupId'];
          if (value is int) return value;
          if (value is num) return value.toInt();
          return int.tryParse(value?.toString() ?? '');
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  void _registerRealtimeListeners() {
    _signalRService.on(
      _newMessageEventName,
      (arguments) => _onMessage(arguments),
    );
    _signalRService.on(
      _messageUpdatedEventName,
      (arguments) => _onMessage(arguments, update: true),
    );
    _signalRService.on(_groupChangedEventName, (arguments) async {
      if (_isDisposed || _extractEventGroupId(arguments) != _groupId) return;
      try {
        await _refreshGroupState();
      } catch (e) {
        _log('group state refresh failed: ${e.runtimeType}');
      }
    });
  }

  Future<void> _onMessage(
    List<Object?>? arguments, {
    bool update = false,
  }) async {
    if (_isDisposed || arguments == null || arguments.isEmpty) {
      return;
    }

    try {
      final raw = arguments.first;
      DriverChatMessageModel? message;

      if (raw is Map) {
        message = DriverChatMessageModel.fromJson(
          Map<String, dynamic>.from(raw),
        );
      } else if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          message = DriverChatMessageModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }

      if (message == null || message.id <= 0 || message.groupId != _groupId)
        return;
      if (update) {
        final index = _messages.indexWhere((item) => item.id == message!.id);
        if (index < 0) return;
        _messages = [..._messages]..[index] = message;
        safeNotify();
      } else if (!_messages.any((item) => item.id == message!.id)) {
        addIncomingMessage(message);
        await markAsRead(silent: true);
      }
    } catch (e) {
      _log('Invalid chat event: ${e.runtimeType}');
    }
  }

  Future<void> disconnectRealtime() async {
    _signalRService.off(_newMessageEventName);
    _signalRService.off(_messageUpdatedEventName);
    _signalRService.off(_groupChangedEventName);
    await _signalRService.disconnect();
    _isRealtimeConnected = false;
    _isRealtimeConnecting = false;
    safeNotify();
  }

  Future<bool> sendMessage({required String content}) async {
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      _error = 'Nội dung tin nhắn không được để trống.';
      safeNotify();
      return false;
    }

    final resolvedGroupId = _groupId ?? await ensurePrimaryGroup();
    if (resolvedGroupId == null) {
      _error = 'Hiện chưa có nhóm chat hoạt động.';
      safeNotify();
      return false;
    }

    _isSending = true;
    _error = null;
    safeNotify();

    try {
      final sent = await _chatService.sendTextMessage(
        groupId: resolvedGroupId,
        content: trimmed,
      );

      final sentMessage = _mapMessage(sent);
      final exists = _messages.any((m) => m.id == sentMessage.id);
      if (!exists) {
        _messages = _sortMessagesAscending([..._messages, sentMessage]);
      }

      _isSending = false;
      safeNotify();
      return true;
    } catch (e) {
      _error = 'Không thể gửi tin nhắn.';
      _isSending = false;
      _log('sendMessage error: $e');
      safeNotify();
      return false;
    }
  }

  Future<bool> markAsRead({bool silent = false}) async {
    if (_groupId == null) return false;

    if (!silent) {
      _isMarkingRead = true;
      _error = null;
      safeNotify();
    }

    try {
      await _chatService.markGroupAsRead(_groupId!);

      if (!silent) {
        _isMarkingRead = false;
        safeNotify();
      }

      return true;
    } catch (e) {
      if (!silent) {
        _error = 'Không thể cập nhật trạng thái đã đọc.';
        _isMarkingRead = false;
        safeNotify();
      }
      return false;
    }
  }

  void addIncomingMessage(DriverChatMessageModel message) {
    if (_groupId != null && message.groupId != _groupId) {
      return;
    }

    final exists = _messages.any((m) => m.id == message.id);
    if (exists) {
      return;
    }

    _messages = _sortMessagesAscending([..._messages, message]);
    safeNotify();
  }

  List<DriverChatMessageModel> _sortMessagesAscending(
    List<DriverChatMessageModel> items,
  ) {
    final list = [...items];
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  void clearError() {
    _error = null;
    safeNotify();
  }

  void reset() {
    _groupInfo = null;
    _groupId = null;
    _messages = [];
    _isInitializing = false;
    _isLoadingMessages = false;
    _isLoadingOlderMessages = false;
    _isSending = false;
    _isMarkingRead = false;
    _isRealtimeConnecting = false;
    _isRealtimeConnected = false;
    _isGroupUnavailable = false;
    _hasExplicitGroupSelection = false;
    _hasMoreMessages = false;
    _nextBeforeMessageId = null;
    _error = null;
    safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    disconnectRealtime();
    _chatService.dispose();
    super.dispose();
  }
}
