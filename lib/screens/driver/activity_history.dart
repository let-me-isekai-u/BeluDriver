import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../models/driver/broker_rides_model.dart';
import '../../models/driver/ride_model.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';
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
    } else {
      _fetchBrokerRides();
    }

    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
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
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceGreen,
        title: Text(
          "Huỷ đơn đã đẩy",
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "Bạn chắc chắn muốn huỷ đơn ${ride.code} không?",
          style: const TextStyle(color: Colors.white),
        ),
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
    if (!mounted) return;

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
    if (!mounted) return;

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
    if (!mounted) return;

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
    if (!mounted) return;

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

  String _tabTitle() {
    switch (_tabController.index) {
      case 1:
        return "Lịch sử chuyến";
      case 2:
        return "Đơn đã đẩy";
      default:
        return "Đang vận hành";
    }
  }

  String _formatPickupTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      return '${DateTime.parse(raw).hour.toString().padLeft(2, '0')}:${DateTime.parse(raw).minute.toString().padLeft(2, '0')} ${DateTime.parse(raw).day.toString().padLeft(2, '0')}/${DateTime.parse(raw).month.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Hoạt động chuyến xe",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.secondary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -70,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildTabSwitcher(theme),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOngoingTab(theme),
                    _buildHistoryTab(theme),
                    _buildBrokerTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen,
                AppColors.surfaceGreen.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DriverPill(
                label: "Bảng điều phối",
                icon: Icons.local_shipping_rounded,
              ),
              const SizedBox(height: 12),
              Text(
                _tabTitle(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Theo dõi chuyến đang chạy, lịch sử hoàn thành và các đơn đã đẩy trong cùng một nơi.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubtle,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DriverStatTile(
                      label: "Đang chạy",
                      value: ongoingRides.length.toString(),
                      icon: Icons.timelapse_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DriverStatTile(
                      label: "Lịch sử",
                      value: historyRides.length.toString(),
                      icon: Icons.history_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DriverStatTile(
                      label: "Đã đẩy",
                      value: brokerRides.length.toString(),
                      icon: Icons.share_location_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabSwitcher(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceGreen.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.12),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: theme.colorScheme.secondary,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: "Đang diễn ra"),
          Tab(text: "Lịch sử"),
          Tab(text: "Đơn đã đẩy"),
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
      child: _buildRideList(
        rides: ongoingRides,
        emptyTitle: "Chưa có chuyến đang diễn ra",
        emptyMessage:
            "Khi nhận đơn thành công, chuyến xe sẽ xuất hiện tại đây để bạn bắt đầu và hoàn tất hành trình.",
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
      child: _buildRideList(
        rides: historyRides,
        emptyTitle: "Chưa có lịch sử chuyến",
        emptyMessage:
            "Sau khi hoàn thành chuyến, thông tin hành trình và doanh thu sẽ được lưu ở đây.",
      ),
    );
  }

  Widget _buildBrokerTab(ThemeData theme) {
    if (_isLoadingBroker) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      );
    }

    if (brokerRides.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBrokerRides,
        child: ListView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: _listPadding(context),
          children: [
            _buildSummaryHeader(theme),
            const SizedBox(height: 16),
            const DriverSectionCard(
              title: "Đơn đã đẩy",
              subtitle: "Các chuyến chia sẻ của bạn sẽ xuất hiện tại đây.",
              icon: Icons.share_rounded,
              child: DriverEmptyState(
                icon: Icons.move_down_rounded,
                title: "Chưa có đơn nào được đẩy",
                message:
                    "Khi bạn tạo hoặc chia sẻ chuyến đi cho tài xế khác, danh sách sẽ được cập nhật tại màn hình này.",
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBrokerRides,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _listPadding(context),
        itemCount: brokerRides.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildSummaryHeader(theme);
          if (index == 1) return const SizedBox(height: 16);
          return _buildBrokerRideCard(brokerRides[index - 2], theme);
        },
      ),
    );
  }

  Widget _buildRideList({
    required List<RideModel> rides,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    final theme = Theme.of(context);

    if (rides.isEmpty) {
      return ListView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _listPadding(context),
        children: [
          _buildSummaryHeader(theme),
          const SizedBox(height: 16),
          DriverSectionCard(
            title: emptyTitle,
            subtitle: "Kéo xuống để tải lại dữ liệu bất kỳ lúc nào.",
            icon: Icons.route_rounded,
            child: DriverEmptyState(
              icon: Icons.location_searching_rounded,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: _listPadding(context),
      itemCount: rides.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummaryHeader(theme);
        if (index == 1) return const SizedBox(height: 16);
        return _buildRideCard(rides[index - 2], theme);
      },
    );
  }

  EdgeInsets _listPadding(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return EdgeInsets.fromLTRB(16, 4, 16, bottom + 28);
  }

  String _rideStatusText(int status) {
    switch (status) {
      case 2:
        return "Đã nhận đơn";
      case 3:
        return "Đang di chuyển";
      case 4:
        return "Hoàn thành";
      case 5:
        return "Đã hủy";
      default:
        return "Không xác định";
    }
  }

  Color _rideStatusColor(int status) {
    switch (status) {
      case 2:
        return const Color(0xFF73B7FF);
      case 3:
        return const Color(0xFFFFB347);
      case 4:
        return const Color(0xFF6ED39B);
      case 5:
        return const Color(0xFFFF8A8A);
      default:
        return Colors.grey;
    }
  }

  Widget _buildRideCard(RideModel ride, ThemeData theme) {
    final statusColor = _rideStatusColor(ride.status);
    final sourceLabel = ride.rideSource == 2 ? "Đơn chia sẻ" : "Đơn BeluCar";
    final pickupText = _formatPickupTime(ride.pickupTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGreen.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(ride),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.code,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ride.formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DriverPill(
                          label: _rideStatusText(ride.status),
                          color: statusColor,
                        ),
                        const SizedBox(height: 8),
                        DriverPill(
                          label: sourceLabel,
                          icon: Icons.layers_rounded,
                          color: ride.rideSource == 2
                              ? const Color(0xFFC49BFF)
                              : const Color(0xFF73B7FF),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (pickupText.isNotEmpty)
                        DriverPill(
                          label: "Giờ đón $pickupText",
                          icon: Icons.access_time_rounded,
                        ),
                      if (ride.rideTypeOrQuantityText.isNotEmpty)
                        DriverPill(
                          label: ride.rideTypeOrQuantityText,
                          icon: ride.type == 1
                              ? Icons.event_seat_rounded
                              : Icons.directions_car_filled_rounded,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationLine(
                  theme,
                  '${ride.fromProvince} - ${ride.fromDistrict}',
                  ride.fromAddress,
                  '${ride.toProvince} - ${ride.toDistrict}',
                  ride.toAddress,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _miniInfo(
                          theme,
                          "Thanh toán",
                          ride.paymentMethod.isEmpty
                              ? "Chưa xác định"
                              : ride.paymentMethod,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ride.formattedPrice,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ride.status == 2 || ride.status == 3) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => ride.status == 2
                          ? _handleStartRide(ride)
                          : _handleCompleteRide(ride),
                      icon: Icon(
                        ride.status == 2
                            ? Icons.play_circle_fill_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        ride.status == 2
                            ? "Bắt đầu di chuyển"
                            : "Xác nhận hoàn thành",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ride.status == 2
                            ? const Color(0xFF73B7FF)
                            : const Color(0xFF6ED39B),
                        foregroundColor: Colors.black87,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrokerRideCard(BrokerRideItem ride, ThemeData theme) {
    final statusColor = _brokerStatusColor(ride.status);
    final statusText = _brokerStatusText(ride.status);
    final canCancel = ride.status == 0 || ride.status == 1;
    final pickupText = ride.pickupTime == null
        ? ''
        : _formatDateTime(ride.pickupTime!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGreen.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateBrokerToDetail(ride),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.code,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTime(ride.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DriverPill(label: statusText, color: statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (pickupText.isNotEmpty)
                        DriverPill(
                          label: "Giờ đón $pickupText",
                          icon: Icons.access_time_rounded,
                        ),
                      if (ride.rideTypeOrQuantityText.isNotEmpty)
                        DriverPill(
                          label: ride.rideTypeOrQuantityText,
                          icon: ride.type == 1
                              ? Icons.event_seat_rounded
                              : Icons.directions_car_filled_rounded,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationLine(
                  theme,
                  '${ride.fromProvince} - ${ride.fromDistrict}',
                  ride.fromAddress,
                  '${ride.toProvince} - ${ride.toDistrict}',
                  ride.toAddress,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _miniInfo(
                          theme,
                          "Thanh toán",
                          ride.paymentMethod.isEmpty
                              ? "Chưa xác định"
                              : ride.paymentMethod,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatMoney(ride.price),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingBroker
                          ? null
                          : () => _handleCancelBrokerRide(ride),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text("Huỷ đơn đã đẩy"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8A8A),
                        side: const BorderSide(color: Color(0xFFFF8A8A)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatMoney(num value) {
    return '${value.toStringAsFixed(0)} đ';
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  Color _brokerStatusColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFFFFB347);
      case 1:
        return const Color(0xFFE5C17B);
      case 2:
        return const Color(0xFF73B7FF);
      case 3:
        return const Color(0xFF8FA8FF);
      case 4:
        return const Color(0xFF6ED39B);
      case 5:
        return const Color(0xFFFF8A8A);
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

  Widget _buildLocationLine(
    ThemeData theme,
    String fromTitle,
    String fromAddress,
    String toTitle,
    String toAddress,
  ) {
    return Column(
      children: [
        _buildLocationPoint(
          theme,
          icon: Icons.trip_origin_rounded,
          color: const Color(0xFF6ED39B),
          title: fromTitle,
          address: fromAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Container(
            width: 2,
            height: 24,
            color: theme.colorScheme.secondary.withValues(alpha: 0.22),
          ),
        ),
        _buildLocationPoint(
          theme,
          icon: Icons.location_on_rounded,
          color: const Color(0xFFFF8A8A),
          title: toTitle,
          address: toAddress,
        ),
      ],
    );
  }

  Widget _buildLocationPoint(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubtle,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
