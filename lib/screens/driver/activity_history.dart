import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../models/driver/ride_model.dart';
import '../../models/driver/broker_rides_model.dart';
import 'ride_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  final int initialTabIndex;
  const ActivityScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<RideModel> ongoingRides = [];
  List<RideModel> historyRides = [];

  //TAB 3: ĐƠN ĐÃ ĐẨY (API 24)
  List<BrokerRideItem> brokerRides = [];
  bool _isLoadingBroker = false;
  bool _isBrokerLoaded = false;

  bool _isLoadingOngoing = false;
  bool _isLoadingHistory = false;
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    final safeInitial = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: safeInitial);

    _fetchOngoingRides();

    if (safeInitial == 1 && !_isHistoryLoaded) {
      _fetchHistoryRides();
    }
    if (safeInitial == 2 && !_isBrokerLoaded) {
      _fetchBrokerRides();
    }

    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && !_isHistoryLoaded) {
      _fetchHistoryRides();
    }
    if (_tabController.index == 2 && !_isBrokerLoaded) {
      _fetchBrokerRides();
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
  // TAB 1: ĐANG DIỄN RA
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
          if (!mounted) return;
          setState(() {
            ongoingRides =
                (body['data'] as List).map((e) => RideModel.fromJson(e)).toList();
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
  // TAB 2: LỊCH SỬ
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
          if (!mounted) return;
          setState(() {
            historyRides =
                (body['data'] as List).map((e) => RideModel.fromJson(e)).toList();
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
  // TAB 3: ĐƠN ĐÃ ĐẨY (API 24)
  // ======================
  Future<void> _fetchBrokerRides() async {
    if (!mounted) return;
    setState(() => _isLoadingBroker = true);

    try {
      final token = await _getToken();
      if (token.isEmpty) return;

      final res = await ApiService.getBrokerRides(accessToken: token);

      if (res.statusCode == 200) {
        final parsed = BrokerRidesResponse.fromRawJson(res.body);

        if (!mounted) return;
        if (parsed.success) {
          setState(() {
            brokerRides = parsed.data;
            _isBrokerLoaded = true;
          });
        }
      } else if (res.statusCode == 404) {
        // backend có thể trả KeyNotFoundException
        if (!mounted) return;
        setState(() {
          brokerRides = [];
          _isBrokerLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("🔥 Fetch broker rides error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBroker = false);
    }
  }

  // ======================
  // HUỶ ĐƠN ĐÃ ĐẨY (API 25)
  // ======================
  Future<void> _handleCancelBrokerRide(BrokerRideItem ride) async {
    final theme = Theme.of(context);
    final token = await _getToken();
    if (token.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Huỷ đơn đã đẩy",
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text("Bạn chắc chắn muốn huỷ đơn ${ride.code} không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Huỷ đơn"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.cancelBrokerRide(
        accessToken: token,
        rideId: ride.rideId,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã huỷ đơn ${ride.code}."),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchBrokerRides();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Huỷ đơn thất bại (${res.statusCode})."),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Có lỗi xảy ra: $e"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  // ======================
  // COMPLETE RIDE
  // ======================
  Future<void> _handleCompleteRide(RideModel ride) async {
    final theme = Theme.of(context);
    final token = await _getToken();
    if (token.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.completeRide(
      accessToken: token,
      rideId: ride.id,
      rideSource: ride.rideSource,
    );

    if (mounted) Navigator.pop(context);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Chuyến xe ${ride.code} đã hoàn thành!"),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchOngoingRides();
      await _fetchHistoryRides();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Không thể cập nhật trạng thái."),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _navigateToDetail(RideModel ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDetailScreen(
          rideId: ride.id,
          rideSource: ride.rideSource,
        ),
      ),
    ).then((_) {
      _fetchOngoingRides();
      if (_isHistoryLoaded) _fetchHistoryRides();
    });
  }

  // ======================
  // UI
  // ======================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Hoạt động chuyến xe",
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
            Tab(text: "ĐANG DIỄN RA"),
            Tab(text: "LỊCH SỬ"),
            Tab(text: "ĐƠN ĐÃ ĐẨY"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngoingTab(theme),
          _buildHistoryTab(theme),
          _buildBrokerTab(theme),
        ],
      ),
    );
  }

  Widget _buildOngoingTab(ThemeData theme) {
    if (_isLoadingOngoing) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchOngoingRides,
      child: _buildList(
        ongoingRides,
        theme,
        emptyMessage: "Hiện tại bạn không có chuyến xe nào.",
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    if (_isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchHistoryRides,
      child: _buildList(
        historyRides,
        theme,
        emptyMessage: "Hiện tại bạn không có lịch sử chuyến xe nào.",
      ),
    );
  }

  Widget _buildBrokerTab(ThemeData theme) {
    if (_isLoadingBroker) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      );
    }

    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = 12.0 + 24.0 + bottomSafe;

    if (brokerRides.isEmpty) {
      return SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _fetchBrokerRides,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: _buildEmptyState("Hiện tại bạn chưa có đơn nào đã đẩy."),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      bottom: true,
      child: RefreshIndicator(
        onRefresh: _fetchBrokerRides,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: Image.asset(
                  'lib/assets/icons/ActivityLogo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
              itemCount: brokerRides.length,
              itemBuilder: (context, index) =>
                  _buildBrokerRideCard(brokerRides[index], theme),
            ),
          ],
        ),
      ),
    );
  }

  // ======================
  // LIST (RideModel) - giữ nguyên
  // ======================
  Widget _buildList(
      List<RideModel> rides,
      ThemeData theme, {
        required String emptyMessage,
      }) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = 12.0 + 24.0 + bottomSafe;

    if (rides.isEmpty) {
      return SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: _buildEmptyState(emptyMessage),
          ),
        ),
      );
    }

    return SafeArea(
      bottom: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'lib/assets/icons/ActivityLogo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
            itemCount: rides.length,
            itemBuilder: (context, index) => _buildRideCard(rides[index], theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/icons/ActivityLogo.png',
              width: 140,
              height: 140,
              errorBuilder: (_, __, ___) => Icon(
                Icons.history_rounded,
                size: 90,
                color: theme.colorScheme.secondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(RideModel ride, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ride.formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ride.statusColor.withOpacity(0.45)),
                    ),
                    child: Text(
                      ride.statusText,
                      style: TextStyle(
                        color: ride.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
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
                      Text(
                        ride.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride.formattedPrice,
                        style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    ride.formattedPrice,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (ride.status == 3) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteRide(ride),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      "XÁC NHẬN ĐẾN NƠI",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // CARD: BrokerRideItem + nút huỷ (API 25)
  // ======================
  Widget _buildBrokerRideCard(BrokerRideItem ride, ThemeData theme) {
    final statusColor = _brokerStatusColor(ride.status);
    final statusText = _brokerStatusText(ride.status);

    // Theo tài liệu: API 24 chỉ trả status 1,2,3
    // Bạn muốn "đúng đơn của tài xế đấy thì có nút huỷ" -> API này theo token đã là đúng tài xế.
    // Mình hiển thị nút huỷ cho status 1/2/3 luôn.
    // Nếu nghiệp vụ chỉ cho huỷ khi status == 1 (mới đẩy), bạn đổi điều kiện tại đây.
    final canCancel = ride.status == 1 || ride.status == 2 || ride.status == 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(ride.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.45)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
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
                    Text(
                      ride.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.paymentMethod,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  _formatMoney(ride.price),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (canCancel) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingBroker ? null : () => _handleCancelBrokerRide(ride),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text(
                    "HUỶ ĐƠN ĐÃ ĐẨY",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helpers cho tab broker
  String _formatMoney(num value) {
    final v = value.toStringAsFixed(0);
    return "$v đ";
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  Color _brokerStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _brokerStatusText(int status) {
    switch (status) {
      case 1:
        return "ĐÃ ĐẨY";
      case 2:
        return "ĐANG XỬ LÝ";
      case 3:
        return "ĐÃ NHẬN";
      default:
        return "KHÁC";
    }
  }

  Widget _buildLocationLine(String from, String to) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.radio_button_checked,
                size: 16, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                from,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 7.5),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(
                  width: 1, thickness: 1, color: Colors.grey),
            ),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                to,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}