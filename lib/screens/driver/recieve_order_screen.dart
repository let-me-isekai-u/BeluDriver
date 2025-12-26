import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'ride_detail_screen.dart';

class ReceiveOrderTab extends StatefulWidget {
  const ReceiveOrderTab({super.key});

  @override
  State<ReceiveOrderTab> createState() => _ReceiveOrderTabState();
}

// Thêm SingleTickerProviderStateMixin để quản lý TabController
class _ReceiveOrderTabState extends State<ReceiveOrderTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;


  List<dynamic> provinces = [];
  int? selectedProvinceId;
  List<Map<String, dynamic>> allNewRides = [];

  // 1. DANH SÁCH ĐƠN MỚI
  List<Map<String, dynamic>> newRides = [];
  bool _isLoadingNewRides = true;
  bool _isLoadingAcceptedRides = false; // Mặc định false vì chưa load ngay
  bool _isAcceptedLoaded = false; // Flag kiểm soát lazy load

  // 2. DANH SÁCH ĐƠN ĐÃ NHẬN
  List<Map<String, dynamic>> acceptedRides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);


    // Load dữ liệu cần thiết cho Tab 1 ngay lập tức
    _loadProvinces();
    _loadNewRides();

    // Lắng nghe sự kiện đổi tab
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // Nếu chuyển sang tab 1 (Đơn đã nhận) và chưa load bao giờ
    if (_tabController.index == 1 && !_isAcceptedLoaded) {
      _loadAcceptedRides();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  // ====================== API & LOGIC (GIỮ NGUYÊN) ======================

  Future<void> _loadProvinces() async {
    try {
      final data = await ApiService.getProvinces();
      setState(() => provinces = data);
    } catch (e) {
      debugPrint("Lỗi load provinces: $e");
    }
  }

  Future<void> _loadNewRides() async {
    if (!mounted) return;
    setState(() => _isLoadingNewRides = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getWaitingRides(accessToken: token);
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> ridesData = body['data'];
          allNewRides = ridesData.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilter();
        }
      }
    } catch (e) {
      debugPrint("Lỗi load new rides: $e");
    } finally {
      if (mounted) setState(() => _isLoadingNewRides = false);
    }
  }

  Future<void> _loadAcceptedRides() async {
    if (!mounted) return;
    setState(() => _isLoadingAcceptedRides = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getAcceptedRides(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> ridesData = body['data'] ?? [];
          setState(() {
            acceptedRides = ridesData.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
            _isAcceptedLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi load accepted rides: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAcceptedRides = false);
    }
  }

  void _applyFilter() {
    setState(() {
      newRides = allNewRides.where((ride) {
        final String spot = (ride['fromProvince'] != null
            ? "${ride['fromProvince']}"
            : ride['fromAddress'] ?? '')
            .toLowerCase();

        if (selectedProvinceId != null) {
          final province = provinces.where((p) => p['id'] == selectedProvinceId).toList();
          if (province.isEmpty) return false;
          final provinceName = province.first['name'].toString().toLowerCase();
          if (!spot.contains(provinceName)) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final int id = int.tryParse(ride['id'].toString()) ?? 0;
    if (id == 0) return;

    final res = await ApiService.acceptRide(accessToken: token, id: id);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      setState(() {
        // 1. Xóa khỏi danh sách Đơn mới
        allNewRides.removeWhere((r) => r['id'] == ride['id']);
        newRides.remove(ride);

        // 2. Nếu tab "Đã nhận" đã từng load, ta thêm đơn này vào thủ công
        if (_isAcceptedLoaded) {
          // TẠO BẢN SAO VÀ CẬP NHẬT TRẠNG THÁI ĐỂ KHỚP VỚI FILTER TAB 2
          Map<String, dynamic> acceptedItem = Map<String, dynamic>.from(ride);

          acceptedItem['status'] = 2; // Gán status = 2 để thỏa mãn điều kiện .where status == 2

          // Đảm bảo có rideId để nhấn vào CHI TIẾT không bị lỗi
          acceptedItem['rideId'] = acceptedItem['id'];

          acceptedRides.add(acceptedItem);
        } else {
          // Nếu chưa từng mở Tab 2, ta chỉ cần đánh dấu để khi người dùng ấn vào tab 2
          // nó sẽ gọi API load lại toàn bộ đơn mới nhất từ Server.
          _isAcceptedLoaded = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message'] ?? "Nhận đơn thành công"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đơn đã được nhận bởi tài xế khác!"), backgroundColor: Colors.red),
      );
      _loadNewRides();
    }
  }

  Future<void> _startRide(Map<String, dynamic> ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final int rideId = int.tryParse(ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0') ?? 0;

    if (rideId == 0) return;

    final res = await ApiService.startRide(accessToken: token, rideId: rideId);

    if (res.statusCode == 200) {
      setState(() => ride['status'] = 3);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bắt đầu chuyến đi: ${ride['code']}"), backgroundColor: Colors.green),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
    }
  }

  void _navigateToDetail(Map<String, dynamic> ride) {
    final int rideId = int.tryParse(ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0') ?? 0;
    if (rideId != 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không tìm thấy mã chuyến xe!")));
    }
  }

  // ====================== UI BUILD (GIỮ NGUYÊN) ======================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Chuyến xe của bạn"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "ĐƠN MỚI", icon: Icon(Icons.fiber_new)),
            Tab(text: "ĐƠN ĐÃ NHẬN", icon: Icon(Icons.assignment_turned_in)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ĐƠN MỚI
          Column(
            children: [
              _buildLocationFilter(),
              Expanded(
                child: _isLoadingNewRides
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                  onRefresh: _loadNewRides,
                  child: _buildOrderList(newRides, isNew: true),
                ),
              ),
            ],
          ),
          // TAB 2: ĐƠN ĐÃ NHẬN
          _isLoadingAcceptedRides
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _loadAcceptedRides,
            child: _buildOrderList(
              acceptedRides.where((ride) => (int.tryParse(ride['status'].toString()) ?? 0) == 2).toList(),
              isNew: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<int>(
        value: selectedProvinceId,
        hint: const Text("Tỉnh đón khách"),
        items: provinces.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['name']))).toList(),
        onChanged: (val) {
          setState(() => selectedProvinceId = val);
          _applyFilter();
        },
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> rides, {required bool isNew}) {
    // NẾU DANH SÁCH TRỐNG
    if (rides.isEmpty) {
      return ListView(
        // Quan trọng: Phải có cái này thì RefreshIndicator mới hoạt động khi list trống
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3), // Đẩy text ra giữa màn hình
          const Center(
            child: Text(
              "Không có đơn hàng nào.\nVuốt xuống để cập nhật mới.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    // NẾU CÓ DANH SÁCH
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo đồng nhất
      padding: const EdgeInsets.all(12),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(rides[index], isNew),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, bool isNew) {
    final theme = Theme.of(context);
    final String fromText = "${ride['fromAddress'] ?? ''}, ${ride['fromProvince'] ?? ''}";
    final String toText = "${ride['toAddress'] ?? ''}, ${ride['toProvince'] ?? ''}";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ride['code'] ?? '---', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  ride['pickupTime'] != null ? DateFormat('HH:mm dd/MM').format(DateTime.parse(ride['pickupTime'])) : '',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildLocationRow(Icons.circle, Colors.green, fromText),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.location_on, Colors.red, toText),
            const Divider(),
            _buildCardFooter(ride, theme, isNew),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFooter(Map<String, dynamic> ride, ThemeData theme, bool isNew) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${NumberFormat('#,###').format(ride['price'] ?? 0)}đ",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
              ),

            ],
          ),
        ),
        const SizedBox(width: 8),
        isNew
            ? ElevatedButton(
          onPressed: () => _acceptRide(ride),
          child: const Text("NHẬN ĐƠN"),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => _navigateToDetail(ride),
              child: const Text("CHI TIẾT"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _startRide(ride),
              child: const Text("XUẤT PHÁT"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(address, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}