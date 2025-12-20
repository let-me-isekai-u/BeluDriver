import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'ride_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> ongoingRides = [];
  List<Map<String, dynamic>> historyRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  // ======================
  // FETCH API
  // ======================
  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      // TAB ĐANG DIỄN RA
      final processingRes = await ApiService.getProcessingRides(accessToken: token);
      if (processingRes.statusCode == 200) {
        final body = jsonDecode(processingRes.body);
        if (body['success'] == true) {
          ongoingRides = _mapApiRides(body['data']);
        }
      }

      // TAB LỊCH SỬ
      final historyRes = await ApiService.getRideHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final body = jsonDecode(historyRes.body);
        if (body['success'] == true) {
          historyRides = _mapApiRides(body['data']);
        }
      }
    } catch (e) {
      debugPrint("🔥 Fetch rides error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ======================
  // XỬ LÝ HOÀN THÀNH CHUYẾN XE (NÚT ĐẾN NƠI)
  // ======================
  Future<void> _handleCompleteRide(int rideId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    // Hiển thị loading nhẹ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.completeRide(accessToken: token, rideId: rideId);

    // Đóng loading
    if (mounted) Navigator.pop(context);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chuyến xe $code đã hoàn thành!"), backgroundColor: Colors.green),
      );
      // Tải lại danh sách để chuyến xe chuyển từ tab Đang di chuyển sang Lịch sử
      _fetchRides();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể cập nhật trạng thái. Vui lòng thử lại!"), backgroundColor: Colors.red),
      );
    }
  }

  // ======================
  // MAP API → UI
  // ======================
  List<Map<String, dynamic>> _mapApiRides(List list) {
    return list.map<Map<String, dynamic>>((ride) {
      final int status = int.tryParse(ride['status'].toString()) ?? -1;

      return {
        "id": ride['rideId'],
        "code": ride['code'],
        "date": DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ride['createdAt'])),
        "from": "${ride['fromAddress']}, ${ride['fromDistrict']}",
        "to": "${ride['toAddress']}, ${ride['toProvince']}",
        "price": "${NumberFormat('#,###').format(ride['price'])}đ",
        "status": _getStatusText(status),
        "statusColor": _getStatusColor(status),
        "rawStatus": status, // Lưu lại số status để check hiển thị nút
        "paymentMethod": ride['paymentMethod'] ?? "Chưa xác định",
      };
    }).toList();
  }

  String _getStatusText(int status) {
    switch (status) {
      case 3: return "Đang di chuyển";
      case 4: return "Hoàn thành";
      case 5: return "Đã hủy";
      default: return "Không xác định";
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 3: return Colors.orange; // Đổi sang màu cam cho "đang đi" dễ nhìn hơn
      case 4: return Colors.green;
      case 5: return Colors.red;
      default: return Colors.grey;
    }
  }

  void _navigateToDetail(int rideId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)),
    ).then((_) => _fetchRides());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Hoạt động chuyến xe"),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "ĐANG DIỄN RA"),
              Tab(text: "LỊCH SỬ"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(ongoingRides, theme),
            _buildList(historyRides, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> rides, ThemeData theme) {
    if (rides.isEmpty) return const Center(child: Text("Không có dữ liệu chuyến xe"));

    return RefreshIndicator(
      onRefresh: _fetchRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return _buildRideCard(ride, theme);
        },
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(ride['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ride['date'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride['statusColor'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ride['status'],
                      style: TextStyle(color: ride['statusColor'], fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildLocationLine(ride['from'], ride['to']),
              const SizedBox(height: 16),

              // Info & Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride['code'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(ride['paymentMethod'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Text(
                    ride['price'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),

              // ======================
              // HIỂN THỊ NÚT ĐẾN NƠI NẾU STATUS = 3
              // ======================
              if (ride['rawStatus'] == 3) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteRide(ride['id'], ride['code']),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("XÁC NHẬN ĐẾN NƠI", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationLine(String from, String to) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Text(from, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 7.5),
            child: SizedBox(height: 12, child: VerticalDivider(width: 1, thickness: 1, color: Colors.grey)),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(to, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );
  }
}