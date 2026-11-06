import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/driver/broker_rides_model.dart';
import '../../models/driver/ride_model.dart';
import '../../providers/driver/activity_history_provider.dart';
import '../../widgets/driver_ui.dart';
import '../popup_list/action_success_popup.dart';
import 'ride_detail_screen.dart';
import '../../ui/ui.dart';

class ActivityScreen extends StatelessWidget {
  final int initialTabIndex;

  const ActivityScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActivityHistoryProvider(),
      child: _ActivityView(initialTabIndex: initialTabIndex),
    );
  }
}

class _ActivityView extends StatefulWidget {
  const _ActivityView({required this.initialTabIndex});

  final int initialTabIndex;

  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final safeInitial = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: safeInitial,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActivityHistoryProvider>().preloadTabData(safeInitial);
    });

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
    final provider = context.read<ActivityHistoryProvider>();

    if (_tabController.index == 0 &&
        !provider.isOngoingLoaded &&
        !provider.isLoadingOngoing) {
      provider.fetchOngoingRides();
    }
    if (_tabController.index == 1 &&
        !provider.isHistoryLoaded &&
        !provider.isLoadingHistory) {
      provider.fetchHistoryRides();
    }
    if (_tabController.index == 2 &&
        !provider.isBrokerLoaded &&
        !provider.isLoadingBroker) {
      provider.fetchBrokerRides();
    }
  }

  Future<void> _handleCancelBrokerRide(BrokerRideItem ride) async {
    final theme = Theme.of(context);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          "Huỷ đơn đã đẩy",
          style: TextStyle(
            color: Brand.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "Bạn chắc chắn muốn huỷ đơn ${ride.code} không?",
          style: const TextStyle(color: Brand.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Brand.inkMuted),
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
    final provider = context.read<ActivityHistoryProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await provider.cancelBrokerRide(ride);
      navigator.pop();

      if (success) {
        if (!mounted) return;
        await ActionSuccessPopup.show(
          context,
          title: 'Huỷ đơn thành công',
          message: 'Đơn ${ride.code} đã được huỷ thành công.',
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Huỷ đơn thất bại."),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text("Có lỗi xảy ra: $e"),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleStartRide(RideModel ride) async {
    final theme = Theme.of(context);
    if (!mounted) return;
    final provider = context.read<ActivityHistoryProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final ok = await provider.startRide(ride);

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã xuất phát chuyến ${ride.code}."),
          backgroundColor: Brand.navy,
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
        await provider.fetchOngoingRides();
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
    if (!mounted) return;
    final provider = context.read<ActivityHistoryProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final ok = await provider.completeRide(ride);

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (ok) {
      await ActionSuccessPopup.show(
        context,
        title: 'Hoàn thành chuyến thành công',
        message: 'Chuyến xe ${ride.code} đã được hoàn thành thành công.',
      );
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
      if (!mounted) return;
      final provider = context.read<ActivityHistoryProvider>();
      if (_tabController.index == 0) {
        provider.fetchOngoingRides();
      }
      if (provider.isHistoryLoaded) {
        provider.fetchHistoryRides();
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
      if (!mounted) return;
      final provider = context.read<ActivityHistoryProvider>();
      if (_tabController.index == 2) {
        await provider.fetchBrokerRides();
      }
      if (_tabController.index == 0) {
        await provider.fetchOngoingRides();
      }
      if (provider.isHistoryLoaded) {
        await provider.fetchHistoryRides();
      }
    });
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
    final provider = context.watch<ActivityHistoryProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Hoạt động",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Brand.navy,
          ),
        ),
      ),
      body: Stack(
        children: [
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
                    _buildOngoingTab(theme, provider),
                    _buildHistoryTab(theme, provider),
                    _buildBrokerTab(theme, provider),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.white,
        unselectedLabelColor: Brand.inkMuted,
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

  Widget _buildOngoingTab(
    ThemeData theme,
    ActivityHistoryProvider provider,
  ) {
    if (provider.isLoadingOngoing) {
      return Center(
        child: CircularProgressIndicator(color: Brand.navy),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.fetchOngoingRides,
      child: _buildRideList(
        rides: provider.ongoingRides,
        emptyTitle: "Chưa có chuyến đang diễn ra",
        emptyMessage:
            "Đơn bạn nhận sẽ hiện ở đây.",
        provider: provider,
      ),
    );
  }

  Widget _buildHistoryTab(
    ThemeData theme,
    ActivityHistoryProvider provider,
  ) {
    if (provider.isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(color: Brand.navy),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.fetchHistoryRides,
      child: _buildRideList(
        rides: provider.historyRides,
        emptyTitle: "Chưa có lịch sử chuyến",
        emptyMessage:
            "Chuyến hoàn thành sẽ được lưu ở đây.",
        provider: provider,
      ),
    );
  }

  Widget _buildBrokerTab(
    ThemeData theme,
    ActivityHistoryProvider provider,
  ) {
    if (provider.isLoadingBroker) {
      return Center(
        child: CircularProgressIndicator(color: Brand.navy),
      );
    }

    if (provider.brokerRides.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.fetchBrokerRides,
        child: ListView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: _listPadding(context),
          children: [
            const SizedBox(height: 48),
            const DriverEmptyState(
              icon: Icons.move_down_rounded,
              title: "Chưa có đơn nào được đẩy",
              message: "Đơn bạn đẩy sẽ hiện ở đây.",
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchBrokerRides,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _listPadding(context),
        itemCount: provider.brokerRides.length + 2,
        itemBuilder: (context, index) {
          if (index < 2) return const SizedBox.shrink();
          return _buildBrokerRideCard(provider.brokerRides[index - 2], theme);
        },
      ),
    );
  }

  Widget _buildRideList({
    required List<RideModel> rides,
    required String emptyTitle,
    required String emptyMessage,
    required ActivityHistoryProvider provider,
  }) {
    final theme = Theme.of(context);

    if (rides.isEmpty) {
      return ListView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: _listPadding(context),
        children: [
          const SizedBox(height: 48),
          DriverEmptyState(
            icon: Icons.route_rounded,
            title: emptyTitle,
            message: emptyMessage,
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
        if (index < 2) return const SizedBox.shrink();
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
        return Brand.info;
      case 3:
        return Brand.warning;
      case 4:
        return Brand.success;
      case 5:
        return Brand.danger;
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
        color: Brand.b50.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A041565),
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
                              color: Brand.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ride.formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Brand.inkMuted,
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
                              : Brand.info,
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
                    color: Brand.b50,
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
                          color: Brand.navy,
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
                            ? Brand.info
                            : Brand.success,
                        foregroundColor: Colors.white,
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
        color: Brand.b50.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A041565),
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
                              color: Brand.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTime(ride.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Brand.inkMuted,
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
                    color: Brand.b50,
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
                          color: Brand.navy,
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
                      onPressed: context.watch<ActivityHistoryProvider>().isLoadingBroker
                          ? null
                          : () => _handleCancelBrokerRide(ride),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text("Huỷ đơn đã đẩy"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Brand.danger,
                        side: const BorderSide(color: Brand.danger),
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
            color: Brand.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Brand.ink,
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
        return Brand.warning;
      case 1:
        return Brand.lane;
      case 2:
        return Brand.info;
      case 3:
        return const Color(0xFF8FA8FF);
      case 4:
        return Brand.success;
      case 5:
        return Brand.danger;
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
          color: Brand.success,
          title: fromTitle,
          address: fromAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Container(
            width: 2,
            height: 24,
            color: Brand.navy.withValues(alpha: 0.22),
          ),
        ),
        _buildLocationPoint(
          theme,
          icon: Icons.location_on_rounded,
          color: Brand.danger,
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
                  color: Brand.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Brand.inkMuted,
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
