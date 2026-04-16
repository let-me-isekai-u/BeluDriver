import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../../models/waiting_ride_model.dart';
import '../../providers/recieve_order_provider.dart';
import 'ride_detail_screen.dart';

class RecieveOrderScreen extends StatefulWidget {
  const RecieveOrderScreen({super.key});

  @override
  State<RecieveOrderScreen> createState() => _RecieveOrderScreenState();
}

class _RecieveOrderScreenState extends State<RecieveOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider =
      Provider.of<RecieveOrderProvider>(context, listen: false);
      await provider.init();
    });

    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    final provider = Provider.of<RecieveOrderProvider>(context, listen: false);
    if (_tabController.index == 1 && !provider.isAcceptedLoaded) {
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
    final theme = Theme.of(context);
    final result = await provider.acceptRide(ride);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true
            ? theme.colorScheme.secondary
            : theme.colorScheme.error,
      ),
    );
  }

  Future<void> _cancelMyBrokerRide(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ) async {
    final theme = Theme.of(context);

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor:
        result['success'] == true ? Colors.green : theme.colorScheme.error,
      ),
    );
  }

  Future<void> _startRide(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      ) async {
    final theme = Theme.of(context);
    final result = await provider.startRide(ride);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(
            rideId: result['rideId'],
            rideSource: result['rideSource'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
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
          builder: (_) => RideDetailScreen(
            rideId: rideId,
            rideSource: rideSource,
          ),
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
        return theme.colorScheme.onSurface.withOpacity(0.55);
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
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

    return ChangeNotifierProvider(
      create: (_) => RecieveOrderProvider(),
      child: Consumer<RecieveOrderProvider>(
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
                labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelColor: Colors.white70,
                unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600),
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
                Column(
                  children: [
                    _buildLocationFilter(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await provider.loadMyBrokerRideIds();
                          provider.pagingController.refresh();
                        },
                        child: SafeArea(
                          bottom: true,
                          child: PagedListView<int, WaitingRide>(
                            pagingController: provider.pagingController,
                            padding:
                            EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            builderDelegate:
                            PagedChildBuilderDelegate<WaitingRide>(
                              itemBuilder: (context, item, index) =>
                                  _buildRideCard(
                                    context,
                                    provider,
                                    item,
                                    true,
                                  ),
                              noItemsFoundIndicatorBuilder: (_) =>
                                  _buildEmptyPlaceholder(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      ),
    );
  }

  Widget _buildLocationFilter() {
    return const SizedBox.shrink();
  }

  Widget _buildRideCard(
      BuildContext context,
      RecieveOrderProvider provider,
      dynamic ride,
      bool isNew,
      ) {
    final theme = Theme.of(context);

    final int rideSource = provider.extractRideSource(ride);

    final String code =
    (ride is WaitingRide) ? (ride.code ?? '---') : (ride['code'] ?? '---');

    final dynamic pickupTime = (ride is WaitingRide)
        ? ride.pickupTime
        : provider.extractDynamicFromMap(ride, [
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
      fromDistrictRaw = provider.extractProvinceFromMap(ride, [
        'fromDistrict',
        'fromDistrictName',
        'from_district',
        'from_district_name'
      ]);
      fromProvinceRaw = provider.extractProvinceFromMap(ride, [
        'fromProvince',
        'fromProvinceName',
        'from_province',
        'from_province_name'
      ]);
      toAddressRaw = ride['toAddress']?.toString() ?? '';
      toDistrictRaw = provider.extractProvinceFromMap(ride, [
        'toDistrict',
        'toDistrictName',
        'to_district',
        'to_district_name'
      ]);
      toProvinceRaw = provider.extractProvinceFromMap(ride, [
        'toProvince',
        'toProvinceName',
        'to_province',
        'to_province_name'
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

    final double price = (ride is WaitingRide)
        ? ride.price
        : (double.tryParse((ride['price'] ?? '0').toString()) ?? 0);

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
                _buildLocationRow(context, Icons.circle, Colors.green, fromText),
                _buildLocationRow(context, Icons.location_on, Colors.red, toText),
                Divider(color: theme.colorScheme.onSurface.withOpacity(0.12)),
                _buildCardFooter(
                  context,
                  provider,
                  ride,
                  theme,
                  isNew,
                  price,
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
      double price,
      ) {
    final bool isMyBrokerRide = provider.isMyBrokerRide(ride);
    final int rideSource = provider.extractRideSource(ride);

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

      final dt = DateTime.parse(s);
      return DateFormat('HH:mm dd/MM').format(dt);
    } catch (_) {
      return value.toString();
    }
  }
}