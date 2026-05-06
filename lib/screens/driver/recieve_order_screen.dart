import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../../models/waiting_ride_model.dart';
import '../../providers/recieve_order_provider.dart';
import '../popup_list/insufficient_balance_popup.dart';
import '../popup_list/has_accepted_popup.dart';
import '../popup_list/received_success_popup.dart';
import 'ride_detail_screen.dart';

class RecieveOrderScreen extends StatelessWidget {
  const RecieveOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecieveOrderProvider(),
      child: const _RecieveOrderView(),
    );
  }
}

class _RecieveOrderView extends StatefulWidget {
  const _RecieveOrderView();

  @override
  State<_RecieveOrderView> createState() => _RecieveOrderViewState();
}

class _RecieveOrderViewState extends State<_RecieveOrderView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _didInitProvider = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitProvider) return;
    _didInitProvider = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<RecieveOrderProvider>();
      await provider.init();
    });
  }

  /// Mỗi lần chuyển sang tab "Đơn đã nhận" đều gọi API load lại danh sách,
  /// không cache — đảm bảo luôn có dữ liệu mới nhất.
  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) return;

    if (_tabController.index == 1) {
      final provider = context.read<RecieveOrderProvider>();
      provider.loadAcceptedRides();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptRide(
      BuildContext context,
      RecieveOrderProvider provider,
      WaitingRide ride,
      ) async {
    final result = await provider.acceptRide(ride);

    if (!mounted) return;

    final reason = result['reason'] as String? ?? 'error';

    switch (reason) {
      case 'success':
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ReceivedSuccessPopup(),
        );
        // Reload danh sách đơn đã nhận sau khi user đóng popup
        if (mounted) {
          provider.loadAcceptedRides();
        }
        break;

      case 'insufficient_balance':
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const InsufficientBalancePopup(),
        );
        break;

      case 'already_accepted':
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const HasAcceptedPopup(),
        );
        break;

      default:
      // Lỗi không xác định — giữ snackbar để dễ debug
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Có lỗi xảy ra'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
    }
  }

  Future<void> _cancelMyBrokerRide(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Huỷ đơn đã đẩy"),
        content: const Text("Bạn chắc chắn muốn huỷ chuyến?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text("Huỷ"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await provider.cancelMyBrokerRide(ride);

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true
            ? Colors.green
            : theme.colorScheme.error,
      ),
    );
  }

  Future<void> _startRide(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await provider.startRide(ride);

    if (!mounted) return;

    if (result['success'] == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );

      navigator.push(
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(
            rideId: result['rideId'],
            rideSource: result['rideSource'],
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _navigateToDetail(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ) {
    final int rideId = provider.extractRideId(ride);
    final int rideSource = provider.extractRideSource(ride);

    if (rideId != 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RideDetailScreen(rideId: rideId, rideSource: rideSource),
        ),
      );
    }
  }

  Color _rideSourceColor(int rideSource, ThemeData theme) {
    switch (rideSource) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.55);
    }
  }

  Widget _rideSourceChip(
      RecieveOrderProvider provider,
      int rideSource,
      ThemeData theme,
      ) {
    final color = _rideSourceColor(rideSource, theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        provider.rideSourceText(rideSource),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<RecieveOrderProvider>(
      builder: (context, provider, _) {
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              unselectedLabelColor: Colors.white70,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              indicatorColor: theme.colorScheme.secondary,
              indicatorWeight: 5.5,
              tabs: const [
                Tab(text: "ĐƠN MỚI", icon: Icon(Icons.fiber_new_rounded)),
                Tab(
                  text: "ĐƠN ĐÃ NHẬN",
                  icon: Icon(Icons.assignment_turned_in_rounded),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Đơn mới ──────────────────────────────────────────
              Column(
                children: [
                  _buildSortFilter(context, provider),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await provider.loadMyBrokerRideIds();
                        provider.pagingController.refresh();
                      },
                      child: SafeArea(
                        bottom: true,
                        child: PagedListView<int, WaitingRideListItem>(
                          pagingController: provider.pagingController,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            bottomPadding,
                          ),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          builderDelegate:
                          PagedChildBuilderDelegate<WaitingRideListItem>(
                            itemBuilder: (context, item, index) {
                              if (item is WaitingRideDateHeaderItem) {
                                return _buildCreatedAtHeader(
                                  context,
                                  provider,
                                  item,
                                );
                              }

                              if (item is WaitingRideCardItem) {
                                return _buildRideCard(
                                  context,
                                  provider,
                                  item.ride,
                                  true,
                                );
                              }

                              return const SizedBox.shrink();
                            },
                            noItemsFoundIndicatorBuilder: (_) =>
                                _buildEmptyPlaceholder(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Tab 2: Đơn đã nhận ──────────────────────────────────────
              provider.isLoadingAcceptedRides
                  ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.secondary,
                ),
              )
                  : RefreshIndicator(
                onRefresh: provider.loadAcceptedRides,
                child: SafeArea(
                  bottom: true,
                  child: _buildOldOrderList(
                    context,
                    provider,
                    provider.acceptedRidesStatus2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortFilter(BuildContext context, RecieveOrderProvider provider) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.swap_vert_rounded, color: theme.colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<WaitingRideSortOption>(
                  value: provider.sortOption,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  items: WaitingRideSortOption.values
                      .map(
                        (option) => DropdownMenuItem<WaitingRideSortOption>(
                      value: option,
                      child: Text(provider.sortOptionLabel(option)),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.setSortOption(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedAtHeader(
      BuildContext context,
      RecieveOrderProvider provider,
      WaitingRideDateHeaderItem item,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              provider.formatCreatedDateHeader(item.date),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      bool isNew,
      ) {
    final theme = Theme.of(context);

    final int rideSource = provider.extractRideSource(ride);

    final String code = (ride is WaitingRide)
        ? (ride.code ?? '---')
        : (ride['code'] ?? '---');

    final dynamic pickupTime = (ride is WaitingRide)
        ? ride.pickupTime
        : provider.extractDynamicFromMap(ride, [
      'pickupTime',
      'pickup_time',
      'pickupAt',
      'pickup_at',
      'pickuptime',
      'pickupDate',
      'pickup_date',
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
      fromDistrictRaw = provider.extractProvinceFromMap(ride, [
        'fromDistrict',
        'fromDistrictName',
        'from_district',
        'from_district_name',
      ]);
      fromProvinceRaw = provider.extractProvinceFromMap(ride, [
        'fromProvince',
        'fromProvinceName',
        'from_province',
        'from_province_name',
      ]);
      toAddressRaw = ride['toAddress']?.toString() ?? '';
      toDistrictRaw = provider.extractProvinceFromMap(ride, [
        'toDistrict',
        'toDistrictName',
        'to_district',
        'to_district_name',
      ]);
      toProvinceRaw = provider.extractProvinceFromMap(ride, [
        'toProvince',
        'toProvinceName',
        'to_province',
        'to_province_name',
      ]);
    }

    final String fromText = provider.buildFullAddress(
      fromAddressRaw,
      fromDistrictRaw,
      fromProvinceRaw,
    );
    final String toText = provider.buildFullAddress(
      toAddressRaw,
      toDistrictRaw,
      toProvinceRaw,
    );

    final String pickupText = _displayPickupTime(provider, pickupTime);

    final double totalPrice = provider.extractRidePrice(ride);
    final double netIncome = provider.extractRideNetIncome(ride);

    final VoidCallback? onTapCard = isNew
        ? null
        : () => _navigateToDetail(context, provider, ride);

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
                    _rideSourceChip(provider, rideSource, theme),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Giờ đón: ",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
                Divider(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                _buildLocationRow(
                  context,
                  Icons.circle,
                  Colors.green,
                  fromText,
                ),
                _buildLocationRow(
                  context,
                  Icons.location_on,
                  Colors.red,
                  toText,
                ),
                Divider(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                _buildCardFooter(
                  context,
                  provider,
                  ride,
                  theme,
                  isNew,
                  totalPrice,
                  netIncome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFooter(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ThemeData theme,
      bool isNew,
      double totalPrice,
      double netIncome,
      ) {
    final bool isMyBrokerRide = provider.isMyBrokerRide(ride);
    final int rideSource = provider.extractRideSource(ride);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Giá tiền: ${NumberFormat('#,###').format(totalPrice)} đ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Thu nhập ròng: ${NumberFormat('#,###').format(netIncome)} đ",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isNew && rideSource == 2 && isMyBrokerRide) ...[
          ElevatedButton(
            onPressed: provider.loadingMyBrokerRides
                ? null
                : () => _cancelMyBrokerRide(context, provider, ride),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text("HUỶ ĐƠN"),
          ),
        ] else if (isNew) ...[
          ElevatedButton(
            onPressed: () =>
                _acceptRide(context, provider, ride as WaitingRide),
            child: const Text("NHẬN ĐƠN"),
          ),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => _navigateToDetail(context, provider, ride),
                child: const Text("CHI TIẾT"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _startRide(context, provider, ride),
                child: const Text("XUẤT PHÁT"),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocationRow(
      BuildContext context,
      IconData icon,
      Color color,
      String address,
      ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOldOrderList(
      BuildContext context,
      RecieveOrderProvider provider,
      List<Map<String, dynamic>> rides,
      ) {
    if (rides.isEmpty) return _buildEmptyList(context);

    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = 12.0 + 24.0 + bottomSafe;

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
      itemCount: rides.length,
      itemBuilder: (context, index) =>
          _buildRideCard(context, provider, rides[index], false),
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
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

  Widget _buildEmptyList(BuildContext context) {
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

  String _displayPickupTime(RecieveOrderProvider provider, dynamic value) {
    if (value == null) return '';
    try {
      if (value is int) {
        final int ms = value.abs() > 1000000000000 ? value : value * 1000;
        return DateFormat(
          'HH:mm dd/MM',
        ).format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      final s = value.toString().trim();
      if (s.isEmpty) return '';

      if (RegExp(r'^\d+$').hasMatch(s)) {
        final int v = int.parse(s);
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateFormat(
          'HH:mm dd/MM',
        ).format(DateTime.fromMillisecondsSinceEpoch(ms));
      }

      final dt = DateTime.parse(s);
      return DateFormat('HH:mm dd/MM').format(dt);
    } catch (_) {
      return value.toString();
    }
  }
}