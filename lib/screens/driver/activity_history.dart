import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/driver/ride_model.dart'; // Đã thêm import model
import 'ride_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Thay đổi kiểu dữ liệu sang RideModel
  List<RideModel> ongoingRides = [];
  List<RideModel> historyRides = [];
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      // Gọi đồng thời 2 API để tối ưu tốc độ load
      final responses = await Future.wait([
        ApiService.getProcessingRides(accessToken: token),
        ApiService.getRideHistory(accessToken: token),
      ]);

      // Xử lý TAB ĐANG DIỄN RA
      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body);
        if (body['success'] == true) {
          ongoingRides = (body['data'] as List)
              .map((e) => RideModel.fromJson(e))
              .toList();
        }
      }

      // Xử lý TAB LỊCH SỬ
      if (responses[1].statusCode == 200) {
        final body = jsonDecode(responses[1].body);
        if (body['success'] == true) {
          historyRides = (body['data'] as List)
              .map((e) => RideModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("🔥 Fetch rides error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // XỬ LÝ HOÀN THÀNH CHUYẾN XE
  // ======================
  Future<void> _handleCompleteRide(int rideId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.completeRide(accessToken: token, rideId: rideId);

    if (mounted) Navigator.pop(context); // Đóng loading

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chuyến xe $code đã hoàn thành!"), backgroundColor: Colors.green),
      );
      _fetchRides(); // Tải lại danh sách
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể cập nhật trạng thái."), backgroundColor: Colors.red),
      );
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

  Widget _buildList(List<RideModel> rides, ThemeData theme) {
    if (rides.isEmpty) return const Center(child: Text("Không có dữ liệu chuyến xe"));

    return RefreshIndicator(
      onRefresh: _fetchRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rides.length,
        itemBuilder: (context, index) => _buildRideCard(rides[index], theme),
      ),
    );
  }

  Widget _buildRideCard(RideModel ride, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(ride.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Row sử dụng getter từ Model
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ride.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ride.statusText,
                      style: TextStyle(color: ride.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildLocationLine(ride.fromAddress, ride.toAddress),
              const SizedBox(height: 16),

              // Info & Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride.code, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(ride.paymentMethod, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Text(
                    ride.formattedPrice,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),

              // Kiểm tra status trực tiếp bằng số int từ Model
              if (ride.status == 3) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteRide(ride.id, ride.code),
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