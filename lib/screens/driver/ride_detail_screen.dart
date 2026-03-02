import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../models/driver/ride_detail_model.dart';
import '../../dashed_line_vertical.dart';

class RideDetailScreen extends StatefulWidget {
  final int rideId;
  final int rideSource;

  const RideDetailScreen({
    super.key,
    required this.rideId,
    required this.rideSource,
  });

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  RideDetailModel? _ride;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideDetail();
  }

  String get _rideSourceText {
    // 1 = hệ thống BeluCar, 2 = đơn chia sẻ/đơn đẩy
    switch (widget.rideSource) {
      case 1:
        return "Đơn BeluCar";
      case 2:
        return "Đơn chia sẻ";
      default:
        return "Không xác định";
    }
  }

  Color get _rideSourceColor {
    switch (widget.rideSource) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchRideDetail() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getRideDetail(
        accessToken: token,
        rideId: widget.rideId,
        rideSource: widget.rideSource,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          if (!mounted) return;
          setState(() => _ride = RideDetailModel.fromJson(body['data']));
        } else {
          if (!mounted) return;
          setState(() => _ride = null);
        }
      }
    } catch (e) {
      debugPrint("🔥 Lỗi fetch detail: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStartRide() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: widget.rideId,
      rideSource: widget.rideSource,
    );

    if (res.statusCode == 200) {
      _showSnackBar("Đã bắt đầu chuyến đi", Colors.green);
      _fetchRideDetail();
    } else {
      _showSnackBar("Không thể bắt đầu chuyến đi", Colors.red);
    }
  }

  Future<void> _handleCompleteRide() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.completeRide(
      accessToken: token,
      rideId: widget.rideId,
      rideSource: widget.rideSource,
    );

    if (res.statusCode == 200) {
      _showSnackBar("Đã hoàn thành chuyến đi", Colors.green);
      _fetchRideDetail();
    } else {
      _showSnackBar("Không thể hoàn thành chuyến đi", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Map<String, dynamic> _getStatusInfo(int status) {
    switch (status) {
      case 2:
        return {"text": "Đã nhận đơn", "color": Colors.blue};
      case 3:
        return {"text": "Đang di chuyển", "color": Colors.orange};
      case 4:
        return {"text": "Hoàn thành", "color": Colors.green};
      case 5:
        return {"text": "Đã hủy", "color": Colors.red};
      default:
        return {"text": "Chờ xác nhận", "color": Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(theme, title: "Chi tiết chuyến xe"),
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.secondary),
        ),
      );
    }

    if (_ride == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(theme, title: "Chi tiết chuyến xe"),
        body: Center(
          child: Text(
            "Không tìm thấy thông tin",
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    final statusInfo = _getStatusInfo(_ride!.status);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(theme, title: "Mã đơn: ${_ride!.code}"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(statusInfo, theme),
            const SizedBox(height: 16),
            _buildPriceDetailCard(theme),
            const SizedBox(height: 16),
            _buildCustomerCard(theme),
            const SizedBox(height: 16),
            _buildRouteCard(theme),
            const SizedBox(height: 16),
            _buildExtraInfoCard(theme),
            const SizedBox(height: 110),
          ],
        ),
      ),
      bottomSheet: _ride!.status >= 4 ? null : _buildBottomActions(_ride!.status),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, {required String title}) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: theme.colorScheme.primary,
      iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      foregroundColor: theme.colorScheme.secondary,
    );
  }

  Widget _themedCard({required Widget child, EdgeInsets? padding}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildStatusHeader(Map<String, dynamic> statusInfo, ThemeData theme) {
    final Color statusColor = statusInfo['color'] as Color;

    return Card(
      elevation: 3,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Mã chuyến: ${_ride!.code}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _rideSourceColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _rideSourceColor.withOpacity(0.35)),
              ),
              child: Text(
                _rideSourceText,
                style: TextStyle(
                  color: _rideSourceColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  (statusInfo['text'] as String).toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDetailCard(ThemeData theme) {
    final formattedPrice = NumberFormat("#,###").format(_ride!.price);

    return _themedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Giá cước",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          Divider(height: 24, color: theme.colorScheme.onSurface.withOpacity(0.12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tổng thanh toán",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                "$formattedPrice đ",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(ThemeData theme) {
    return _themedCard(
      padding: const EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
          child: Text(
            _ride!.customerName.isNotEmpty ? _ride!.customerName[0] : '?',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _ride!.customerName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          _ride!.customerPhone.isNotEmpty ? _ride!.customerPhone : "BeluCar Customer",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green, size: 28),
          onPressed: () async {
            if (_ride!.customerPhone.isEmpty) {
              _showSnackBar("Không có số điện thoại", Colors.red);
              return;
            }
            final uri = Uri.parse('tel:${_ride!.customerPhone}');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        ),
      ),
    );
  }

  Widget _buildRouteCard(ThemeData theme) {
    return _themedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Icon(Icons.circle, color: Colors.green, size: 18),
              DashedLineVertical(height: 40, color: theme.colorScheme.secondary),
              const Icon(Icons.location_on, color: Colors.red, size: 18),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _routePointText(
                  title: _ride!.fromProvince,
                  district: _ride!.fromDistrict,
                  address: _ride!.fromAddress,
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _routePointText(
                  title: _ride!.toProvince,
                  district: _ride!.toDistrict,
                  address: _ride!.toAddress,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routePointText({
    required String title,
    required String district,
    required String address,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title - $district",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(
          address,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildExtraInfoCard(ThemeData theme) {
    return _themedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chi tiết bổ sung",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          Divider(height: 20, color: theme.colorScheme.onSurface.withOpacity(0.12)),
          _detailRow("Loại dịch vụ", _ride!.typeText, theme),
          _detailRow("Nguồn đơn", _rideSourceText, theme),
          _detailRow("Số lượng", _ride!.quantity.toString(), theme),
          _detailRow("Thanh toán", _ride!.paymentMethod, theme),
          _detailRow("Thời gian tạo", _formatDate(_ride!.createdAt), theme),
          _detailRow("Thời gian đón", _formatDate(_ride!.pickupTime), theme),
          _detailRow("Ghi chú", _ride!.note ?? "Không có ghi chú", theme, isLast: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(color: theme.colorScheme.onSurface),
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

  Widget _buildBottomActions(int status) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => status == 2 ? _handleStartRide() : _handleCompleteRide(),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 2 ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                status == 2 ? "BẮT ĐẦU DI CHUYỂN" : "XÁC NHẬN HOÀN THÀNH",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}