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

      // Nếu có filter theo tỉnh đón (selectedProvinceId != null) thì gọi API search theo tỉnh
      if (selectedProvinceId != null) {
        final res = await ApiService.searchRideByFromProvince(
          accessToken: token,
          fromProvinceId: selectedProvinceId!,
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true) {
            final List<dynamic> list = body['data'] ?? [];
            final items = list
                .map<WaitingRide>((json) => WaitingRide.fromJson(json as Map<String, dynamic>))
                .toList();

            // Khi filter bằng tỉnh, API trả về toàn bộ danh sách => xử lý như single page
            _pagingController.appendLastPage(items);
            return;
          } else {
            _pagingController.error = "Không thể tải dữ liệu (filter theo tỉnh)";
            return;
          }
        } else {
          _pagingController.error = "Không thể tải dữ liệu từ máy chủ (filter theo tỉnh)";
          return;
        }
      }

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
    // Làm mới danh sách phân trang khi đổi tỉnh
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

  // Helper: ghép address + province, tránh dấu phẩy thừa
  String _buildAddressWithProvince(String? address, String? province) {
    final a = (address ?? '').toString().trim();
    final p = (province ?? '').toString().trim();
    if (a.isEmpty && p.isEmpty) return '';
    if (p.isEmpty) return a;
    if (a.isEmpty) return p;
    return '$a, $p';
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
                  ],
                ),
              ),
              if (selectedProvinceId != null)
                GestureDetector(
                  onTap: () {
                    setState(() => selectedProvinceId = null);
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
    if (result != selectedProvinceId) { // Chỉ refresh nếu giá trị thay đổi
      setState(() => selectedProvinceId = result);
      _applyFilter();
    }
  }

  Widget _buildRideCard(dynamic ride, bool isNew) {
    final theme = Theme.of(context);

    // Ép kiểu linh hoạt để dùng chung 1 UI cho cả 2 Tab
    final String code = (ride is WaitingRide) ? (ride.code ?? '---') : (ride['code'] ?? '---');
    final String? pickupTime = (ride is WaitingRide) ? ride.pickupTime : ride['pickupTime'];

    // Lấy address và province một cách an toàn, tránh dấu phẩy dư thừa khi province rỗng
    String fromAddressRaw = '';
    String fromProvinceRaw = '';
    String toAddressRaw = '';
    String toProvinceRaw = '';

    if (ride is WaitingRide) {
      fromAddressRaw = ride.fromAddress ?? '';
      fromProvinceRaw = ride.fromProvince ?? '';
      toAddressRaw = ride.toAddress ?? '';
      toProvinceRaw = ride.toProvince ?? '';
    } else if (ride is Map) {
      fromAddressRaw = ride['fromAddress']?.toString() ?? '';
      // thử nhiều key khả dĩ cho province trong Map
      fromProvinceRaw = _extractProvinceFromMap(ride, ['fromProvince', 'fromProvinceName', 'from_province', 'from_province_name']);
      toAddressRaw = ride['toAddress']?.toString() ?? '';
      toProvinceRaw = _extractProvinceFromMap(ride, ['toProvince', 'toProvinceName', 'to_province', 'to_province_name']);
    }

    final String fromText = _buildAddressWithProvince(fromAddressRaw, fromProvinceRaw);
    final String toText = _buildAddressWithProvince(toAddressRaw, toProvinceRaw);

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
                Text(
                  pickupTime != null ? DateFormat('HH:mm dd/MM').format(DateTime.parse(pickupTime)) : '',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildLocationRow(Icons.circle, Colors.green, fromText),
            const SizedBox(height: 8),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
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
        Expanded(child: Text(address, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
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