import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/waiting_ride_model.dart';
import '../../providers/received_order_provider.dart';
import '../../widgets/driver_ui.dart';
import '../popup_list/insufficient_balance_popup.dart';
import '../popup_list/has_accepted_popup.dart';
import '../popup_list/received_success_popup.dart';

class RecieveOrderScreen extends StatelessWidget {
  const RecieveOrderScreen({
    super.key,
    this.onReceiveSuccessNavigateToActivity,
  });

  /// Sau khi đóng popup nhận đơn thành công — chuyển sang tab Hoạt động (Đang diễn ra).
  final VoidCallback? onReceiveSuccessNavigateToActivity;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecieveOrderProvider(),
      child: _RecieveOrderView(
        onReceiveSuccessNavigateToActivity: onReceiveSuccessNavigateToActivity,
      ),
    );
  }
}

class _RecieveOrderView extends StatefulWidget {
  const _RecieveOrderView({this.onReceiveSuccessNavigateToActivity});

  final VoidCallback? onReceiveSuccessNavigateToActivity;

  @override
  State<_RecieveOrderView> createState() => _RecieveOrderViewState();
}

class _RecieveOrderViewState extends State<_RecieveOrderView> {
  bool _didInitProvider = false;

  String _paymentMethodLabel(int paymentMethod) {
    switch (paymentMethod) {
      case 1:
        return 'Chuyển khoản';
      case 2:
        return 'Ví';
      case 3:
        return 'Tiền mặt (COD)';
      default:
        return 'Chưa xác định';
    }
  }

  IconData _paymentMethodIcon(int paymentMethod) {
    switch (paymentMethod) {
      case 1:
        return Icons.account_balance_outlined;
      case 2:
        return Icons.account_balance_wallet_outlined;
      case 3:
        return Icons.payments_outlined;
      default:
        return Icons.help_outline_rounded;
    }
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
      await provider.ensureInitialWaitingOrdersLoaded();
    });
  }

  Future<void> _acceptRide(
    BuildContext context,
    RecieveOrderProvider provider,
    WaitingRide ride,
  ) async {
    final result = await provider.acceptRide(ride);

    if (!mounted || !context.mounted) return;

    final reason = result['reason'] as String? ?? 'error';

    switch (reason) {
      case 'success':
        provider.syncWaitingOrdersAfterAccept();
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const ReceivedSuccessPopup(),
        );
        if (!mounted || !context.mounted) return;
        widget.onReceiveSuccessNavigateToActivity?.call();
        break;

      case 'insufficient_balance':
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const InsufficientBalancePopup(),
        );
        break;

      case 'already_accepted':
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const HasAcceptedPopup(),
        );
        break;

      default:
        // Lỗi không xác định — giữ snackbar để dễ debug
        if (mounted && context.mounted) {
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
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildSortFilter(context, provider),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await provider.loadMyBrokerRideIds();
                      await provider.refreshWaitingOrders();
                    },
                    child: SafeArea(
                      bottom: true,
                      child: PagedListView<int, WaitingRideListItem>(
                        pagingController: provider.pagingController,
                        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        builderDelegate:
                            PagedChildBuilderDelegate<WaitingRideListItem>(
                              animateTransitions: true,
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
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                              firstPageProgressIndicatorBuilder: (_) =>
                                  const Padding(
                                    padding: EdgeInsets.only(top: 80),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
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
          ),
        );
      },
    );
  }



  Widget _buildSortFilter(BuildContext context, RecieveOrderProvider provider) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
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
    WaitingRide ride,
  ) {
    final theme = Theme.of(context);

    final int rideSource = provider.extractRideSource(ride);

    final String code = ride.code ?? '---';

    final dynamic pickupTime = ride.pickupTime;

    final String fromAddressRaw = ride.fromAddress ?? '';
    final String fromDistrictRaw = ride.fromDistrict ?? '';
    final String fromProvinceRaw = ride.fromProvince ?? '';
    final String toAddressRaw = ride.toAddress ?? '';
    final String toDistrictRaw = ride.toDistrict ?? '';
    final String toProvinceRaw = ride.toProvince ?? '';

    final String rideTypeOrQuantityText = provider.rideTypeOrQuantityText(ride);
    final bool shouldShowRideTypeOrQuantityText = provider
        .shouldShowRideTypeOrQuantity(ride);
    final int paymentMethod = ride.paymentMethod;
    final bool shouldShowPaymentMethod = paymentMethod > 0;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGreen.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.16),
              ),
            ),
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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DriverPill(
                          label: "Giờ đón $pickupText",
                          icon: Icons.access_time_rounded,
                        ),
                        if (shouldShowRideTypeOrQuantityText)
                          DriverPill(
                            label: rideTypeOrQuantityText,
                            icon: Icons.event_seat_rounded,
                          ),
                        if (shouldShowPaymentMethod)
                          DriverPill(
                            label: _paymentMethodLabel(paymentMethod),
                            icon: _paymentMethodIcon(paymentMethod),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _buildLocationRow(
                          context,
                          Icons.circle,
                          Colors.green,
                          fromText,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 2,
                              height: 22,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                        _buildLocationRow(
                          context,
                          Icons.location_on,
                          Colors.red,
                          toText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildCardFooter(
                    context,
                    provider,
                    ride,
                    theme,
                    totalPrice,
                    netIncome,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFooter(
    BuildContext context,
    RecieveOrderProvider provider,
    WaitingRide ride,
    ThemeData theme,
    double totalPrice,
    double netIncome,
  ) {
    final bool isMyBrokerRide = provider.isMyBrokerRide(ride);
    final int rideSource = provider.extractRideSource(ride);
    final bool isCancelAction = rideSource == 2 && isMyBrokerRide;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Giá tiền",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${NumberFormat('#,###').format(totalPrice)} đ",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Thu nhập ròng",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.greenAccent.shade100,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${NumberFormat('#,###').format(netIncome)} đ",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: isCancelAction
              ? ElevatedButton(
                  onPressed: provider.loadingMyBrokerRides
                      ? null
                      : () => _cancelMyBrokerRide(context, provider, ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("HỦY ĐƠN ĐÃ ĐẨY"),
                )
              : ElevatedButton(
                  onPressed: () => _acceptRide(context, provider, ride),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("NHẬN ĐƠN NGAY"),
                ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: DriverEmptyState(
        icon: Icons.inbox_outlined,
        title: "Chưa có đơn hàng chờ",
        message:
            "Hệ thống sẽ cập nhật ngay khi có chuyến phù hợp. Bạn có thể vuốt xuống để làm mới danh sách.",
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
