import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/driver/wallet_history_provider.dart';
import '../../ui/ui.dart';

// Màu chữ cho tiền vào / tiền ra: đủ đậm để đọc rõ trên nền trắng.
const Color _kIncome = Brand.success;
const Color _kExpense = Brand.danger;

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

  DateTime? _parseDate(dynamic raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _formatTime(dynamic raw, DateTime? dt) {
    if (dt != null) return DateFormat('HH:mm').format(dt);
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? '--:--' : s;
  }

  String _dayLabel(DateTime? dt) {
    if (dt == null) return 'Không rõ ngày';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return DateFormat('dd/MM/yyyy').format(dt);
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
            color: Brand.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: Brand.navy),
        actions: [
          IconButton(
            tooltip: "Làm mới",
            onPressed: provider.fetchData,
            icon: Icon(
              Icons.refresh_rounded,
              color: Brand.navy,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetchData,
        color: Brand.navy,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _FadeSlideIn(
              index: 0,
              child: _buildBalanceHero(provider.currentBalance),
            ),
            const SizedBox(height: 12),
            _FadeSlideIn(
              index: 1,
              child: _buildSummaryCard(provider.transactions),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 56),
                child: Center(
                  child: CircularProgressIndicator(color: Brand.navy),
                ),
              )
            else if (provider.errorMessage != null)
              _buildErrorCard(provider)
            else if (provider.transactions.isEmpty)
                _buildEmptyCard()
              else
                _FadeSlideIn(
                  index: 2,
                  child: _buildTransactionList(provider.transactions),
                ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Thẻ số dư: chữ trắng / xanh nhạt trên nền navy để tương phản cao
  // ---------------------------------------------------------------------------

  Widget _buildBalanceHero(String currentBalance) {
    final balance = num.tryParse(currentBalance) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Brand.navy, Brand.b700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Brand.navy.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  "Ví tài xế",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Số dư khả dụng",
            style: TextStyle(
              color: Brand.b200,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatMoney(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Dòng tiền vào ra của tài khoản.",
            style: TextStyle(
              color: Brand.b200,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Thẻ tóm tắt: Tổng cộng / Tiền vào / Tiền ra
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(List<dynamic> transactions) {
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

    const divider = SizedBox(
      height: 38,
      child: VerticalDivider(width: 1, thickness: 1, color: Brand.line),
    );

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Brand.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: _SummaryCell(
                label: "Tổng cộng",
                value: transactions.length.toString(),
                color: Brand.ink,
              ),
            ),
            divider,
            Expanded(
              child: _SummaryCell(
                label: "Tiền vào",
                value: _formatMoney(incoming),
                color: _kIncome,
              ),
            ),
            divider,
            Expanded(
              child: _SummaryCell(
                label: "Tiền ra",
                value: _formatMoney(outgoing),
                color: _kExpense,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Danh sách giao dịch, nhóm theo ngày
  // ---------------------------------------------------------------------------

  Widget _buildTransactionList(List<dynamic> transactions) {
    final rows = <Widget>[];
    String? currentLabel;

    for (final item in transactions) {
      final dt = _parseDate(item['createdDate']);
      final label = _dayLabel(dt);

      if (label != currentLabel) {
        currentLabel = label;
        rows.add(_buildDayHeader(label));
      } else {
        rows.add(
          const Divider(
            height: 1,
            thickness: 1,
            indent: 70,
            endIndent: 16,
            color: Brand.lineSoft,
          ),
        );
      }
      rows.add(_buildTransactionRow(item, dt));
    }

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Brand.line),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildDayHeader(String label) {
    return Container(
      width: double.infinity,
      color: Brand.b50,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Text(
        label,
        style: TextStyle(
          color: Brand.navy,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTransactionRow(dynamic item, DateTime? dt) {
    final num amount = item['amount'] ?? 0;
    final bool isNegative = amount < 0;
    final Color accent = isNegative ? _kExpense : _kIncome;
    final title = item['type']?.toString().trim().isNotEmpty == true
        ? item['type'].toString()
        : "Giao dịch ví";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isNegative ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Brand.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(item['createdDate'], dt),
                  style: const TextStyle(
                    color: Brand.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isNegative ? '-' : '+'}${_formatMoney(amount.abs())}",
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isNegative ? "Giảm số dư" : "Tăng số dư",
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trạng thái rỗng / lỗi
  // ---------------------------------------------------------------------------

  Widget _buildEmptyCard() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Brand.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Brand.b50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: Brand.navy,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Ví của bạn chưa phát sinh giao dịch",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Brand.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Giao dịch ví sẽ hiện ở đây.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Brand.inkMuted,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(WalletHistoryProvider provider) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _kExpense.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kExpense.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _kExpense,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Không thể tải dữ liệu",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Brand.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.errorMessage ?? "Đã có lỗi xảy ra",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kExpense,
                fontSize: 13.5,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Brand.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Widget nhỏ
// =============================================================================

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Brand.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiệu ứng xuất hiện (fade + trượt lên) cho các khối nội dung.
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduce
          ? Duration.zero
          : Duration(milliseconds: 360 + index * 80),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}