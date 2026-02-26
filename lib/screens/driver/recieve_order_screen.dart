import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../services/api_service.dart';
import '../../models/paged_response_model.dart';
import '../../models/waiting_ride_model.dart';
import 'ride_detail_screen.dart';

// ✅ THÊM: model API #24
import '../../models/driver/broker_rides_model.dart';

class ReceiveOrderTab extends StatefulWidget {
  const ReceiveOrderTab({super.key});

  @override
  State<ReceiveOrderTab> createState() => _ReceiveOrderTabState();
}

class _ReceiveOrderTabState extends State<ReceiveOrderTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _pageSize = 20;
  final PagingController<int, WaitingRide> _pagingController =
  PagingController(firstPageKey: 1);

  List<dynamic> provinces = [];
  int? selectedProvinceId;

  List<dynamic> districts = [];
  int? selectedDistrictId;

  List<Map<String, dynamic>> acceptedRides = [];
  bool _isLoadingAcceptedRides = false;
  bool _isAcceptedLoaded = false;

  // ✅ THÊM: danh sách rideId do tài xế này đã đẩy (API #24)
  final Set<int> _myBrokerRideIds = <int>{};
  bool _loadingMyBrokerRides = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _loadProvinces();
    _loadMyBrokerRideIds(); // ✅ THÊM

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

  // ====================== Ride source helpers ======================

  String _rideSourceText(int rideSource) {
    switch (rideSource) {
      case 1:
        return "Đơn BeluCar";
      case 2:
        return "Đơn cộng đồng";
      default:
        return "Không xác định";
    }
  }

  Color _rideSourceColor(int rideSource, ThemeData theme) {
    switch (rideSource) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.55);
    }
  }

  Widget _rideSourceChip(int rideSource, ThemeData theme) {
    final color = _rideSourceColor(rideSource, theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _rideSourceText(rideSource),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  int _extractRideSource(dynamic ride) {
    if (ride is WaitingRide) return ride.rideSource;
    if (ride is Map) {
      return int.tryParse(
        ride['rideSource']?.toString() ??
            ride['ride_source']?.toString() ??
            '1',
      ) ??
          1;
    }
    return 1;
  }

  // ✅ THÊM: biết 1 đơn có phải do mình đẩy không
  bool _isMyBrokerRide(dynamic ride) {
    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(
      ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0',
    ) ??
        0);
    if (rideId == 0) return false;
    return _myBrokerRideIds.contains(rideId);
  }

  // ====================== LOGIC API & PHÂN TRANG ======================

  Future<void> _fetchNewRidesPage(int pageKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

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
                .map<WaitingRide>((json) =>
                WaitingRide.fromJson(json as Map<String, dynamic>))
                .toList();

            _pagingController.appendLastPage(items);
            return;
          } else {
            _pagingController.error =
            "Không thể tải dữ liệu (filter theo huyện)";
            return;
          }
        } else {
          _pagingController.error =
          "Không thể tải dữ liệu từ máy chủ (filter theo huyện)";
          return;
        }
      }

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

  // ✅ THÊM: load danh sách đơn mình đẩy (API #24)
  Future<void> _loadMyBrokerRideIds() async {
    if (!mounted) return;
    setState(() => _loadingMyBrokerRides = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';
      if (token.isEmpty) return;

      final res = await ApiService.getBrokerRides(accessToken: token);
      if (res.statusCode == 200) {
        final parsed = BrokerRidesResponse.fromRawJson(res.body);
        if (parsed.success) {
          final ids = parsed.data.map((e) => e.rideId).toSet();
          if (!mounted) return;
          setState(() {
            _myBrokerRideIds
              ..clear()
              ..addAll(ids);
          });
        }
      } else {
        debugPrint("getBrokerRides() status=${res.statusCode} body=${res.body}");
      }
    } catch (e) {
      debugPrint("Lỗi load broker rides: $e");
    } finally {
      if (mounted) setState(() => _loadingMyBrokerRides = false);
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getRideCountByProvince(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          if (!mounted) return;
          setState(() => provinces = data);
        }
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
          if (!mounted) return;
          setState(() {
            acceptedRides = ridesData
                .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e))
                .toList();
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
    _pagingController.refresh();
  }

  Future<void> _acceptRide(WaitingRide ride) async {
    final theme = Theme.of(context);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res = await ApiService.acceptRide(
      accessToken: token,
      id: ride.id,
      rideSource: ride.rideSource,
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      final currentItems = _pagingController.itemList ?? [];
      currentItems.removeWhere((item) => item.id == ride.id);
      _pagingController.itemList = List.from(currentItems);

      _isAcceptedLoaded = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body['message'] ?? "Nhận đơn thành công"),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Đơn đã được nhận bởi tài xế khác!"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      _pagingController.refresh();
    }
  }

  //THÊM: Huỷ đơn mình đã đẩy (API #25)
  Future<void> _cancelMyBrokerRide(dynamic ride) async {
    final theme = Theme.of(context);

    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(
      ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0',
    ) ??
        0);
    if (rideId == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Huỷ đơn đã đẩy"),
        content: Text("Bạn chắc chắn muốn huỷ chuyến?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700), // gold
            ),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text("Huỷ",),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final res =
    await ApiService.cancelBrokerRide(accessToken: token, rideId: rideId);

    if (!mounted) return;

    if (res.statusCode == 200) {
      setState(() {
        _myBrokerRideIds.remove(rideId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Huỷ đơn thành công"), backgroundColor: Colors.green),
      );

      _pagingController.refresh();
      await _loadMyBrokerRideIds();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Huỷ đơn thất bại (${res.statusCode})"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _startRide(dynamic ride) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) return;

    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(
      ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0',
    ) ??
        0);

    if (rideId == 0) return;

    final int rideSource = _extractRideSource(ride);

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Bắt đầu chuyến đi thành công"),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(
            rideId: rideId,
            rideSource: rideSource,
          ),
        ),
      );
    }
  }

  void _navigateToDetail(dynamic ride) {
    final int rideId = (ride is WaitingRide)
        ? ride.id
        : (int.tryParse(
      ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0',
    ) ??
        0);

    final int rideSource = _extractRideSource(ride);

    if (rideId != 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(
            rideId: rideId,
            rideSource: rideSource,
          ),
        ),
      );
    }
  }

  // ====================== Helpers ======================

  String _extractProvinceFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    return '';
  }

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
      if (value is int) {
        final int v = value;
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateFormat('HH:mm dd/MM')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      final s = value.toString().trim();
      if (s.isEmpty) return '';

      if (RegExp(r'^\d+$').hasMatch(s)) {
        final int v = int.parse(s);
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateFormat('HH:mm dd/MM')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      final DateTime dt = DateTime.parse(s);
      return DateFormat('HH:mm dd/MM').format(dt);
    } catch (_) {
      return value.toString();
    }
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

  // ====================== UI ======================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = 12.0 + 24.0 + bottomSafe;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Nhận đơn",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.secondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelColor: Colors.white70,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: theme.colorScheme.secondary,
          indicatorWeight: 5.5,
          tabs: const [
            Tab(text: "ĐƠN MỚI", icon: Icon(Icons.fiber_new_rounded)),
            Tab(text: "ĐƠN ĐÃ NHẬN", icon: Icon(Icons.assignment_turned_in_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              _buildLocationFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadMyBrokerRideIds();
                    _pagingController.refresh();
                  },
                  child: SafeArea(
                    bottom: true,
                    child: PagedListView<int, WaitingRide>(
                      pagingController: _pagingController,
                      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      builderDelegate: PagedChildBuilderDelegate<WaitingRide>(
                        itemBuilder: (context, item, index) =>
                            _buildRideCard(item, true),

                        noItemsFoundIndicatorBuilder: (_) => _buildEmptyPlaceholder(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _isLoadingAcceptedRides
              ? Center(
            child: CircularProgressIndicator(color: theme.colorScheme.secondary),
          )
              : RefreshIndicator(
            onRefresh: _loadAcceptedRides,
            child: SafeArea(
              bottom: true,
              child: _buildOldOrderList(
                acceptedRides
                    .where((ride) =>
                (int.tryParse(ride['status'].toString()) ?? 0) == 2)
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== Filter UI ======================
  Widget _buildLocationFilter() {
    return const SizedBox.shrink();
  }

  // ====================== Cards/List rendering ======================

  Widget _buildRideCard(dynamic ride, bool isNew) {
    final theme = Theme.of(context);

    final int rideSource = _extractRideSource(ride);

    final String code =
    (ride is WaitingRide) ? (ride.code ?? '---') : (ride['code'] ?? '---');

    final dynamic pickupTime = (ride is WaitingRide)
        ? ride.pickupTime
        : _extractDynamicFromMap(ride, [
      'pickupTime',
      'pickup_time',
      'pickupAt',
      'pickup_at',
      'pickuptime',
      'pickupDate',
      'pickup_date'
    ]);

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
      fromDistrictRaw = _extractProvinceFromMap(ride, [
        'fromDistrict',
        'fromDistrictName',
        'from_district',
        'from_district_name'
      ]);
      fromProvinceRaw = _extractProvinceFromMap(ride, [
        'fromProvince',
        'fromProvinceName',
        'from_province',
        'from_province_name'
      ]);
      toAddressRaw = ride['toAddress']?.toString() ?? '';
      toDistrictRaw = _extractProvinceFromMap(ride, [
        'toDistrict',
        'toDistrictName',
        'to_district',
        'to_district_name'
      ]);
      toProvinceRaw = _extractProvinceFromMap(ride, [
        'toProvince',
        'toProvinceName',
        'to_province',
        'to_province_name'
      ]);
    }

    final String fromText =
    _buildFullAddress(fromAddressRaw, fromDistrictRaw, fromProvinceRaw);
    final String toText =
    _buildFullAddress(toAddressRaw, toDistrictRaw, toProvinceRaw);
    final String pickupText = _formatPickupTime(pickupTime);
    final double price = (ride is WaitingRide)
        ? ride.price
        : (double.tryParse((ride['price'] ?? '0').toString()) ?? 0);

    // ✅ NEW RULE:
    // - Tab "đơn mới" (isNew==true): không cho xem chi tiết => onTap = null
    // - Tab "đơn đã nhận" (isNew==false): vẫn cho xem chi tiết
    final VoidCallback? onTapCard = isNew ? null : () => _navigateToDetail(ride);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapCard,
          borderRadius: BorderRadius.circular(12),
          // ✅ nếu không cho tap thì cũng không highlight
          splashColor: isNew ? Colors.transparent : null,
          highlightColor: isNew ? Colors.transparent : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _rideSourceChip(rideSource, theme),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Giờ đón: ",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pickupText,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(color: theme.colorScheme.onSurface.withOpacity(0.12)),
                _buildLocationRow(Icons.circle, Colors.green, fromText),
                _buildLocationRow(Icons.location_on, Colors.red, toText),
                Divider(color: theme.colorScheme.onSurface.withOpacity(0.12)),
                _buildCardFooter(ride, theme, isNew, price),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFooter(
      dynamic ride,
      ThemeData theme,
      bool isNew,
      double price,
      ) {
    final bool isMyBrokerRide = _isMyBrokerRide(ride);
    final int rideSource = _extractRideSource(ride);

    return Row(
      children: [
        Expanded(
          child: Text(
            "${NumberFormat('#,###').format(price)}đ",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isNew && rideSource == 2 && isMyBrokerRide) ...[
          ElevatedButton(
            onPressed:
            _loadingMyBrokerRides ? null : () => _cancelMyBrokerRide(ride),
            style:
            ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text("HUỶ ĐƠN"),
          ),
        ] else if (isNew) ...[
          ElevatedButton(
            onPressed: () => _acceptRide(ride as WaitingRide),
            child: const Text("NHẬN ĐƠN"),
          ),
        ] else ...[
          Row(
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
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String address) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOldOrderList(List<Map<String, dynamic>> rides) {
    if (rides.isEmpty) return _buildEmptyList();

    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = 12.0 + 24.0 + bottomSafe;

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
      itemCount: rides.length,
      itemBuilder: (context, index) => _buildRideCard(rides[index], false),
    );
  }

  Widget _buildEmptyPlaceholder() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          "Không có đơn hàng nào.\nVuốt xuống để cập nhật mới.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyList() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 320,
        child: Center(
          child: Text(
            "Không có đơn hàng nào.\nVuốt xuống để cập nhật mới.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}