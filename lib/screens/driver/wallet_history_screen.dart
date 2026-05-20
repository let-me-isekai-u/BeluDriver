import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../providers/driver/wallet_history_provider.dart';
import '../../widgets/driver_ui.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletHistoryProvider()..fetchData(),
      child: const _WalletHistoryView(),
    );
  }
}

class _WalletHistoryView extends StatelessWidget {
  const _WalletHistoryView();

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
    final provider = context.watch<WalletHistoryProvider>();

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
            onPressed: provider.fetchData,
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
            onRefresh: provider.fetchData,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildBalanceHero(theme, provider.currentBalance),
                const SizedBox(height: 16),
                _buildSummaryRow(theme, provider.transactions),
                const SizedBox(height: 16),
                if (provider.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 72),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  )
                else if (provider.errorMessage != null)
                  _buildErrorWidget(theme, provider)
                else if (provider.transactions.isEmpty)
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
                      children: provider.transactions
                          .map(
                            (item) => Padding(
                              padding: EdgeInsets.only(
                                bottom: item == provider.transactions.last
                                    ? 0
                                    : 12,
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

  Widget _buildBalanceHero(ThemeData theme, String currentBalance) {
    final balance = num.tryParse(currentBalance) ?? 0;

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

  Widget _buildSummaryRow(ThemeData theme, List<dynamic> transactions) {
    final incoming = transactions.fold<num>(
      0,
      (sum, item) =>
          sum +
          (((item['amount'] ?? 0) as num) > 0 ? item['amount'] as num : 0),
    );
    final outgoing = transactions.fold<num>(
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
            value: transactions.length.toString(),
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

  Widget _buildErrorWidget(
    ThemeData theme,
    WalletHistoryProvider provider,
  ) {
    return DriverSectionCard(
      title: "Không thể tải dữ liệu",
      subtitle: "Bạn có thể thử lại sau ít phút.",
      icon: Icons.error_outline_rounded,
      child: Column(
        children: [
          Text(
            provider.errorMessage ?? "Đã có lỗi xảy ra",
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
              onPressed: provider.fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Tải lại dữ liệu"),
            ),
          ),
        ],
      ),
    );
  }
}
