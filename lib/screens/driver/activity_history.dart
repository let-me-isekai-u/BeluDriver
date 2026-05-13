import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/api_chat_service.dart';
import '../../models/driver/ride_model.dart';
import '../../models/driver/broker_rides_model.dart';
import 'ride_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  final int initialTabIndex;
  const ActivityScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<RideModel> ongoingRides = [];
  List<RideModel> historyRides = [];

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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: safeInitial,
    );

    if (safeInitial == 0) {
      _fetchOngoingRides();
    } else if (safeInitial == 1) {
      _fetchHistoryRides();
    } else if (safeInitial == 2) {
      _fetchBrokerRides();
    }

    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;

    if (_tabController.index == 0 &&
        ongoingRides.isEmpty &&
        !_isLoadingOngoing) {
      _fetchOngoingRides();
    }

    if (_tabController.index == 1 && !_isHistoryLoaded && !_isLoadingHistory) {
      _fetchHistoryRides();
    }

    if (_tabController.index == 2 && !_isBrokerLoaded && !_isLoadingBroker) {
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

  Future<void> _fetchOngoingRides() async {
    if (!mounted) return;
    setState(() => _isLoadingOngoing = true);

    try {
      final token = await _getToken();
      if (token.isEmpty) {
        if (!mounted) return;
        setState(() => ongoingRides = []);
        return;
      }

      debugPrint(
        "🔵 [ACTIVITY][TAB 1] START fetch ongoing rides (status 2 + 3)",
      );
      debugPrint(
        "🔵 [ACTIVITY][TAB 1] CALL API /api/driverapi/ride-confirmed -> lấy đơn đã nhận (status = 2)",
      );
      debugPrint(
        "🔵 [ACTIVITY][TAB 1] CALL API /api/driverapi/ride-process -> lấy đơn đang chạy (status = 3)",
      );
      final responses = await Future.wait([
        ApiService.getAcceptedRides(accessToken: token),
        ApiService.getProcessingRides(accessToken: token),
      ]);

      final acceptedRes = responses[0];
      final processingRes = responses[1];

      debugPrint(
        "🔵 [ACTIVITY][TAB 1][ACCEPTED] STATUS: ${acceptedRes.statusCode}",
      );
      debugPrint("🔵 [ACTIVITY][TAB 1][ACCEPTED] BODY: ${acceptedRes.body}");
      debugPrint(
        "🔵 [ACTIVITY][TAB 1][PROCESSING] STATUS: ${processingRes.statusCode}",
      );
      debugPrint(
        "🔵 [ACTIVITY][TAB 1][PROCESSING] BODY: ${processingRes.body}",
      );

      final List<RideModel> mergedRides = [];

      if (acceptedRes.statusCode == 200) {
        final body = jsonDecode(acceptedRes.body);
        if (body['success'] == true) {
          final acceptedData = (body['data'] as List? ?? const []);
          debugPrint(
            "🔵 [ACTIVITY][TAB 1][ACCEPTED] COUNT FROM API: ${acceptedData.length}",
          );
          mergedRides.addAll(
            acceptedData
                .map((e) => RideModel.fromJson(e))
                .where((ride) => ride.status == 2),
          );
        }
      }

      if (processingRes.statusCode == 200) {
        final body = jsonDecode(processingRes.body);
        if (body['success'] == true) {
          final processingData = (body['data'] as List? ?? const []);
          debugPrint(
            "🔵 [ACTIVITY][TAB 1][PROCESSING] COUNT FROM API: ${processingData.length}",
          );
          mergedRides.addAll(
            processingData
                .map((e) => RideModel.fromJson(e))
                .where((ride) => ride.status == 3),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        ongoingRides = _dedupeAndSortOngoingRides(mergedRides);
      });
      debugPrint(
        "🔵 [ACTIVITY][TAB 1] DONE merged ongoing rides: ${ongoingRides.length} items",
      );
    } catch (e) {
      debugPrint("🔥 Fetch ongoing error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOngoing = false);
    }
  }

  List<RideModel> _dedupeAndSortOngoingRides(List<RideModel> rides) {
    final Map<String, RideModel> uniqueRides = {};

    for (final ride in rides) {
      if (ride.status != 2 && ride.status != 3) continue;
      final key = '${ride.id}_${ride.rideSource}';
      uniqueRides[key] = ride;
    }

    final result = uniqueRides.values.toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(
            b.createdAt,
          ).compareTo(DateTime.parse(a.createdAt));
        } catch (_) {
          return 0;
        }
      });

    return result;
  }

  Future<void> _fetchHistoryRides() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);

    try {
      final token = await _getToken();

      debugPrint("🟠 [ACTIVITY][TAB 2] CALL getRideHistory");
      final res = await ApiService.getRideHistory(accessToken: token);
      debugPrint("🟠 [ACTIVITY][TAB 2] STATUS: ${res.statusCode}");
      debugPrint("🟠 [ACTIVITY][TAB 2] BODY: ${res.body}");

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          if (!mounted) return;
          setState(() {
            historyRides = (body['data'] as List)
                .map((e) => RideModel.fromJson(e))
                .toList();
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

  Future<void> _fetchBrokerRides() async {
    if (!mounted) return;
    setState(() => _isLoadingBroker = true);

    try {
      final token = await _getToken();
      if (token.isEmpty) return;

      debugPrint("🟣 [ACTIVITY][TAB 3] CALL getBrokerRides");
      final res = await ApiService.getBrokerRides(accessToken: token);
      debugPrint("🟣 [ACTIVITY][TAB 3] STATUS: ${res.statusCode}");
      debugPrint("🟣 [ACTIVITY][TAB 3] BODY: ${res.body}");

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
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
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
      Navigator.pop(context);

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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Có lỗi xảy ra: $e"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleStartRide(RideModel ride) async {
    final theme = Theme.of(context);
    final token = await _getToken();
    if (token.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: ride.id,
      rideSource: ride.rideSource,
    );

    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã xuất phát chuyến ${ride.code}."),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RideDetailScreen(rideId: ride.id, rideSource: ride.rideSource),
        ),
      );

      if (!mounted) return;
      if (_tabController.index == 0) {
        await _fetchOngoingRides();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Không thể xuất phát, vui lòng thử lại."),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

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

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
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
        builder: (_) =>
            RideDetailScreen(rideId: ride.id, rideSource: ride.rideSource),
      ),
    ).then((_) {
      if (_tabController.index == 0) {
        _fetchOngoingRides();
      }
      if (_isHistoryLoaded) {
        _fetchHistoryRides();
      }
    });
  }

  void _navigateBrokerToDetail(BrokerRideItem ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDetailScreen(rideId: ride.rideId, rideSource: 2),
      ),
    ).then((_) async {
      if (_tabController.index == 2) {
        await _fetchBrokerRides();
      }
      if (_tabController.index == 0) {
        await _fetchOngoingRides();
      }
      if (_isHistoryLoaded) {
        await _fetchHistoryRides();
      }
    });
  }

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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
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
            itemBuilder: (context, index) =>
                _buildRideCard(rides[index], theme),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ride.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ride.statusColor.withOpacity(0.45),
                      ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
              if (ride.status == 2) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleStartRide(ride),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      "XUẤT PHÁT",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              if (ride.status == 3) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteRide(ride),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      "HOÀN THÀNH",
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

  Widget _buildBrokerRideCard(BrokerRideItem ride, ThemeData theme) {
    final statusColor = _brokerStatusColor(ride.status);
    final statusText = _brokerStatusText(ride.status);

    final canCancel = ride.status == 0 || ride.status == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateBrokerToDetail(ride),
        borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
                    onPressed: _isLoadingBroker
                        ? null
                        : () => _handleCancelBrokerRide(ride),
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
      ),
    );
  }

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
      case 0:
        return Colors.orange;
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.indigo;
      case 4:
        return Colors.green;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _brokerStatusText(int status) {
    switch (status) {
      case 0:
        return "Chờ duyệt";
      case 1:
        return "Đang đợi tài xế";
      case 2:
        return "Đã có tài xế";
      case 3:
        return "Đang di chuyển";
      case 4:
        return "Đã hoàn thành";
      case 5:
        return "Đã huỷ";
      default:
        return "Khác";
    }
  }

  Widget _buildLocationLine(String from, String to) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.radio_button_checked,
              size: 16,
              color: Colors.green,
            ),
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
                width: 1,
                thickness: 1,
                color: Colors.grey,
              ),
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
