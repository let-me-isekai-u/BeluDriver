import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../services/api_service.dart';
import '../../models/paged_response_model.dart';
import '../../models/waiting_ride_model.dart';
import 'ride_detail_screen.dart';

class ReceiveOrderTab extends StatefulWidget {
  const ReceiveOrderTab({super.key});

  @override
  State<ReceiveOrderTab> createState() => _ReceiveOrderTabState();
}

class _ReceiveOrderTabState extends State<ReceiveOrderTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Cấu hình phân trang
  static const _pageSize = 20;
  final PagingController<int, WaitingRide> _pagingController = PagingController(firstPageKey: 1);

  // provinces sẽ chứa kết quả từ API ride-count-by-province
  // mỗi phần tử dạng: { "provinceId": 1, "provinceName": "TP Hà Nội", "totalRides": 0 }
  List<dynamic> provinces = [];
  int? selectedProvinceId;

  // districts cho province đã chọn
  // mỗi phần tử dạng: { "districtId": 1, "districtName": "Quận X", "totalRides": 0 }
  List<dynamic> districts = [];
  int? selectedDistrictId;

  // Tab 2 (Đơn đã nhận) - Hiện tại vẫn dùng Map theo yêu cầu giữ nguyên logic cũ
  List<Map<String, dynamic>> acceptedRides = [];
  bool _isLoadingAcceptedRides = false;
  bool _isAcceptedLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _loadProvinces();

    // Đăng ký listener để tự động load trang khi cuộn
    _pagingController.addPageRequestListener((pageKey) {
      _fetchNewRidesPage(pageKey);
    });

    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.index == 1 && !_isAcceptedLoaded) {
      _loadAcceptedRides();
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  // ====================== LOGIC API & PHÂN TRANG ======================

  Future<void> _fetchNewRidesPage(int pageKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      // Nếu có filter theo huyện đón (selectedDistrictId != null) thì gọi API search theo huyện
      if (selectedDistrictId != null) {
        final res = await ApiService.searchRideByFromDistrict(
          accessToken: token,
          fromDistrictId: selectedDistrictId!,
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true) {
            final List<dynamic> list = body['data'] ?? [];
            final items = list
                .map<WaitingRide>((json) => WaitingRide.fromJson(json as Map<String, dynamic>))
                .toList();

            // Khi filter bằng huyện, API trả về toàn bộ danh sách => xử lý như single page
            _pagingController.appendLastPage(items);
            return;
          } else {
            _pagingController.error = "Không thể tải dữ liệu (filter theo huyện)";
            return;
          }
        } else {
          _pagingController.error = "Không thể tải dữ liệu từ máy chủ (filter theo huyện)";
          return;
        }
      }

      // LƯU Ý: API search theo tỉnh đã bị loại bỏ, nên ở đây nếu chỉ chọn tỉnh mà không chọn huyện
      // client sẽ không gọi search theo tỉnh (server-side). Thay vào đó ta sẽ load phân trang bình thường.
      // (Flow chọn tỉnh hiện tại sẽ tự động mở modal chọn huyện; nếu user hủy chọn huyện, tỉnh sẽ bị clear.)

      // Nếu không có filter, dùng API phân trang cũ
      final res = await ApiService.getWaitingRidesPaged(
        accessToken: token,
        page: pageKey,
        pageSize: _pageSize,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        final dynamic pagedData = body['data'] ?? body;

        final pagedResponse = PagedResponse<WaitingRide>.fromJson(
          pagedData,
              (json) => WaitingRide.fromJson(json as Map<String, dynamic>),
        );

        final newItems = pagedResponse.data;

        if (!pagedResponse.hasNext) {
          _pagingController.appendLastPage(newItems);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(newItems, nextPageKey);
        }
      } else {
        _pagingController.error = "Không thể tải dữ liệu từ máy chủ";
      }
    } catch (e) {
      debugPrint("Lỗi phân trang: $e");
      _pagingController.error = e;
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      // Gọi API ride-count-by-province để lấy tên tỉnh + tổng số đơn
      final res = await ApiService.getRideCountByProvince(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          setState(() => provinces = data);
        } else {
          debugPrint("Lỗi load provinces: success == false");
        }
      } else {
        debugPrint("Lỗi load provinces: status ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Lỗi load provinces: $e");
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
    // Làm mới danh sách phân trang khi đổi tỉnh/huyện
    _pagingController.refresh();
  }

  Future<void> _acceptRide(WaitingRide ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.acceptRide(accessToken: token, id: ride.id);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      // Xóa item khỏi UI cục bộ để tạo cảm giác mượt mà
      final currentItems = _pagingController.itemList ?? [];
      currentItems.removeWhere((item) => item.id == ride.id);
      _pagingController.itemList = List.from(currentItems);

      // Đánh dấu Tab 2 cần tải lại vì dữ liệu đã thay đổi
      _isAcceptedLoaded = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message'] ?? "Nhận đơn thành công"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đơn đã được nhận bởi tài xế khác!"), backgroundColor: Colors.red),
      );
      _pagingController.refresh();
    }
  }

  Future<void> _startRide(dynamic ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    // Xử lý ID linh hoạt cho cả Model và Map
    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0') ?? 0);

    if (rideId == 0) return;

    final res = await ApiService.startRide(accessToken: token, rideId: rideId);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bắt đầu chuyến đi thành công"), backgroundColor: Colors.green),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
    }
  }

  void _navigateToDetail(dynamic ride) {
    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0') ?? 0);

    if (rideId != 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
    }
  }

  // Helper: lấy giá trị province từ nhiều key khả dĩ trong Map
  String _extractProvinceFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
    }
    return '';
  }

  // Helper: lấy giá trị (dynamic) từ Map với nhiều key khả dĩ
  dynamic _extractDynamicFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v != null) return v;
      }
    }
    return null;
  }

  String _formatPickupTime(dynamic value) {
    if (value == null) return '';
    try {
      // Nếu là số nguyên (int) -> xem là timestamp (giây hoặc ms)
      if (value is int) {
        final int v = value;
        final int ms = v.abs() > 1000000000000 ? v : v * 1000; // >1e12 coi là ms
        return DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      final s = value.toString().trim();
      if (s.isEmpty) return '';

      // Nếu là chuỗi chỉ chứa chữ số -> timestamp string
      if (RegExp(r'^\d+$').hasMatch(s)) {
        final int v = int.parse(s);
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      // Thử parse ISO / standard datetime string
      final DateTime dt = DateTime.parse(s);
      return DateFormat('HH:mm dd/MM').format(dt);
    } catch (e) {
      // Fallback: trả về nguyên chuỗi (đỡ mất thông tin), hoặc '' nếu muốn ẩn
      return value.toString();
    }
  }


  // Helper: ghép address + province, tránh dấu phẩy thừa
  String _buildAddressWithProvince(String? address, String? province) {
    final a = (address ?? '').toString().trim();
    final p = (province ?? '').toString().trim();
    if (a.isEmpty && p.isEmpty) return '';
    if (p.isEmpty) return a;
    if (a.isEmpty) return p;
    return '$a, $p';
  }
  String _buildFullAddress(String? address, String? district, String? province) {
    final a = (address ?? '').toString().trim();
    final d = (district ?? '').toString().trim();
    final p = (province ?? '').toString().trim();

    final parts = <String>[];
    if (a.isNotEmpty) parts.add(a);
    if (d.isNotEmpty) parts.add(d);
    if (p.isNotEmpty) parts.add(p);

    return parts.join(', ');
  }

  // ====================== UI COMPONENTS ======================


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
          // TAB 1: ĐƠN MỚI (PHÂN TRANG VỚI MODEL)
          Column(
            children: [
              _buildLocationFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => Future.sync(() => _pagingController.refresh()),
                  child: PagedListView<int, WaitingRide>(
                    pagingController: _pagingController,
                    padding: const EdgeInsets.all(12),
                    builderDelegate: PagedChildBuilderDelegate<WaitingRide>(
                      itemBuilder: (context, item, index) => _buildRideCard(item, true),
                      noItemsFoundIndicatorBuilder: (_) => _buildEmptyPlaceholder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // TAB 2: ĐƠN ĐÃ NHẬN (LOGIC CŨ)
          _isLoadingAcceptedRides
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAcceptedRides,
                  child: _buildOldOrderList(
                    acceptedRides.where((ride) => (int.tryParse(ride['status'].toString()) ?? 0) == 2).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    final theme = Theme.of(context);
    // Tìm object province đang được chọn để lấy tên và số lượng đơn
    final selected = selectedProvinceId == null
        ? null
        : provinces.cast<dynamic?>().firstWhere(
          (p) => p != null && (p['provinceId'].toString() == selectedProvinceId.toString()),
      orElse: () => null,
    );

    // Tìm object district đang được chọn để hiển thị tên
    final selectedDistrict = selectedDistrictId == null
        ? null
        : districts.cast<dynamic?>().firstWhere(
          (d) => d != null && (d['districtId'].toString() == selectedDistrictId.toString()),
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showProvincePicker(context),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Nếu đã chọn tỉnh thì đổi viền sang màu xanh lá nhạt
            color: selected != null ? Colors.green.withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected != null ? Colors.green.withOpacity(0.3) : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.explore_outlined,
                color: selected != null ? Colors.green : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Khu vực đón khách",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      selected != null
                          ? "${selected['provinceName']} (${selected['totalRides'] ?? 0})"
                          : "Chọn tỉnh đón khách",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected != null ? FontWeight.bold : FontWeight.w500,
                        color: selected != null ? Colors.green[800] : Colors.blue,
                      ),
                    ),
                    if (selectedDistrict != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Huyện: ${selectedDistrict['districtName']} (${selectedDistrict['totalRides'] ?? 0})",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              if (selectedProvinceId != null || selectedDistrictId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedDistrictId != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => selectedDistrictId = null);
                          _applyFilter();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        // Clear both province and district when clearing province
                        setState(() {
                          selectedProvinceId = null;
                          selectedDistrictId = null;
                          districts = [];
                        });
                        _applyFilter();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                )
              else
                Icon(Icons.unfold_more_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // Thay thế hàm _showProvincePicker cũ bằng hàm này
  Future<void> _showProvincePicker(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Để làm viền bo tròn đẹp hơn
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Thanh gạch ngang nhỏ trên đầu modal (Handle bar)
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Chọn tỉnh đón khách",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: provinces.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: provinces.length + 1,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final bool isAll = index == 0;
                    String name = "";
                    int total = 0;
                    int? pid;

                    if (isAll) {
                      name = "Tất cả các tỉnh";
                      total = provinces.fold<int>(0, (s, p) => s + (int.tryParse(p['totalRides'].toString()) ?? 0));
                      pid = null;
                    } else {
                      final p = provinces[index - 1];
                      name = p['provinceName'] ?? '';
                      total = int.tryParse(p['totalRides'].toString()) ?? 0;
                      pid = p['provinceId'] is int ? p['provinceId'] : int.tryParse(p['provinceId'].toString()) ?? 0;
                    }

                    // Kiểm tra xem có đang được chọn không
                    final bool isSelected = selectedProvinceId == pid;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Icon(
                        isAll ? Icons.map : Icons.location_on_outlined,
                        color: isSelected ? Colors.blue : Colors.grey[400],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          // Chuyển chữ thành màu xanh lá khi được chọn, hoặc xanh nhạt hơn cho danh sách
                          color: isSelected ? Colors.blue[700] : Colors.blue[600],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          total.toString(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, pid),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    // Nếu user chọn "Tất cả" (null) thì clear filter và refresh
    if (result == null) {
      setState(() {
        selectedProvinceId = null;
        selectedDistrictId = null;
        districts = [];
      });
      _applyFilter();
      return;
    }

    // Nếu user chọn 1 tỉnh cụ thể thì mở modal chọn huyện.
    final int pid = result;
    // Lưu districts (được set trong _showDistrictPicker) và lấy kết quả huyện đã chọn
    final int? did = await _showDistrictPicker(context, pid);

    if (!mounted) return;

    if (did == null) {
      // Nếu user hủy chọn huyện -> rollback (clear tỉnh)
      setState(() {
        selectedProvinceId = null;
        selectedDistrictId = null;
        districts = [];
      });
    } else {
      // Commit cả tỉnh và huyện
      setState(() {
        selectedProvinceId = pid;
        selectedDistrictId = did;
      });
    }

    _applyFilter();
  }

  // Mở modal để chọn huyện cho tỉnh đã chọn
  // Trả về int? = districtId được chọn, hoặc null nếu user cancel
  Future<int?> _showDistrictPicker(BuildContext context, int provinceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    try {
      final res = await ApiService.getRideCountByDistrict(accessToken: token, provinceId: provinceId);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          // Lưu districts vào state để hiển thị tên khi cần
          setState(() => districts = data);

          final result = await showModalBottomSheet<int?>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Chọn huyện của ${provinces.firstWhere((p) => p['provinceId'].toString() == provinceId.toString())['provinceName'] ?? ''}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: data.isEmpty
                          ? const Center(child: Text("Không có huyện"))
                          : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: data.length + 1,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final bool isAll = index == 0;
                          String name = "";
                          int total = 0;
                          int? did;

                          if (isAll) {
                            name = "Tất cả các huyện";
                            total = data.fold<int>(0, (s, d) => s + (int.tryParse(d['totalRides'].toString()) ?? 0));
                            did = null;
                          } else {
                            final d = data[index - 1];
                            name = d['districtName'] ?? '';
                            total = int.tryParse(d['totalRides'].toString()) ?? 0;
                            did = d['districtId'] is int ? d['districtId'] : int.tryParse(d['districtId'].toString()) ?? 0;
                          }

                          final bool isSelected = selectedDistrictId == did;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            leading: Icon(
                              isAll ? Icons.map : Icons.location_city,
                              color: isSelected ? Colors.blue : Colors.grey[400],
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: isSelected ? Colors.blue[700] : Colors.blue[600],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                total.toString(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, did),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );

          return result;
        } else {
          debugPrint("Lỗi load districts: success == false");
        }
      } else {
        debugPrint("Lỗi load districts: status ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Lỗi load districts: $e");
    }
    return null;
  }

  Widget _buildRideCard(dynamic ride, bool isNew) {
    final theme = Theme.of(context);

    // Ép kiểu linh hoạt để dùng chung 1 UI cho cả 2 Tab
    final String code = (ride is WaitingRide) ? (ride.code ?? '---') : (ride['code'] ?? '---');
    final dynamic pickupTime = (ride is WaitingRide)
        ? ride.pickupTime
        : _extractDynamicFromMap(ride, ['pickupTime', 'pickup_time', 'pickupAt', 'pickup_at', 'pickuptime', 'pickupDate', 'pickup_date']);

    // Lấy address và province một cách an toàn, tránh dấu phẩy dư thừa khi province rỗng
    String fromAddressRaw = '';
    String fromDistrictRaw = '';
    String fromProvinceRaw = '';
    String toAddressRaw = '';
    String toDistrictRaw = '';
    String toProvinceRaw = '';

    if (ride is WaitingRide) {
      fromAddressRaw = ride.fromAddress ?? '';
      fromDistrictRaw = ride.fromDistrict ?? '';
      fromProvinceRaw = ride.fromProvince ?? '';
      toAddressRaw = ride.toAddress ?? '';
      toDistrictRaw = ride.toDistrict ?? '';
      toProvinceRaw = ride.toProvince ?? '';
    } else if (ride is Map) {
      fromAddressRaw = ride['fromAddress']?.toString() ?? '';
      fromDistrictRaw = _extractProvinceFromMap(ride, ['fromDistrict', 'fromDistrictName', 'from_district', 'from_district_name']);
      fromProvinceRaw = _extractProvinceFromMap(ride, ['fromProvince', 'fromProvinceName', 'from_province', 'from_province_name']);
      toAddressRaw = ride['toAddress']?.toString() ?? '';
      toDistrictRaw = _extractProvinceFromMap(ride, ['toDistrict', 'toDistrictName', 'to_district', 'to_district_name']);
      toProvinceRaw = _extractProvinceFromMap(ride, ['toProvince', 'toProvinceName', 'to_province', 'to_province_name']);
    }

    final String fromText = _buildFullAddress(fromAddressRaw, fromDistrictRaw, fromProvinceRaw);
    final String toText = _buildFullAddress(toAddressRaw, toDistrictRaw, toProvinceRaw);
    final String pickupText = _formatPickupTime(pickupTime);
    final double price = (ride is WaitingRide) ? ride.price : (double.tryParse((ride['price'] ?? '0').toString()) ?? 0);

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
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text("Giờ đón: ",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pickupText,
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                )

              ],
            ),
            const Divider(),
            _buildLocationRow(Icons.circle, Colors.green, fromText),
            _buildLocationRow(Icons.location_on, Colors.red, toText),
            const Divider(),
            _buildCardFooter(ride, theme, isNew, price),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFooter(dynamic ride, ThemeData theme, bool isNew, double price) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "${NumberFormat('#,###').format(price)}đ",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
        const SizedBox(width: 8),
        isNew
            ? ElevatedButton(
          onPressed: () => _acceptRide(ride as WaitingRide),
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
        Expanded(child: Text(address, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildOldOrderList(List<Map<String, dynamic>> rides) {
    if (rides.isEmpty) return _buildEmptyList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(rides[index], false),
    );
  }

  // Non-scrollable placeholder for PagedListView.noItemsFoundIndicatorBuilder
  Widget _buildEmptyPlaceholder() {
    return SizedBox(
      height: 200,
      child: Center(
        child: const Text(
          "Không có đơn hàng nào.\nVuốt xuống để cập nhật mới.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  // Scrollable empty view so RefreshIndicator can work in tab 2
  Widget _buildEmptyList() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: const Text(
            "Không có đơn hàng nào.\nVuốt xuống để cập nhật mới.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}