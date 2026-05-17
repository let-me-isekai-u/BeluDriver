import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../models/driver/withdrawal_history_model.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  late Future<List<WithdrawalHistoryModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("hoàn thành") || s.contains("success")) {
      return const Color(0xFF6ED39B);
    }
    if (s.contains("đang xử lý") || s.contains("pending")) {
      return const Color(0xFFFFB347);
    }
    if (s.contains("từ chối") || s.contains("cancel") || s.contains("reject")) {
      return const Color(0xFFFF8A8A);
    }
    return Colors.grey;
  }

  String _formatDateTime(String dateStr) {
    if (dateStr.isEmpty) return "---";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<List<WithdrawalHistoryModel>> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getWithdrawalHistory(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => WithdrawalHistoryModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error loadHistory: $e");
      throw Exception("Không thể tải lịch sử rút tiền. Vui lòng thử lại!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Lịch sử rút tiền",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.secondary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<WithdrawalHistoryModel>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                  Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.14),
                  DriverSectionCard(
                    title: "Không thể tải lịch sử",
                    subtitle: "Kéo xuống để thử lại hoặc quay lại sau.",
                    icon: Icons.error_outline_rounded,
                    child: Text(
                      "Lỗi: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFFA3A3),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.14),
                  const DriverSectionCard(
                    title: "Chưa có yêu cầu rút tiền",
                    subtitle:
                        "Mọi yêu cầu rút tiền của bạn sẽ xuất hiện tại đây.",
                    icon: Icons.account_balance_wallet_outlined,
                    child: DriverEmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: "Danh sách đang trống",
                      message:
                          "Khi bạn gửi yêu cầu rút tiền, trạng thái xử lý và lý do từ chối nếu có sẽ được cập nhật ngay trong màn hình này.",
                    ),
                  ),
                ],
              );
            }

            final completedCount = list.where((item) {
              final status = item.status.toLowerCase();
              return status.contains("hoàn thành") ||
                  status.contains("success");
            }).length;

            final totalAmount = list.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );

            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildHero(theme, list.length, completedCount, totalAmount),
                const SizedBox(height: 16),
                DriverSectionCard(
                  title: "Danh sách yêu cầu",
                  subtitle:
                      "Xem trạng thái từng lần rút tiền và các phản hồi từ hệ thống.",
                  icon: Icons.payments_outlined,
                  child: Column(
                    children: list
                        .map(
                          (item) => Padding(
                            padding: EdgeInsets.only(
                              bottom: item == list.last ? 0 : 12,
                            ),
                            child: _buildItemCard(theme, item),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(
    ThemeData theme,
    int totalCount,
    int completedCount,
    double totalAmount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.surfaceGreen.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DriverPill(
            label: "Theo dõi thanh toán",
            icon: Icons.currency_exchange_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            "Rút tiền về tài khoản",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Kiểm tra tiến độ xử lý từng yêu cầu và tổng số tiền đã gửi đi.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtle,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DriverStatTile(
                  label: "Yêu cầu",
                  value: totalCount.toString(),
                  icon: Icons.request_page_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DriverStatTile(
                  label: "Hoàn tất",
                  value: completedCount.toString(),
                  icon: Icons.task_alt_rounded,
                  accentColor: const Color(0xFF6ED39B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DriverStatTile(
                  label: "Tổng tiền",
                  value: _formatCurrency(totalAmount),
                  icon: Icons.savings_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ThemeData theme, WithdrawalHistoryModel item) {
    final statusColor = _getStatusColor(item.status);
    final currentStatus = item.status.toLowerCase();
    final isReject =
        currentStatus.contains("từ chối") ||
        currentStatus.contains("cancel") ||
        currentStatus.contains("reject");
    final hasReason = (item.reasonCancel?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(item.amount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(item.createDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (isReject && hasReason) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Lý do từ chối: ${item.reasonCancel}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
