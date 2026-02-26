import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/broker_ride_models.dart';
import '../../services/api_service.dart';

class DriverBookingConfirmScreen extends StatefulWidget {
  final CreateBrokerRideRequest request;

  final int fromProvinceId;
  final int toProvinceId;

  const DriverBookingConfirmScreen({
    super.key,
    required this.request,
    required this.fromProvinceId,
    required this.toProvinceId,
  });

  @override
  State<DriverBookingConfirmScreen> createState() => _DriverBookingConfirmScreenState();
}

class _DriverBookingConfirmScreenState extends State<DriverBookingConfirmScreen> {
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

  Widget _buildTextPriceRow(
      String label,
      String value, {
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
            value,
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<String> _getProvinceName(int provinceId) async {
    try {
      final provinces = await ApiService.getProvinces();
      final p = provinces.cast<dynamic?>().firstWhere(
            (x) => x != null && x['id'].toString() == provinceId.toString(),
        orElse: () => null,
      );
      return p?['name']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _getDistrictName(int provinceId, int districtId) async {
    try {
      final districts = await ApiService.getDistricts(provinceId: provinceId);
      final d = districts.cast<dynamic?>().firstWhere(
            (x) => x != null && x['id'].toString() == districtId.toString(),
        orElse: () => null,
      );
      return d?['name']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleCreateBrokerRide() async {
    setState(() => _isCreatingRide = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chưa đăng nhập'), backgroundColor: Colors.red),
        );
        setState(() => _isCreatingRide = false);
      }
      return;
    }

    try {
      final req = widget.request;

      final res = await ApiService.createBrokerRide(
        accessToken: token,
        fromDistrictId: req.fromDistrictId,
        toDistrictId: req.toDistrictId,
        fromAddress: req.fromAddress,
        toAddress: req.toAddress,
        type: req.type,
        customerPhone: req.customerPhone,
        quantity: req.quantity,
        pickupTime: req.pickupTime,
        offerPrice: req.offerPrice,
        creatorEarn: req.creatorEarn,
        note: req.note,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // backend trả: { success: true, data: { id, code, pickupTime, price } }
        final body = jsonDecode(res.body);
        final bool ok = body is Map && body['success'] == true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Tạo/đẩy đơn thành công' : 'Tạo/đẩy đơn thất bại'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );

        if (ok) {
          // Nếu bạn muốn quay lại tab trước hoặc home:
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tạo/đẩy đơn thất bại (${res.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingRide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;

    final DateTime? pickupDt = (() {
      try {
        return DateTime.parse(req.pickupTime);
      } catch (_) {
        return null;
      }
    })();

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
      body: FutureBuilder<_ConfirmLocationNames>(
        future: () async {
          final fromProvinceName = await _getProvinceName(widget.fromProvinceId);
          final toProvinceName = await _getProvinceName(widget.toProvinceId);

          final fromDistrictName =
          await _getDistrictName(widget.fromProvinceId, req.fromDistrictId);
          final toDistrictName = await _getDistrictName(widget.toProvinceId, req.toDistrictId);

          return _ConfirmLocationNames(
            fromProvinceName: fromProvinceName,
            fromDistrictName: fromDistrictName,
            toProvinceName: toProvinceName,
            toDistrictName: toDistrictName,
          );
        }(),
        builder: (context, snapshot) {
          final names = snapshot.data;

          final fromProvince = (names?.fromProvinceName ?? '').trim();
          final toProvince = (names?.toProvinceName ?? '').trim();

          final fromDistrict = (names?.fromDistrictName ?? '').trim().isNotEmpty
              ? names!.fromDistrictName
              : "ID: ${req.fromDistrictId}";
          final toDistrict = (names?.toDistrictName ?? '').trim().isNotEmpty
              ? names!.toDistrictName
              : "ID: ${req.toDistrictId}";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: "Thông tin đơn",
                  icon: Icons.info_outline,
                  children: [
                    _buildInfoRow("Số lượng:", req.quantity.toString()),
                    _buildInfoRow("SĐT khách:", req.customerPhone),
                    if (req.note.trim().isNotEmpty) _buildInfoRow("Ghi chú:", req.note),
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
                    if (fromProvince.isNotEmpty) _buildInfoRow("Tỉnh/Thành:", fromProvince),
                    _buildInfoRow("Quận/Huyện:", fromDistrict),
                    _buildInfoRow("Địa chỉ:", req.fromAddress),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: "Điểm đến",
                  icon: Icons.location_on,
                  children: [
                    if (toProvince.isNotEmpty) _buildInfoRow("Tỉnh/Thành:", toProvince),
                    _buildInfoRow("Quận/Huyện:", toDistrict),
                    _buildInfoRow("Địa chỉ:", req.toAddress),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: "Giá",
                  icon: Icons.payments_outlined,
                  children: [
                    _buildPriceRow("Giá chào:", req.offerPrice),
                    _buildPriceRow("Tiền nhận:", req.creatorEarn),
                    Divider(
                      height: 20,
                      color: theme.colorScheme.secondary.withOpacity(0.5),
                      thickness: 1.5,
                    ),
                    _buildTextPriceRow(
                      "Ghi chú:",
                      req.note.trim().isEmpty ? "Không có" : req.note.trim(),
                      isBold: true,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
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
                onPressed: _isCreatingRide ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: theme.colorScheme.secondary, width: 2),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmLocationNames {
  final String fromProvinceName;
  final String fromDistrictName;
  final String toProvinceName;
  final String toDistrictName;

  const _ConfirmLocationNames({
    required this.fromProvinceName,
    required this.fromDistrictName,
    required this.toProvinceName,
    required this.toDistrictName,
  });
}