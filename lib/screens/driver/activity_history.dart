import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/driver/ride_model.dart';
import 'ride_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<RideModel> ongoingRides = [];
  List<RideModel> historyRides = [];

  bool _isLoadingOngoing = false;
  bool _isLoadingHistory = false;
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Chỉ gọi API Đang diễn ra khi khởi tạo
    _fetchOngoingRides();

    // Lắng nghe sự kiện đổi tab để gọi API Lịch sử
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    // index == 1 là tab Lịch sử
    if (_tabController.index == 1 && !_isHistoryLoaded) {
      _fetchHistoryRides();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  // ======================
  // API TAB 1: ĐANG DIỄN RA
  // ======================
  Future<void> _fetchOngoingRides() async {
    if (!mounted) return;
    setState(() => _isLoadingOngoing = true);
    try {
      final token = await _getToken();
      final res = await ApiService.getProcessingRides(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            ongoingRides = (body['data'] as List).map((e) => RideModel.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("🔥 Fetch ongoing error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOngoing = false);
    }
  }

  // ======================
  // API TAB 2: LỊCH SỬ
  // ======================
  Future<void> _fetchHistoryRides() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      final token = await _getToken();
      final res = await ApiService.getRideHistory(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            historyRides = (body['data'] as List).map((e) => RideModel.fromJson(e)).toList();
            _isHistoryLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint("🔥 Fetch history error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ======================
  // LOGIC XỬ LÝ
  // ======================
  Future<void> _handleCompleteRide(int rideId, String code) async {
    final token = await _getToken();
    if (token.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.completeRide(accessToken: token, rideId: rideId);
    if (mounted) Navigator.pop(context);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chuyến xe $code đã hoàn thành!"), backgroundColor: Colors.green),
      );
      // Khi xong 1 chuyến, cần làm mới cả 2 tab để dữ liệu nhảy từ Ongoing sang History
      _fetchOngoingRides();
      _fetchHistoryRides();
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
    ).then((_) {
      _fetchOngoingRides();
      if (_isHistoryLoaded) _fetchHistoryRides();
    });
  }

  // ======================
  // UI CHÍNH
  // ======================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Hoạt động chuyến xe"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "ĐANG DIỄN RA"),
            Tab(text: "LỊCH SỬ"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngoingTab(theme),
          _buildHistoryTab(theme),
        ],
      ),
    );
  }

  Widget _buildOngoingTab(ThemeData theme) {
    if (_isLoadingOngoing) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchOngoingRides,
      child: _buildList(ongoingRides, theme),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    if (_isLoadingHistory) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchHistoryRides,
      child: _buildList(historyRides, theme),
    );
  }

  Widget _buildList(List<RideModel> rides, ThemeData theme) {
    if (rides.isEmpty) {
      return ListView( //trả về ListView để kéo được
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200), // Đẩy text xuống giữa
          Center(child: Text("Không có dữ liệu chuyến xe")),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn kéo được
      padding: const EdgeInsets.all(12),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(rides[index], theme),
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
              // Hiển thị thêm huyện: province - district - address
              _buildLocationLine(
                '${ride.fromProvince} - ${ride.fromDistrict} - ${ride.fromAddress}',
                '${ride.toProvince} - ${ride.toDistrict} - ${ride.toAddress}',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride.code, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(ride.formattedPrice, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Text(
                    ride.formattedPrice,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
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