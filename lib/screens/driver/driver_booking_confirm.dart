import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/broker_ride_models.dart';
import '../../services/api_service.dart';
import '../popup_list/action_success_popup.dart';

class DriverBookingConfirmScreen extends StatefulWidget {
  final CreateBrokerRideRequest request;
  final VoidCallback? onGoToPushedOrdersTab;

  const DriverBookingConfirmScreen({
    super.key,
    required this.request,
    this.onGoToPushedOrdersTab,
  });

  @override
  State<DriverBookingConfirmScreen> createState() =>
      _DriverBookingConfirmScreenState();
}

class _DriverBookingConfirmScreenState
    extends State<DriverBookingConfirmScreen> {
  bool _isCreatingRide = false;

  String formatCurrency(num value) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    num amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            Divider(
              height: 20,
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.3),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  String _extractMessage(String raw, int statusCode) {
    if (statusCode == 502) {
      return "Không thể lấy địa chỉ, vui lòng thử lại";
    }

    try {
      final parsed = CreateBrokerRideResponse.fromRawJson(raw);
      if (parsed.message != null && parsed.message!.trim().isNotEmpty) {
        return parsed.message!.trim();
      }
    } catch (_) {}

    return "Tạo/đẩy đơn thất bại";
  }

  Future<void> _handleCreateBrokerRide() async {
    setState(() => _isCreatingRide = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa đăng nhập'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCreatingRide = false);
      }
      return;
    }

    try {
      final req = widget.request;
      final res = await ApiService.createBrokerRide(
        accessToken: token,
        from: req.from,
        to: req.to,
        type: req.type,
        customerName: req.customerName,
        customerPhone: req.customerPhone,
        quantity: req.normalizedQuantity,
        pickupTime: req.pickupTime,
        offerPrice: req.offerPrice,
        creatorEarn: req.creatorEarn,
        note: req.note,
        groupId: req.groupId,
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = CreateBrokerRideResponse.fromRawJson(res.body);
        if (parsed.success) {
          await ActionSuccessPopup.show(
            context,
            title: req.groupId != null
                ? 'Đẩy đơn thành công'
                : 'Tạo đơn thành công',
            message: req.groupId != null
                ? 'Đơn của bạn đã được tạo và đẩy vào nhóm chat thành công.'
                : 'Đơn của bạn đã được tạo thành công.',
          );
          if (!mounted) return;
          widget.onGoToPushedOrdersTab?.call();
          Navigator.pop(context, true);
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractMessage(res.body, res.statusCode)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCreatingRide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;
    final rideTypeLabel = BrokerRideType.labelOf(req.type);
    final DateTime? pickupDt = DateTime.tryParse(req.pickupTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xác nhận đẩy đơn',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: "Thông tin đơn",
              icon: Icons.info_outline,
              children: [
                _buildInfoRow("Loại chuyến:", rideTypeLabel),
                if (BrokerRideType.requiresPassengerQuantity(req.type))
                  _buildInfoRow(
                    "${BrokerRideType.quantityLabelOf(req.type)}:",
                    req.normalizedQuantity.toString(),
                  ),
                _buildInfoRow("Tên khách:", req.customerName),
                _buildInfoRow("SĐT khách:", req.customerPhone),
                if (req.note.trim().isNotEmpty)
                  _buildInfoRow("Ghi chú:", req.note),
                _buildInfoRow(
                  "Giờ đón:",
                  pickupDt == null
                      ? req.pickupTime
                      : "${DateFormat('dd/MM/yyyy').format(pickupDt)} - ${DateFormat('HH:mm').format(pickupDt)}",
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Điểm đón",
              icon: Icons.my_location,
              children: [
                _buildInfoRow("Địa chỉ đã chọn:", req.fromDisplayAddress),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Điểm đến",
              icon: Icons.location_on,
              children: [
                _buildInfoRow("Địa chỉ đã chọn:", req.toDisplayAddress),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Giá",
              icon: Icons.payments_outlined,
              children: [
                _buildPriceRow(
                  "Giá chào:",
                  req.offerPrice,
                  isBold: true,
                  color: theme.colorScheme.secondary,
                ),
                _buildPriceRow("Tiền nhận:", req.creatorEarn),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isCreatingRide
                    ? null
                    : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "QUAY LẠI",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isCreatingRide ? null : _handleCreateBrokerRide,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.black87,
                ),
                child: _isCreatingRide
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black87,
                        ),
                      )
                    : const Text(
                        "TẠO CHUYẾN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
