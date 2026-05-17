import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentBalance = "0";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = "Phiên đăng nhập đã hết hạn.";
          _isLoading = false;
        });
        return;
      }

      final profileRes = await ApiService.getDriverProfile(accessToken: token);
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        final dynamic wallet = profileData['wallet'];
        if (wallet is num) {
          _currentBalance = wallet.toStringAsFixed(0);
        } else {
          _currentBalance = (double.tryParse(wallet?.toString() ?? '') ?? 0)
              .toStringAsFixed(0);
        }
      }

      final historyRes = await ApiService.getWalletHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final Map<String, dynamic> historyData = jsonDecode(historyRes.body);
        if (historyData['success'] == true) {
          _transactions = historyData['data'] ?? [];
        }
      } else {
        _errorMessage = "Lỗi tải lịch sử giao dịch (${historyRes.statusCode})";
      }
    } catch (e) {
      _errorMessage = "Đã xảy ra lỗi: $e";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "--:--";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Lịch sử tài chính",
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
        actions: [
          IconButton(
            tooltip: "Làm mới",
            onPressed: _fetchData,
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildBalanceHero(theme),
                const SizedBox(height: 16),
                _buildSummaryRow(theme),
                const SizedBox(height: 16),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 72),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorWidget(theme)
                else if (_transactions.isEmpty)
                  const DriverSectionCard(
                    title: "Chưa có giao dịch",
                    subtitle: "Các biến động số dư sẽ hiển thị tại đây.",
                    icon: Icons.receipt_long_rounded,
                    child: DriverEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Ví của bạn chưa phát sinh giao dịch",
                      message:
                          "Khi có nạp tiền, rút tiền hoặc điều chỉnh số dư, hệ thống sẽ cập nhật trong danh sách này.",
                    ),
                  )
                else
                  DriverSectionCard(
                    title: "Biến động số dư",
                    subtitle:
                        "Theo dõi các khoản cộng và trừ để kiểm soát ví tài xế.",
                    icon: Icons.swap_vert_rounded,
                    child: Column(
                      children: _transactions
                          .map(
                            (item) => Padding(
                              padding: EdgeInsets.only(
                                bottom: item == _transactions.last ? 0 : 12,
                              ),
                              child: _buildTransactionCard(theme, item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHero(ThemeData theme) {
    final balance = num.tryParse(_currentBalance) ?? 0;

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
            label: "Ví tài xế",
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            "Số dư khả dụng",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMoney(balance),
            style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 10),
          Text(
            "Kiểm tra lịch sử để nắm rõ toàn bộ dòng tiền vào ra của tài khoản.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtle,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme) {
    final incoming = _transactions.fold<num>(
      0,
      (sum, item) =>
          sum +
          (((item['amount'] ?? 0) as num) > 0 ? item['amount'] as num : 0),
    );
    final outgoing = _transactions.fold<num>(
      0,
      (sum, item) =>
          sum +
          (((item['amount'] ?? 0) as num) < 0
              ? (item['amount'] as num).abs()
              : 0),
    );

    return Row(
      children: [
        Expanded(
          child: DriverStatTile(
            label: "Tổng cộng",
            value: _transactions.length.toString(),
            icon: Icons.receipt_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DriverStatTile(
            label: "Tiền vào",
            value: _formatMoney(incoming),
            icon: Icons.add_circle_outline_rounded,
            accentColor: const Color(0xFF6ED39B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DriverStatTile(
            label: "Tiền ra",
            value: _formatMoney(outgoing),
            icon: Icons.remove_circle_outline_rounded,
            accentColor: const Color(0xFFFF9A9A),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(ThemeData theme, dynamic item) {
    final num amount = item['amount'] ?? 0;
    final bool isNegative = amount < 0;
    final Color accent = isNegative
        ? const Color(0xFFFF9A9A)
        : const Color(0xFF6ED39B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isNegative ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['type']?.toString().trim().isNotEmpty == true
                      ? item['type'].toString()
                      : "Giao dịch ví",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(item['createdDate']?.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isNegative ? '-' : '+'}${_formatMoney(amount.abs())}",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isNegative ? "Giảm số dư" : "Tăng số dư",
                style: theme.textTheme.bodySmall?.copyWith(color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return DriverSectionCard(
      title: "Không thể tải dữ liệu",
      subtitle: "Bạn có thể thử lại sau ít phút.",
      icon: Icons.error_outline_rounded,
      child: Column(
        children: [
          Text(
            _errorMessage ?? "Đã có lỗi xảy ra",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFFFA3A3),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Tải lại dữ liệu"),
            ),
          ),
        ],
      ),
    );
  }
}
