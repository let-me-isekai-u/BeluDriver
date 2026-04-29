import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_chat_service.dart';
import 'chat_screen.dart';

class DriverChatGroupListScreen extends StatefulWidget {
  const DriverChatGroupListScreen({super.key});

  @override
  State<DriverChatGroupListScreen> createState() =>
      _DriverChatGroupListScreenState();
}

class _DriverChatGroupListScreenState extends State<DriverChatGroupListScreen> {
  static const Color beluDarkGreen = Color(0xFF0A422D);
  static const Color beluMediumGreen = Color(0xFF145E44);
  static const Color beluAccentGold = Color(0xFFFFD700);
  static const Color bgCanvas = Color(0xFFF0F4F2);

  late final ApiChatService _chatService = ApiChatService(
    tokenProvider: _readAccessToken,
  );

  List<DriverChatGroupDto> _groups = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _accessToken = '';

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _loadGroups({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final token = await _readAccessToken() ?? '';

    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _accessToken = '';
        _groups = const [];
        _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    try {
      final groups = await _chatService.getDriverGroups();
      if (!mounted) return;

      final sortedGroups = [...groups]
        ..sort((a, b) {
          if (a.isActive != b.isActive) {
            return a.isActive ? -1 : 1;
          }

          final aTime = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      setState(() {
        _accessToken = token;
        _groups = sortedGroups;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accessToken = token;
        _error = 'Không thể tải danh sách nhóm chat.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _openGroup(DriverChatGroupDto group) async {
    if (!group.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhóm chat này hiện không hoạt động.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverGroupChatScreen(initialGroup: group),
      ),
    );

    if (!mounted) return;
    await _loadGroups(refresh: true);
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return '';

    final local = time.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (isToday) {
      return DateFormat('HH:mm').format(local);
    }

    return DateFormat('dd/MM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCanvas,
      appBar: AppBar(
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
        title: const Text(
          'Nhóm Chat Tuyến',
          style: TextStyle(color: beluAccentGold, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: beluMediumGreen,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_accessToken.isEmpty) {
      return _InfoState(
        icon: Icons.lock_outline_rounded,
        title: 'Chưa đăng nhập',
        subtitle: _error ?? 'Phiên đăng nhập đã hết hạn.',
        onRetry: () => _loadGroups(),
      );
    }

    if (_error != null && _groups.isEmpty) {
      return _InfoState(
        icon: Icons.wifi_off_rounded,
        title: 'Không tải được nhóm chat',
        subtitle: _error!,
        onRetry: () => _loadGroups(),
      );
    }

    if (_groups.isEmpty) {
      return RefreshIndicator(
        color: beluMediumGreen,
        onRefresh: () => _loadGroups(refresh: true),
        child: ListView(children: const [SizedBox(height: 120), _EmptyState()]),
      );
    }

    return RefreshIndicator(
      color: beluMediumGreen,
      onRefresh: () => _loadGroups(refresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _groups.length + (_isRefreshing ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_isRefreshing && index == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: beluMediumGreen,
                ),
              ),
            );
          }

          final group = _groups[_isRefreshing ? index - 1 : index];
          return _GroupCard(
            group: group,
            timeLabel: _formatLastMessageTime(group.lastMessageAt),
            onTap: () => _openGroup(group),
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.timeLabel,
    required this.onTap,
  });

  final DriverChatGroupDto group;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = group.isActive;
    final title = group.name?.trim().isNotEmpty == true
        ? group.name!.trim()
        : 'Nhóm chat tài xế';
    final provinceName = group.provinceName?.trim();
    final subtitle = group.description?.trim();
    final preview = group.lastMessagePreview?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF145E44).withValues(alpha: 0.16)
                  : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFF145E44).withValues(alpha: 0.10)
                      : Colors.grey.shade200,
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: isActive ? const Color(0xFF145E44) : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (provinceName != null && provinceName.isNotEmpty)
                          _ChipLabel(
                            icon: Icons.route_rounded,
                            label: provinceName,
                            fg: const Color(0xFF145E44),
                            bg: const Color(0xFF145E44).withValues(alpha: 0.10),
                          ),
                        _ChipLabel(
                          icon: isActive
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_rounded,
                          label: isActive
                              ? 'Đang hoạt động'
                              : 'Không hoạt động',
                          fg: isActive ? Colors.green.shade700 : Colors.grey,
                          bg: isActive
                              ? Colors.green.shade50
                              : Colors.grey.shade200,
                        ),
                      ],
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.8,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview == null || preview.isEmpty
                                ? 'Chưa có tin nhắn gần đây'
                                : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.8,
                              color: preview == null || preview.isEmpty
                                  ? Colors.black38
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (group.unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF145E44),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group.unreadCount > 99
                                  ? '99+'
                                  : '${group.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

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
                color: const Color(0xFF145E44).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF145E44)),
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
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF145E44),
                backgroundColor: const Color(
                  0xFF145E44,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF145E44).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 34,
              color: Color(0xFF145E44),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chưa có nhóm chat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hiện chưa có nhóm chat tuyến nào theo các tỉnh bạn đã đăng ký.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
