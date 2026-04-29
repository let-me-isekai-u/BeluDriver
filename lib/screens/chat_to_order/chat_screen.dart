import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver_chat_broker_ride_meta_model.dart';
import '../../models/driver_chat_message_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_chat_service.dart';
import '../../services/api_service.dart';
import '../driver/driver_booking_screen.dart';

class DriverGroupChatScreen extends StatelessWidget {
  const DriverGroupChatScreen({super.key, this.initialGroup});

  final DriverChatGroupDto? initialGroup;

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(tokenProvider: _readAccessToken),
      child: _DriverGroupChatView(initialGroup: initialGroup),
    );
  }
}

class _DriverGroupChatView extends StatefulWidget {
  const _DriverGroupChatView({this.initialGroup});

  final DriverChatGroupDto? initialGroup;

  @override
  State<_DriverGroupChatView> createState() => _DriverGroupChatViewState();
}

class _DriverGroupChatViewState extends State<_DriverGroupChatView> {
  static const Color beluDarkGreen = Color(0xFF0A422D);
  static const Color beluMediumGreen = Color(0xFF145E44);
  static const Color beluAccentGold = Color(0xFFFFD700);
  static const Color bgCanvas = Color(0xFFF0F4F2);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  ChatProvider? _provider;
  bool _didCaptureProvider = false;

  String _accessToken = '';
  int? _currentDriverId;
  bool _isReady = false;
  bool _inputFocused = false;
  bool _isOpeningCreateRide = false;
  int? _lastRenderedMessageId;
  final Set<int> _processingBrokerRideIds = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChatScreen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCaptureProvider) {
      _provider = context.read<ChatProvider>();
      _didCaptureProvider = true;
    }
  }

  Future<int?> _fetchCurrentDriverId(String accessToken) async {
    try {
      final response = await ApiService.getDriverProfile(
        accessToken: accessToken,
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawData = decoded['data'] ?? decoded;
        if (rawData is Map<String, dynamic>) {
          final id = rawData['id'];
          if (id is int) return id;
          if (id is num) return id.toInt();
          return int.tryParse(id?.toString() ?? '');
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _initChatScreen() async {
    final provider = _provider ?? context.read<ChatProvider>();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    int? driverId;
    if (token.isNotEmpty) {
      driverId = await _fetchCurrentDriverId(token);
    }

    if (!mounted) return;
    setState(() {
      _accessToken = token;
      _currentDriverId = driverId;
      _isReady = true;
    });

    if (_accessToken.isEmpty) return;

    await provider.initChat(
      accessToken: _accessToken,
      groupId: widget.initialGroup?.id,
      initialGroup: widget.initialGroup,
      autoMarkRead: true,
    );
    if (!mounted || !provider.hasGroup) return;

    await provider.connectRealtime(
      accessToken: _accessToken,
      groupId: provider.groupId,
    );

    if (!mounted) return;
    if (provider.messages.isNotEmpty) {
      _scrollToBottom(jump: true);
    }
  }

  @override
  void dispose() {
    _provider?.disconnectRealtime();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final provider = _provider ?? context.read<ChatProvider>();

    if (_scrollController.position.pixels <= 80) {
      if (!provider.isLoadingOlderMessages && provider.hasMoreMessages) {
        provider.loadOlderMessages();
      }
    }

    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if ((max - current) <= 80) {
      provider.markAsRead(silent: true);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 80;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _accessToken.isEmpty) return;

    final provider = _provider ?? context.read<ChatProvider>();
    final ok = await provider.sendMessage(content: text);

    if (ok) {
      _controller.clear();
      _scrollToBottom();
      await provider.markAsRead(silent: true);
    }
  }

  Future<void> _openCreateRide(ChatProvider provider) async {
    if (_accessToken.isEmpty || _isOpeningCreateRide) return;

    setState(() => _isOpeningCreateRide = true);

    try {
      final resolvedGroupId =
          provider.groupId ??
          await provider.ensurePrimaryGroup(forceRefresh: true);

      if (!mounted) return;

      if (resolvedGroupId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nhóm chat chưa sẵn sàng để đẩy đơn.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DriverBookingScreen(
            groupId: resolvedGroupId,
            closeOnSuccess: true,
          ),
        ),
      );

      if (!mounted || created != true) return;

      await provider.loadMessages(groupId: resolvedGroupId, autoMarkRead: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đơn đã được đẩy vào nhóm chat.'),
          backgroundColor: Colors.green,
        ),
      );
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isOpeningCreateRide = false);
      }
    }
  }

  bool _isBrokerRideBusy(int rideId) {
    return _processingBrokerRideIds.contains(rideId);
  }

  Future<void> _refreshChatAfterBrokerRideAction() async {
    final provider = _provider ?? context.read<ChatProvider>();
    if (provider.groupId == null) return;

    await provider.loadMessages(groupId: provider.groupId, autoMarkRead: true);
  }

  Future<void> _handleCancelBrokerRideCard(
    DriverChatBrokerRideMetaModel ride,
  ) async {
    if (_accessToken.isEmpty || _isBrokerRideBusy(ride.brokerRideId)) return;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Huỷ đơn đã đẩy',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('Bạn chắc chắn muốn huỷ đơn ${ride.code} không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processingBrokerRideIds.add(ride.brokerRideId);
    });

    try {
      final res = await ApiService.cancelBrokerRide(
        accessToken: _accessToken,
        rideId: ride.brokerRideId,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã huỷ đơn ${ride.code}.'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshChatAfterBrokerRideAction();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Huỷ đơn thất bại (${res.statusCode}).'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingBrokerRideIds.remove(ride.brokerRideId);
        });
      }
    }
  }

  Future<void> _handleAcceptBrokerRideCard(
    DriverChatBrokerRideMetaModel ride,
  ) async {
    if (_accessToken.isEmpty || _isBrokerRideBusy(ride.brokerRideId)) return;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _processingBrokerRideIds.add(ride.brokerRideId);
    });

    try {
      final res = await ApiService.acceptRide(
        accessToken: _accessToken,
        id: ride.brokerRideId,
        rideSource: RideSource.brokerRide,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Nhận đơn ${ride.code} thành công.'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshChatAfterBrokerRideAction();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Đơn đã được nhận hoặc không thể nhận.'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingBrokerRideIds.remove(ride.brokerRideId);
        });
      }
    }
  }

  bool _isMine(DriverChatMessageModel message) {
    return _currentDriverId != null &&
        message.senderType == DriverChatSenderType.driver &&
        message.senderId == _currentDriverId;
  }

  bool _isSystem(DriverChatMessageModel message) {
    return message.senderType == DriverChatSenderType.system;
  }

  DateTime _messageTime(DriverChatMessageModel message) {
    return (message.createdAt ?? DateTime.now()).toLocal();
  }

  String _buildTitle(ChatProvider provider) {
    if (provider.isInitializing && !provider.hasGroup) {
      return 'Đang tải nhóm chat...';
    }
    final initialName = widget.initialGroup?.name?.trim();
    if (provider.groupName == 'Nhóm chat tài xế' &&
        initialName != null &&
        initialName.isNotEmpty) {
      return initialName;
    }
    return provider.groupName;
  }

  bool _shouldDisplayBrokerRideCard(DriverChatMessageModel message) {
    if (!message.isBrokerRideCard) return true;

    final ride = message.brokerRideMeta;
    if (ride == null) return false;

    return ride.status == BrokerRideStatus.findingDriver;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final messages = provider.messages
            .where(_shouldDisplayBrokerRideCard)
            .toList(growable: false);
        final latestId = messages.isEmpty ? null : messages.last.id;

        if (latestId != null && latestId != _lastRenderedMessageId) {
          final shouldJump = _lastRenderedMessageId == null;
          _lastRenderedMessageId = latestId;
          _scrollToBottom(jump: shouldJump);
        }

        return Scaffold(
          backgroundColor: bgCanvas,
          appBar: _buildAppBar(provider),
          body: Column(
            children: [
              Expanded(
                child: !_isReady
                    ? const _FullScreenLoader()
                    : _buildBody(provider, messages),
              ),
              _buildInputArea(provider),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ChatProvider provider) {
    final connected = provider.isRealtimeConnected;
    final subtitle =
        provider.groupDescription ??
        widget.initialGroup?.description ??
        'Chat realtime cho tài xế';

    return AppBar(
      elevation: 0,
      centerTitle: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [beluDarkGreen, beluMediumGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: beluAccentGold.withValues(alpha: 0.15),
              border: Border.all(
                color: beluAccentGold.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: beluAccentGold,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _buildTitle(provider),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: beluAccentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected ? Colors.greenAccent : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_accessToken.isNotEmpty)
          IconButton(
            tooltip: 'Đẩy đơn vào nhóm',
            onPressed: _isOpeningCreateRide
                ? null
                : () => _openCreateRide(provider),
            icon: const Icon(Icons.add_box_rounded, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildBody(
    ChatProvider provider,
    List<DriverChatMessageModel> messages,
  ) {
    if (_accessToken.isEmpty) {
      return const _EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Chưa đăng nhập',
        subtitle: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    if (provider.isInitializing && messages.isEmpty) {
      return const _FullScreenLoader();
    }

    if (!provider.hasGroup) {
      return _ErrorState(
        message: provider.error ?? 'Hiện chưa có nhóm chat hoạt động.',
        onRetry: () =>
            provider.initChat(accessToken: _accessToken, autoMarkRead: true),
      );
    }

    if (provider.error != null && messages.isEmpty) {
      return _ErrorState(
        message: provider.error!,
        onRetry: () => provider.initChat(
          accessToken: _accessToken,
          groupId: provider.groupId,
          autoMarkRead: true,
        ),
      );
    }

    if (messages.isEmpty) {
      return _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có tin nhắn',
        subtitle: provider.groupId == null
            ? 'Nhóm chat hiện chưa sẵn sàng.'
            : 'Nhập tin nhắn hoặc nhấn nút + để đẩy đơn vào nhóm.',
      );
    }

    return Column(
      children: [
        if (provider.error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Text(
              provider.error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: provider.isLoadingOlderMessages
              ? const _LoadingOlderBanner(key: ValueKey('loading'))
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final previous = index > 0 ? messages[index - 1] : null;
              final showDateSeparator =
                  previous == null ||
                  !_isSameDay(_messageTime(message), _messageTime(previous));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDateSeparator)
                    _DateSeparator(date: _messageTime(message)),
                  if (message.isBrokerRideCard)
                    _buildBrokerRideCard(message)
                  else
                    _buildChatBubble(message, previous),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(
    DriverChatMessageModel message,
    DriverChatMessageModel? previous,
  ) {
    final isMine = _isMine(message);
    final isSystem = _isSystem(message);
    final previousIsMine = previous != null && _isMine(previous);
    final time = _messageTime(message);
    final showTime =
        previous == null ||
        time.difference(_messageTime(previous)).inMinutes >= 1 ||
        previousIsMine != isMine;
    final showSender =
        !isMine &&
        !isSystem &&
        (previous == null ||
            previous.senderType != message.senderType ||
            previous.senderId != message.senderId ||
            previous.senderName != message.senderName);

    final senderColor = message.senderType == DriverChatSenderType.admin
        ? Colors.blue.shade700
        : beluMediumGreen;

    return TweenAnimationBuilder<double>(
      key: ValueKey(message.id),
      duration: const Duration(milliseconds: 260),
      tween: Tween(begin: 0.9, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: showTime ? 10 : 4,
          left: isMine ? 62 : 0,
          right: isMine ? 0 : 42,
        ),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    message.senderName.isEmpty ? 'Tài xế' : message.senderName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: senderColor,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [beluMediumGreen, beluDarkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSystem
                      ? Colors.amber.shade50
                      : (isMine ? null : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 20 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMine
                          ? beluDarkGreen.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: isSystem
                      ? Border.all(color: Colors.amber.shade200)
                      : (!isMine
                            ? Border.all(color: Colors.grey.shade100)
                            : null),
                ),
                child: Text(
                  message.content.trim().isEmpty
                      ? 'Tin nhắn trống'
                      : message.content,
                  style: TextStyle(
                    color: isMine ? Colors.white : Colors.black87,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              if (showTime)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(time),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black38,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrokerRideCard(DriverChatMessageModel message) {
    final theme = Theme.of(context);
    final ride = message.brokerRideMeta;
    final status = ride?.status ?? 0;
    final isCreatedByMe =
        ride != null &&
        _currentDriverId != null &&
        ride.createdDriverId == _currentDriverId;
    final isAcceptedByMe =
        ride != null &&
        _currentDriverId != null &&
        ride.acceptedDriverId == _currentDriverId;
    final canCancel =
        ride != null &&
        isCreatedByMe &&
        (ride.status == BrokerRideStatus.findingDriver ||
            ride.status == BrokerRideStatus.accepted ||
            ride.status == BrokerRideStatus.inProgress);
    final canAccept =
        ride != null &&
        !isCreatedByMe &&
        !isAcceptedByMe &&
        ride.status == BrokerRideStatus.findingDriver &&
        ride.acceptedDriverId == null;
    final isBusy = ride != null && _isBrokerRideBusy(ride.brokerRideId);

    final Color headerColor;
    final Color borderColor;
    final Color titleColor;
    final IconData headerIcon;

    switch (status) {
      case BrokerRideStatus.accepted:
        headerColor = const Color(0xFF1565C0);
        borderColor = Colors.blue.shade200;
        titleColor = Colors.white;
        headerIcon = Icons.assignment_turned_in_rounded;
        break;
      case BrokerRideStatus.inProgress:
        headerColor = const Color(0xFF00897B);
        borderColor = Colors.teal.shade200;
        titleColor = Colors.white;
        headerIcon = Icons.local_taxi_rounded;
        break;
      case BrokerRideStatus.completed:
        headerColor = const Color(0xFF2E7D32);
        borderColor = Colors.green.shade200;
        titleColor = Colors.white;
        headerIcon = Icons.verified_rounded;
        break;
      case BrokerRideStatus.cancelled:
        headerColor = const Color(0xFFC62828);
        borderColor = Colors.red.shade200;
        titleColor = Colors.white;
        headerIcon = Icons.cancel_rounded;
        break;
      case BrokerRideStatus.findingDriver:
      default:
        headerColor = beluDarkGreen;
        borderColor = beluMediumGreen.withValues(alpha: 0.25);
        titleColor = beluAccentGold;
        headerIcon = Icons.campaign_rounded;
        break;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('ride_${message.id}'),
      duration: const Duration(milliseconds: 280),
      tween: Tween(begin: 0.92, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                color: headerColor,
                child: Row(
                  children: [
                    Icon(headerIcon, color: titleColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride == null || ride.code.trim().isEmpty
                            ? 'Broker ride'
                            : ride.code.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(_messageTime(message)),
                      style: TextStyle(
                        fontSize: 11,
                        color: titleColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ride == null)
                      const Text(
                        'Không đọc được metadata của broker ride.',
                        style: TextStyle(fontSize: 13.5, color: Colors.black54),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thời gian đẩy: ${_formatFullTime(_messageTime(message))}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                ride.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _statusColor(
                                  ride.status,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              _statusText(ride.status),
                              style: TextStyle(
                                color: _statusColor(ride.status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildChatRideLocationLine(
                        '${ride.fromDistrictName ?? ''} - ${ride.fromAddress}',
                        '${ride.toDistrictName ?? ''} - ${ride.toAddress}',
                      ),
                      const SizedBox(height: 14),
                      _buildCompactInfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Thời điểm đón',
                        value: ride.pickupTime == null
                            ? '--'
                            : _formatFullTime(ride.pickupTime!),
                      ),
                      _buildCompactInfoRow(
                        icon: Icons.payments_rounded,
                        label: 'Giá tiền',
                        value: _formatMoney(ride.offerPrice),
                      ),
                      if (isAcceptedByMe)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text(
                              'Bạn đã nhận đơn này.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ),
                      if (canCancel || canAccept) ...[
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isBusy
                                ? null
                                : canCancel
                                ? () => _handleCancelBrokerRideCard(ride)
                                : () => _handleAcceptBrokerRideCard(ride),
                            icon: isBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    canCancel
                                        ? Icons.cancel_outlined
                                        : Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              canCancel ? 'HUỶ ĐƠN ĐÃ ĐẨY' : 'NHẬN ĐƠN',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canCancel
                                  ? theme.colorScheme.error
                                  : beluDarkGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                      if (ride.status == BrokerRideStatus.findingDriver &&
                          !canAccept &&
                          !canCancel &&
                          !isAcceptedByMe) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: beluDarkGreen.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Đơn đang chờ tài xế nhận.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: beluDarkGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: beluMediumGreen),
          const SizedBox(width: 7),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRideLocationLine(String from, String to) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.radio_button_checked,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                from.trim().replaceFirst(RegExp(r'^-\s*'), ''),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 7.5),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                to.trim().replaceFirst(RegExp(r'^-\s*'), ''),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    final disabled =
        _accessToken.isEmpty || provider.isSending || provider.groupId == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, -3),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_accessToken.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isOpeningCreateRide
                    ? null
                    : () => _openCreateRide(provider),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: beluDarkGreen.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_business_rounded,
                    color: beluDarkGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _inputFocused ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _inputFocused ? beluMediumGreen : Colors.grey.shade200,
                  width: _inputFocused ? 1.5 : 1,
                ),
                boxShadow: _inputFocused
                    ? [
                        BoxShadow(
                          color: beluDarkGreen.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                minLines: 1,
                enabled: !disabled,
                cursorColor: beluDarkGreen,
                style: const TextStyle(color: Colors.black87, fontSize: 14.5),
                onSubmitted: (_) => _handleSendMessage(),
                decoration: InputDecoration(
                  hintText: provider.groupId == null
                      ? 'Nhóm chat chưa sẵn sàng'
                      : (provider.isSending
                            ? 'Đang gửi...'
                            : 'Nhập tin nhắn...'),
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: disabled
                  ? null
                  : const LinearGradient(
                      colors: [beluMediumGreen, beluDarkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: disabled ? Colors.grey.shade300 : null,
              boxShadow: disabled
                  ? []
                  : [
                      BoxShadow(
                        color: beluDarkGreen.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: disabled ? null : _handleSendMessage,
                child: Center(
                  child: provider.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _formatTime(DateTime time) =>
      DateFormat('HH:mm').format(time.toLocal());

  String _formatFullTime(DateTime time) {
    return DateFormat('HH:mm dd/MM/yyyy').format(time.toLocal());
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  Color _statusColor(int status) {
    switch (status) {
      case BrokerRideStatus.findingDriver:
        return Colors.blue.shade700;
      case BrokerRideStatus.accepted:
        return Colors.orange.shade700;
      case BrokerRideStatus.inProgress:
        return Colors.teal.shade700;
      case BrokerRideStatus.completed:
        return Colors.green.shade700;
      case BrokerRideStatus.cancelled:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _statusText(int status) {
    switch (status) {
      case BrokerRideStatus.findingDriver:
        return 'CHƯA NHẬN';
      case BrokerRideStatus.accepted:
        return 'ĐANG XỬ LÝ';
      case BrokerRideStatus.inProgress:
        return 'ĐÃ NHẬN';
      case BrokerRideStatus.completed:
        return 'HOÀN THÀNH';
      case BrokerRideStatus.cancelled:
        return 'ĐÃ HỦY';
      default:
        return 'KHÁC';
    }
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF145E44),
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0A422D).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF0A422D)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: Colors.black87),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A422D),
                backgroundColor: const Color(
                  0xFF0A422D,
                ).withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  String _label() {
    final d = date.toLocal();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hôm nay';
    }
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Hôm qua';
    }
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: Color(0xFFD0D8D4), thickness: 1),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A422D).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF0A422D),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(color: Color(0xFFD0D8D4), thickness: 1),
          ),
        ],
      ),
    );
  }
}

class _LoadingOlderBanner extends StatelessWidget {
  const _LoadingOlderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF145E44),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Đang tải tin nhắn cũ...',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
