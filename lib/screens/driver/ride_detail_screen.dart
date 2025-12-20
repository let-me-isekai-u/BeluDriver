import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RideDetailScreen extends StatefulWidget {
  final int rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideDetail();
  }

  // Lấy chi tiết chuyến đi từ API
  Future<void> _fetchRideDetail() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getRideDetail(accessToken: token, rideId: widget.rideId);

      print("📥 DETAIL BODY: ${res.body}");

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() => _rideData = body['data']);
        } else {
          setState(() => _rideData = null);
        }
      }
    } catch (e) {
      debugPrint("🔥 Lỗi fetch detail: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Xử lý Bắt đầu di chuyển
  Future<void> _handleStartRide() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.startRide(accessToken: token, rideId: widget.rideId);

    if (res.statusCode == 200) {
      _showSnackBar("Đã bắt đầu chuyến đi", Colors.green);
      _fetchRideDetail(); // Tải lại để cập nhật status lên 3
    } else {
      _showSnackBar("Không thể bắt đầu chuyến đi", Colors.red);
    }
  }

  // Xử lý Hoàn thành chuyến đi
  Future<void> _handleCompleteRide() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.completeRide(accessToken: token, rideId: widget.rideId);

    if (res.statusCode == 200) {
      _showSnackBar("Đã hoàn thành chuyến đi", Colors.green);
      _fetchRideDetail(); // Tải lại để cập nhật status lên 4
    } else {
      _showSnackBar("Không thể hoàn thành chuyến đi", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Map màu sắc cho trạng thái (Server trả về 2, 3, 4...)
  Map<String, dynamic> _getStatusInfo(int status) {
    switch (status) {
      case 2: return {"text": "Đã nhận đơn", "color": Colors.blue};
      case 3: return {"text": "Đang di chuyển", "color": Colors.orange};
      case 4: return {"text": "Hoàn thành", "color": Colors.green};
      case 5: return {"text": "Đã hủy", "color": Colors.red};
      default: return {"text": "Chờ xác nhận", "color": Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_rideData == null) return const Scaffold(body: Center(child: Text("Không tìm thấy thông tin")));

    final statusInfo = _getStatusInfo(_rideData!['status']);
    final theme = Theme.of(context);
    final String customerName = _rideData!['customerName'] ?? 'Khách hàng';
    final String customerPhone = _rideData!['customerPhone'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Mã đơn: ${_rideData!['code']}"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header: Giá tiền và Trạng thái
            _buildHeaderSummary(statusInfo),

            // 2. Card: Thông tin khách hàng
            _buildInfoCard(
              title: "Thông tin khách hàng",
              icon: Icons.person_outline,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(customerName.isNotEmpty ? customerName[0] : 'K'),
                ),
                title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(customerPhone.isNotEmpty ? customerPhone : "BeluCar Customer"),
                trailing: IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green, size: 28),
                  onPressed: () async {
                    if (customerPhone.isEmpty) {
                      _showSnackBar("Không có số điện thoại", Colors.red);
                      return;
                    }
                    final uri = Uri.parse('tel:$customerPhone');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
              ),
            ),

            // 3. Card: Lộ trình di chuyển
            _buildInfoCard(
              title: "Lộ trình",
              icon: Icons.route_outlined,
              child: Column(
                children: [
                  _buildLocationStep(
                      Icons.radio_button_checked,
                      Colors.green,
                      "Điểm đón",
                      "${_rideData!['fromAddress']}, ${_rideData!['fromDistrict']}, ${_rideData!['fromProvince']}"
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 11),
                    child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.more_vert, size: 16, color: Colors.grey)),
                  ),
                  _buildLocationStep(
                      Icons.location_on,
                      Colors.red,
                      "Điểm đến",
                      "${_rideData!['toAddress']}, ${_rideData!['toDistrict']}, ${_rideData!['toProvince']}"
                  ),
                ],
              ),
            ),

            // 4. Card: Chi tiết bổ sung (Thêm PaymentMethod)
            _buildInfoCard(
              title: "Chi tiết bổ sung",
              icon: Icons.info_outline,
              child: Column(
                children: [
                  _buildDetailRow("Loại dịch vụ", "Chuyến xe #${_rideData!['type']}"),
                  _buildDetailRow("Thanh toán", _rideData!['paymentMethod'] ?? "Tiền mặt"),
                  _buildDetailRow("Thời gian đón", _formatDate(_rideData!['pickupTime'])),
                  _buildDetailRow("Ghi chú", _rideData!['note'] ?? "Không có ghi chú", isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      // 5. Nút bấm hành động dưới đáy màn hình
      bottomSheet: _rideData!['status'] >= 4
          ? null
          : _buildBottomActions(statusInfo['text'], _rideData!['status']),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "---";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('HH:mm - dd/MM/yyyy').format(date);
    } catch (_) { return dateStr; }
  }

  Widget _buildHeaderSummary(Map<String, dynamic> statusInfo) {
    final price = _rideData!['price'] ?? 0;
    final formattedPrice = NumberFormat("#,###").format(price);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("$formattedPrice đ", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: statusInfo['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(statusInfo['text'], style: TextStyle(color: statusInfo['color'], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildLocationStep(IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildBottomActions(String statusText, int status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => status == 2 ? _handleStartRide() : _handleCompleteRide(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: status == 2 ? Colors.blue : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
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