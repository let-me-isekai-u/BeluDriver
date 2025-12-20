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

class _ReceiveOrderTabState extends State<ReceiveOrderTab> {
  List<dynamic> provinces = [];
  List<dynamic> districts = [];
  int? selectedProvinceId;
  int? selectedDistrictId;
  List<Map<String, dynamic>> allNewRides = [];

  // 1. DANH SÁCH ĐƠN MỚI
  List<Map<String, dynamic>> newRides = [];
  bool _isLoadingNewRides = true;
  bool _isLoadingAcceptedRides = true;

  // 2. DANH SÁCH ĐƠN ĐÃ NHẬN
  List<Map<String, dynamic>> acceptedRides = [];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _loadNewRides();
    _loadAcceptedRides();
  }

  Future<void> _loadProvinces() async {
    try {
      final data = await ApiService.getProvinces();
      setState(() => provinces = data);
    } catch (e) {
      debugPrint("Lỗi load provinces: $e");
    }
  }

  Future<void> _loadNewRides() async {
    setState(() => _isLoadingNewRides = true);
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
    setState(() => _isLoadingNewRides = false);
  }

  Future<void> _loadAcceptedRides() async {
    setState(() => _isLoadingAcceptedRides = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    List<Map<String, dynamic>> result = [];
    final res = await ApiService.getAcceptedRides(accessToken: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        final List<dynamic> ridesData = body['data'] ?? [];
        result = ridesData.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    setState(() {
      acceptedRides = result;
      _isLoadingAcceptedRides = false;
    });
  }

  void _applyFilter() {
    setState(() {
      newRides = allNewRides.where((ride) {
        final String spot = (ride['fromProvince'] != null
            ? "${ride['fromProvince']} ${ride['fromDistrict']}"
            : ride['fromAddress'] ?? '')
            .toLowerCase();

        if (selectedProvinceId != null) {
          final province = provinces.where((p) => p['id'] == selectedProvinceId).toList();
          if (province.isEmpty) return false;
          final provinceName = province.first['name'].toString().toLowerCase();
          if (!spot.contains(provinceName)) return false;
        }

        if (selectedDistrictId != null) {
          final district = districts.firstWhere((d) => d['id'] == selectedDistrictId, orElse: () => null);
          if (district == null) return false;
          final districtName = district['name'].toString().toLowerCase();
          if (!spot.contains(districtName)) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.acceptRide(
      accessToken: token,
      rideId: int.tryParse(ride['rideId'].toString()) ?? 0,
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      setState(() {
        newRides.remove(ride);
        acceptedRides.add(ride);
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
    final int rideId = int.tryParse(ride['rideId'].toString()) ?? 0;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Chuyến xe của bạn"),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "ĐƠN MỚI", icon: Icon(Icons.fiber_new)),
              Tab(text: "ĐƠN ĐÃ NHẬN", icon: Icon(Icons.assignment_turned_in)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildLocationFilter(),
                Expanded(
                  child: _isLoadingNewRides
                      ? const Center(child: CircularProgressIndicator())
                      : _buildOrderList(newRides, isNew: true),
                ),
              ],
            ),
            _isLoadingAcceptedRides
                ? const Center(child: CircularProgressIndicator())
                : _buildOrderList(
              acceptedRides.where((ride) => (int.tryParse(ride['status'].toString()) ?? 0) == 2).toList(),
              isNew: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: selectedProvinceId,
            hint: const Text("Tỉnh đón khách"),
            items: provinces.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['name']))).toList(),
            onChanged: (val) async {
              setState(() {
                selectedProvinceId = val;
                selectedDistrictId = null;
                districts = [];
              });
              if (val != null) {
                final dData = await ApiService.getDistricts(val);
                setState(() => districts = dData);
              }
              _applyFilter();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedDistrictId,
                  hint: const Text("Quận / Huyện"),
                  items: districts.map((d) => DropdownMenuItem<int>(value: d['id'], child: Text(d['name']))).toList(),
                  onChanged: (val) {
                    setState(() => selectedDistrictId = val);
                    _applyFilter();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.red),
                onPressed: () {
                  setState(() {
                    selectedProvinceId = null;
                    selectedDistrictId = null;
                    districts = [];
                  });
                  _applyFilter();
                },
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> rides, {required bool isNew}) {
    if (rides.isEmpty) return const Center(child: Text("Không có đơn hàng"));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(rides[index], isNew),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, bool isNew) {
    final theme = Theme.of(context);
    final String fromText = "${ride['fromAddress'] ?? ''}, ${ride['fromDistrict'] ?? ''}, ${ride['fromProvince'] ?? ''}";
    final String toText = "${ride['toAddress'] ?? ''}, ${ride['toDistrict'] ?? ''}, ${ride['toProvince'] ?? ''}";

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${NumberFormat('#,###').format(ride['price'] ?? 0)}đ",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            // 👉 THÊM THÔNG TIN THANH TOÁN Ở ĐÂY
            Text(
              ride['paymentMethod'] ?? "Tiền mặt",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        isNew
            ? ElevatedButton(
          onPressed: () => _acceptRide(ride),
          child: const Text("NHẬN ĐƠN"),
        )
            : Row(
          children: [
            OutlinedButton(
              onPressed: () {
                final id = int.tryParse(ride['rideId'].toString()) ?? 0;
                if (id > 0) Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: id)));
              },
              child: const Text("CHI TIẾT"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _startRide(ride),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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