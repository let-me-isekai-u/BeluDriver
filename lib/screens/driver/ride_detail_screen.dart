import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_theme.dart';
import '../../models/driver/ride_detail_model.dart';
import '../../providers/driver/ride_detail_provider.dart';
import '../../widgets/driver_ui.dart';

class RideDetailScreen extends StatelessWidget {
  final int rideId;
  final int rideSource;

  const RideDetailScreen({
    super.key,
    required this.rideId,
    required this.rideSource,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          RideDetailProvider(rideId: rideId, rideSource: rideSource)
            ..fetchRideDetail(),
      child: _RideDetailView(rideId: rideId, rideSource: rideSource),
    );
  }
}

class _RideDetailView extends StatelessWidget {
  const _RideDetailView({
    required this.rideId,
    required this.rideSource,
  });

  final int rideId;
  final int rideSource;

  String get _rideSourceText {
    switch (rideSource) {
      case 1:
        return "Đơn BeluCar";
      case 2:
        return "Đơn chia sẻ";
      default:
        return "Không xác định";
    }
  }

  Color get _rideSourceColor {
    switch (rideSource) {
      case 1:
        return const Color(0xFF73B7FF);
      case 2:
        return const Color(0xFFC49BFF);
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _getStatusInfo(int status) {
    switch (status) {
      case 2:
        return {"text": "Đã nhận đơn", "color": const Color(0xFF73B7FF)};
      case 3:
        return {"text": "Đang di chuyển", "color": const Color(0xFFFFB347)};
      case 4:
        return {"text": "Hoàn thành", "color": const Color(0xFF6ED39B)};
      case 5:
        return {"text": "Đã hủy", "color": const Color(0xFFFF7B7B)};
      default:
        return {"text": "Chờ xác nhận", "color": Colors.grey};
    }
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RideDetailProvider>();
    final ride = provider.ride;

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(theme, title: "Chi tiết chuyến"),
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.secondary),
        ),
      );
    }

    if (ride == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(theme, title: "Chi tiết chuyến"),
        body: const DriverEmptyState(
          icon: Icons.search_off_rounded,
          title: "Không tìm thấy chuyến xe",
          message: "Dữ liệu chuyến có thể đã thay đổi hoặc không còn khả dụng.",
        ),
      );
    }

    final statusInfo = _getStatusInfo(ride.status);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme, title: "Mã đơn ${ride.code}"),
      bottomNavigationBar: ride.status >= 4
          ? null
          : _buildBottomActions(context, ride.status),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
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
            onRefresh: provider.fetchRideDetail,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildHeroSection(theme, statusInfo, ride),
                const SizedBox(height: 16),
                _buildOverviewStats(theme, ride),
                const SizedBox(height: 16),
                _buildFareSection(theme, ride),
                const SizedBox(height: 16),
                _buildCustomerSection(context, theme, ride),
                const SizedBox(height: 16),
                _buildRouteSection(theme, ride),
                const SizedBox(height: 16),
                _buildDetailSection(theme, ride),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, {required String title}) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.secondary,
      iconTheme: IconThemeData(color: theme.colorScheme.secondary),
    );
  }

  Widget _buildHeroSection(
    ThemeData theme,
    Map<String, dynamic> statusInfo,
    RideDetailModel ride,
  ) {
    final statusColor = statusInfo['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.surfaceGreen.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DriverPill(
                      label: "Chi tiết chuyến xe",
                      icon: Icons.local_taxi_rounded,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ride.code,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Theo dõi trạng thái, hành trình và thông tin khách hàng trong một màn hình.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubtle,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.flag_circle_rounded, color: statusColor),
                    const SizedBox(height: 6),
                    Text(
                      statusInfo['text'] as String,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DriverPill(label: _rideSourceText, color: _rideSourceColor),
              DriverPill(
                label: ride.paymentMethod.isEmpty
                    ? "Chưa rõ thanh toán"
                    : ride.paymentMethod,
                icon: Icons.payments_outlined,
              ),
              DriverPill(label: ride.typeText, icon: Icons.category_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats(ThemeData theme, RideDetailModel ride) {
    return Row(
      children: [
        Expanded(
          child: DriverStatTile(
            label: "Giá chuyến",
            value: _formatMoney(ride.price),
            icon: Icons.receipt_long_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DriverStatTile(
            label: "Thu nhập ròng",
            value: _formatMoney(ride.netIncome),
            icon: Icons.savings_rounded,
            accentColor: const Color(0xFF6ED39B),
          ),
        ),
      ],
    );
  }

  Widget _buildFareSection(ThemeData theme, RideDetailModel ride) {
    return DriverSectionCard(
      title: "Chi tiết cước phí",
      subtitle: "Tổng tiền khách trả và phần thu nhập thực nhận của tài xế.",
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _buildAmountRow(
            theme,
            label: "Giá chuyến",
            value: _formatMoney(ride.price),
            valueColor: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 14),
          _buildAmountRow(
            theme,
            label: "Thu nhập ròng",
            value: _formatMoney(ride.netIncome),
            valueColor: const Color(0xFF6ED39B),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    ThemeData theme, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(
    BuildContext context,
    ThemeData theme,
    RideDetailModel ride,
  ) {
    final phone = ride.customerPhone.trim();

    return DriverSectionCard(
      title: "Khách hàng",
      subtitle: "Thông tin liên hệ để hỗ trợ đón khách nhanh hơn.",
      icon: Icons.person_rounded,
      trailing: IconButton(
        tooltip: "Gọi khách",
        onPressed: () => _callCustomer(context, phone),
        icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.green),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.secondary.withValues(
              alpha: 0.14,
            ),
            child: Text(
              ride.customerName.isNotEmpty ? ride.customerName[0] : '?',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.customerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone.isEmpty ? "Chưa có số điện thoại" : phone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: phone.isEmpty
                        ? const Color(0xFFFFA3A3)
                        : AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callCustomer(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      _showSnackBar(context, "Không có số điện thoại", Colors.red);
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      _showSnackBar(context, "Không thể mở ứng dụng gọi điện", Colors.red);
    }
  }

  Widget _buildRouteSection(ThemeData theme, RideDetailModel ride) {
    return DriverSectionCard(
      title: "Lộ trình chuyến xe",
      subtitle:
          "Điểm đón và điểm trả được trình bày rõ theo thứ tự hành trình.",
      icon: Icons.alt_route_rounded,
      child: Column(
        children: [
          _buildRouteStop(
            theme,
            icon: Icons.trip_origin_rounded,
            color: const Color(0xFF6ED39B),
            label: "Điểm đón",
            title: "${ride.fromProvince} - ${ride.fromDistrict}",
            address: ride.fromAddress,
          ),
          Container(
            width: 2,
            height: 28,
            margin: const EdgeInsets.only(left: 11, top: 6, bottom: 6),
            color: theme.colorScheme.secondary.withValues(alpha: 0.25),
          ),
          _buildRouteStop(
            theme,
            icon: Icons.location_on_rounded,
            color: const Color(0xFFFF7B7B),
            label: "Điểm trả",
            title: "${ride.toProvince} - ${ride.toDistrict}",
            address: ride.toAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStop(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address.isEmpty ? "Chưa có địa chỉ chi tiết" : address,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(ThemeData theme, RideDetailModel ride) {
    return DriverSectionCard(
      title: "Thông tin bổ sung",
      subtitle: "Các dữ liệu vận hành quan trọng của chuyến xe.",
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _detailRow(theme, "Loại dịch vụ", ride.typeText),
          _detailRow(theme, "Nguồn đơn", _rideSourceText),
          _detailRow(theme, "Số lượng", ride.quantity.toString()),
          _detailRow(
            theme,
            "Thanh toán",
            ride.paymentMethod.isEmpty
                ? "Chưa xác định"
                : ride.paymentMethod,
          ),
          _detailRow(theme, "Thời gian tạo", _formatDate(ride.createdAt)),
          _detailRow(theme, "Thời gian đón", _formatDate(ride.pickupTime)),
          _detailRow(
            theme,
            "Số điện thoại khách",
            ride.customerPhone.trim().isEmpty
                ? "Chưa có dữ liệu"
                : ride.customerPhone.trim(),
          ),
          _detailRow(
            theme,
            "Ghi chú",
            (ride.note ?? '').trim().isEmpty
                ? "Không có ghi chú"
                : ride.note!,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "---";
    try {
      return DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildBottomActions(BuildContext context, int status) {
    final theme = Theme.of(context);
    final isStart = status == 2;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.16),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () async {
              final provider = context.read<RideDetailProvider>();
              final ok = isStart
                  ? await provider.startRide()
                  : await provider.completeRide();
              if (!context.mounted) return;
              _showSnackBar(
                context,
                ok
                    ? (isStart
                          ? "Đã bắt đầu chuyến đi"
                          : "Đã hoàn thành chuyến đi")
                    : (isStart
                          ? "Không thể bắt đầu chuyến đi"
                          : "Không thể hoàn thành chuyến đi"),
                ok ? Colors.green : Colors.red,
              );
            },
            icon: Icon(
              isStart ? Icons.play_circle_fill_rounded : Icons.task_alt_rounded,
            ),
            label: Text(isStart ? "Bắt đầu di chuyển" : "Xác nhận hoàn thành"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isStart
                  ? const Color(0xFF73B7FF)
                  : const Color(0xFF6ED39B),
              foregroundColor: Colors.black87,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
