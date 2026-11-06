import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../models/driver/driver_profile_model.dart';
import '../../providers/home_provider.dart';
import '../../providers/driver/deposit_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';
import '../chat_to_order/chat_group_list_screen.dart';
import '../kyc/kyc_deposit_requirement_popup.dart';
import '../kyc/kyc_popup.dart';
import '../popup_list/withdraw_request_failed_popup.dart';
import '../popup_list/withdraw_request_success_popup.dart';
import 'activity_history.dart';
import 'concert_ticket_scanner_screen.dart';
import 'driver_booking_screen.dart';
import 'driver_profile.dart';
import 'recieve_order_screen.dart';

import '../../providers/kyc/kyc_provider.dart';
import '../../providers/routes/register_route_provider.dart';
import '../register_route/register_route_popup.dart';
import '../../ui/ui.dart';

///test màn hình facedetection

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DepositProvider()),
      ],
      child: const _DriverHomeView(),
    );
  }
}

class _DriverDepositInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DriverDepositInfoTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0x33041565),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHomeView extends StatefulWidget {
  const _DriverHomeView();

  @override
  State<_DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<_DriverHomeView> {
  int _currentIndex = 2;
  bool _didTryShowPopup = false;
  int _activityScreenSeed = 0;

  static const String _depositPopupShownKey =
      'hasShownKycDepositRequirementPopup';
  static const num _requiredDepositAmount = 100000;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryShowOnboardingPopup();
  }

  // TODO: Bật lại khi cần — tạm vô hiệu hoá popup ký quỹ
  Future<void> _showDepositRequirementPopupIfNeeded(
    HomeProvider provider,
  ) async {
    return; // DISABLED

    // ignore: dead_code
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_depositPopupShownKey) ?? false;

    final kycStatus = provider.kycStatus;
    final wallet = provider.profile?.wallet ?? 0;
    final shouldShowDepositPopup = kycStatus != 2 && wallet == 0;

    debugPrint('[HOME] depositPopup.hasShown = $hasShown');
    debugPrint('[HOME] depositPopup.kycStatus = $kycStatus');
    debugPrint('[HOME] depositPopup.wallet = $wallet');
    debugPrint(
      '[HOME] depositPopup.shouldShowDepositPopup = $shouldShowDepositPopup',
    );

    if (hasShown || !shouldShowDepositPopup || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const KycDepositRequirementPopup(amount: _requiredDepositAmount),
    );

    await prefs.setBool(_depositPopupShownKey, true);
    debugPrint('[HOME] Deposit requirement popup marked as shown');
  }

  Future<void> _tryShowOnboardingPopup() async {
    if (_didTryShowPopup) return;

    final homeProvider = context.read<HomeProvider>();

    if (!homeProvider.hasCheckedKycPopup) return;
    if (homeProvider.isLoadingProfile) return;
    if (homeProvider.isLoadingOnboardingStatus) return;
    if (homeProvider.profile == null) return;
    if (!mounted) return;

    _didTryShowPopup = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 1. Chưa đăng ký tuyến -> show popup đăng ký tuyến trước
      if (homeProvider.shouldShowRegisterRoutePopup) {
        debugPrint("[HOME] Opening Register Route popup...");

        final routeRegistered = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => RegisterRouteProvider(),
            child: const RegisterRoutePopup(),
          ),
        );

        await homeProvider.markRegisterRoutePopupShown();
        await homeProvider.refreshProfile();

        if (!mounted) return;

        final updatedProvider = context.read<HomeProvider>();

        // Nếu vừa đăng ký tuyến xong và cần KYC thì show tiếp KYC
        if (routeRegistered == true && updatedProvider.shouldShowKycPopup) {
          debugPrint("[HOME] Register route done -> Opening KYC popup...");

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ChangeNotifierProvider(
              create: (_) => KycProvider(),
              child: const KycPopup(),
            ),
          );

          await updatedProvider.markKycPopupShown();
          await updatedProvider.refreshProfile();
        }

        if (!mounted) return;

        await _showDepositRequirementPopupIfNeeded(
          context.read<HomeProvider>(),
        );
        return;
      }

      // 2. Đã có tuyến rồi, nếu cần thì show KYC
      if (homeProvider.shouldShowKycPopup) {
        debugPrint("[HOME] Opening KYC popup...");

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ChangeNotifierProvider(
            create: (_) => KycProvider(),
            child: const KycPopup(),
          ),
        );

        await homeProvider.markKycPopupShown();
        await homeProvider.refreshProfile();

        if (!mounted) return;

        await _showDepositRequirementPopupIfNeeded(
          context.read<HomeProvider>(),
        );
        return;
      }

      // 3. Không cần route/KYC popup nữa -> check popup ký quỹ
      await _showDepositRequirementPopupIfNeeded(homeProvider);
    });
  }

  Future<void> _showKycRequiredDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Chưa thể nhận đơn"),
        content: const Text(
          "Tài khoản của bạn cần được duyệt KYC trước khi vào màn hình Nhận đơn.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Brand.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
            ),
            child: const Text("Tôi đã hiểu"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNavigationRequest(
    int index,
    HomeProvider homeProvider,
  ) async {
    final isReceiveOrderTab = index == 0;
    final isKycApproved = homeProvider.kycStatus == 2;

    if (isReceiveOrderTab && !isKycApproved) {
      await _showKycRequiredDialog();
      return;
    }

    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _handleBottomNavigationTap(
    int bottomIndex,
    HomeProvider homeProvider,
  ) async {
    if (bottomIndex == 2) {
      _openConcertTicketScanner();
      return;
    }

    final screenIndex = bottomIndex > 2 ? bottomIndex - 1 : bottomIndex;
    await _handleNavigationRequest(screenIndex, homeProvider);
  }

  void _navigateToActivityOngoingTab() {
    if (!mounted) return;
    setState(() {
      _activityScreenSeed++;
      _currentIndex = 3;
    });
  }

  void _openConcertTicketScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConcertTicketScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = Brand.navy;
    final homeProvider = context.watch<HomeProvider>();
    final bottomNavigationIndex = _currentIndex >= 2
        ? _currentIndex + 1
        : _currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tryShowOnboardingPopup();
      }
    });

    final List<Widget> screens = [
      RecieveOrderScreen(
        onReceiveSuccessNavigateToActivity: _navigateToActivityOngoingTab,
      ),
      DriverBookingScreen(onGoToPushedOrdersTab: _navigateToActivityOngoingTab),
      _HomeDashboard(
        profile: homeProvider.profile,
        isLoading: homeProvider.isLoadingProfile,
        homeProvider: homeProvider,
        onNavigate: (index) => _handleNavigationRequest(index, homeProvider),
        onRefreshProfile: homeProvider.refreshProfile,
      ),
      ActivityScreen(
        key: ValueKey('activity_$_activityScreenSeed'),
        initialTabIndex: 0,
      ),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: _currentIndex == 2
          ? _buildCustomAppBar(
              theme,
              homeProvider.profile,
              homeProvider.isLoadingProfile,
            )
          : null,
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Color(0x14041565), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: bottomNavigationIndex,
          onTap: (index) => _handleBottomNavigationTap(index, homeProvider),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: goldColor,
          unselectedItemColor: Brand.inkMuted,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_turned_in_rounded),
              label: 'Nhận đơn',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_rounded),
              label: 'Đẩy đơn',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Soát vé',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _currentIndex == 2 ? goldColor : Brand.b50,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (_currentIndex == 2)
                      BoxShadow(
                        color: goldColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 30,
                  color: _currentIndex == 2
                      ? Colors.white
                      : Brand.navy,
                ),
              ),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              label: 'Hoạt động',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.person_rounded),
                  if (homeProvider.kycStatus != 2)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Brand.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar(
    ThemeData theme,
    DriverProfileModel? profile,
    bool isLoadingProfile,
  ) {
    return AppBar(
      toolbarHeight: 95,
      backgroundColor: Brand.navy,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            foregroundImage: (profile != null && profile.avatarUrl.isNotEmpty)
                ? NetworkImage(profile.avatarUrl)
                : null,
            child: (profile == null || profile.avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 26, color: Brand.navy)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoadingProfile
                      ? "Đang tải..."
                      : (profile?.fullName ?? "Tài xế"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Chúc bạn một ngày làm việc an toàn ",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Brand.b200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  final DriverProfileModel? profile;
  final bool isLoading;
  final HomeProvider homeProvider;
  final Function(int) onNavigate;
  final Future<void> Function() onRefreshProfile;

  const _HomeDashboard({
    required this.profile,
    required this.isLoading,
    required this.homeProvider,
    required this.onNavigate,
    required this.onRefreshProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = profile?.wallet ?? 0;
    final routeCount = profile?.routes.length ?? 0;
    final canReceiveRide =
        homeProvider.onboardingStatus?.canReceiveRide ?? false;

    return RefreshIndicator(
      onRefresh: onRefreshProfile,
      color: Brand.navy,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(context, wallet, routeCount, canReceiveRide),
            const SizedBox(height: 16),
            if (!canReceiveRide || !homeProvider.hasRegisteredRoute) ...[
              _buildStatusBanner(context),
              const SizedBox(height: 16),
            ],
            BrandCard(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Row(children: [
                _quick(Icons.near_me_rounded, 'Nhận đơn', () => onNavigate(0)),
                _quick(Icons.upload_file_rounded, 'Đẩy đơn', () => onNavigate(1)),
                _quick(Icons.forum_rounded, 'Nhóm chat', () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverChatGroupListScreen()),
                    )),
                _quick(Icons.add_card_rounded, 'Nạp ví', () => _showDepositDialog(context, theme)),
                _quick(Icons.payments_outlined, 'Rút tiền', () => _showWithdrawDialog(context)),
              ]),
            ),
            if (profile != null && profile!.routes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader('Tuyến của bạn'),
              BrandCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final route in profile!.routes.take(5)) ...[
                    if (route != profile!.routes.first) const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: const IconTile(Icons.route_rounded, size: 40),
                      title: Text(route.name.isNotEmpty ? route.name : route.code,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text('${route.fromProvinceName} → ${route.toProvinceName}',
                          style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
                    ),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quick(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              IconTile(icon, size: 46, radius: 15),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _buildHeroCard(
    BuildContext context,
    double wallet,
    int routeCount,
    bool canReceiveRide,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Brand.navy, Brand.b700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A041565),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? "Đang tải hồ sơ..." : "Sẵn sàng làm việc?",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Brand.b200,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canReceiveRide
                          ? "Vào tab Nhận đơn để bắt đầu ca làm việc"
                          : "Hoàn tất trạng thái tài khoản để mở nhận đơn",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DriverPill(
                label: homeProvider.kycStatusTextSafe,
                icon: canReceiveRide
                    ? Icons.verified_rounded
                    : Icons.pending_actions_rounded,
                color: canReceiveRide
                    ? const Color(0xFF4ADE80)
                    : Brand.lane,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DriverStatTile(
                  label: "Số dư ví",
                  value: "${NumberFormat('#,###').format(wallet)} đ",
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DriverStatTile(
                  label: "Tuyến đã đăng ký",
                  value: "$routeCount tuyến",
                  icon: Icons.alt_route_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {

    String message;
    if (!homeProvider.hasRegisteredRoute) {
      message = "Bạn cần đăng ký tuyến trước khi bắt đầu nhận chuyến.";
    } else if (homeProvider.kycPendingReview) {
      message =
          "Hồ sơ KYC đang chờ duyệt.";
    } else if (homeProvider.kycStatus == 3) {
      message =
          "Hồ sơ KYC cần bổ sung.";
    } else {
      message =
          "Tài khoản chưa đủ điều kiện nhận đơn.";
    }

    return InfoBanner(
      '$message\nTiếp theo: ${homeProvider.nextStepLabel}',
      tone: Tone.warning,
      icon: Icons.flag_rounded,
    );
  }

  void _showDepositDialog(BuildContext parentContext, ThemeData theme) {
    final TextEditingController amountController = TextEditingController();
    final depositProvider = parentContext.read<DepositProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

    bool isSubmitting = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Brand.navy.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Brand.navy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Nạp tiền vào ví",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Brand.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nhập số tiền, hệ thống sẽ tạo mã QR chuyển khoản.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Brand.inkMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Brand.b50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Brand.navy.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Số tiền cần nạp",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Brand.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Brand.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ví dụ: 100000",
                          hintStyle: TextStyle(
                            color: Brand.inkSubtle,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Icon(
                            Icons.payments_outlined,
                            color: Brand.navy,
                          ),
                          suffixText: "đ",
                          suffixStyle: TextStyle(
                            color: Brand.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                          filled: true,
                          fillColor: const Color(0x1A041565),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Brand.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Huỷ"),
                ),
              ),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amount = int.tryParse(
                            amountController.text.replaceAll(',', '').trim(),
                          );

                          if (amount == null || amount <= 0) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Vui lòng nhập số tiền hợp lệ"),
                              ),
                            );
                            return;
                          }

                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('accessToken') ?? '';

                          if (token.isEmpty) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Không tìm thấy access token"),
                              ),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);

                          final ok = await depositProvider.createDepositRequest(
                            accessToken: token,
                            amount: amount,
                          );

                          if (!parentContext.mounted) return;

                          setState(() => isSubmitting = false);

                          if (!ok) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  depositProvider.errorMessage ??
                                      "Không thể tạo yêu cầu nạp tiền",
                                ),
                              ),
                            );
                            return;
                          }

                          final content = depositProvider.depositContent;
                          if (content == null || content.isEmpty) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Không nhận được nội dung chuyển khoản",
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          _showQRDialog(
                            parentContext,
                            theme,
                            amount,
                            content,
                            depositProvider,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Brand.navy,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Tạo yêu cầu"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQRDialog(
    BuildContext parentContext,
    ThemeData theme,
    int amount,
    String content,
    DepositProvider depositProvider,
  ) async {
    if (!parentContext.mounted) return;

    final qrUrl =
        "https://img.vietqr.io/image/MB-08102002-compact2.png?amount=$amount&addInfo=$content&accountName=CONG%20TY%20CP%20CONG%20NGHE%20VA%20QUAN%20LY%20VAN%20TAI%20DONG%20DUONG";

    int countdown = 300;
    Timer? countdownTimer;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown <= 0) {
                t.cancel();
                Navigator.pop(dialogCtx);
              } else {
                setState(() => countdown--);
              }
            });

            final minutes = countdown ~/ 60;
            final seconds = (countdown % 60).toString().padLeft(2, '0');

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Brand.navy.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.qr_code_rounded,
                            color: Brand.navy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "QR nạp ví",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Brand.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F2E7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'CONG TY CP CONG NGHE VA QUAN LY VAN TAI DONG DUONG',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Brand.navy,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(qrUrl, height: 220, width: 220),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DriverDepositInfoTile(
                            label: 'Số tiền',
                            value: "${NumberFormat('#,###').format(amount)} đ",
                            valueColor: Brand.navy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DriverDepositInfoTile(
                            label: 'Nội dung',
                            value: content,
                            valueColor: Brand.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Còn lại: $minutes:$seconds",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          countdownTimer?.cancel();
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('accessToken') ?? '';
                          if (!dialogCtx.mounted) return;

                          String message;
                          Color color;

                          if (token.isEmpty ||
                              depositProvider.depositId == null) {
                            message = "Không thể huỷ yêu cầu nạp tiền lúc này";
                            color = Colors.orange;
                          } else {
                            final ok = await depositProvider
                                .cancelDepositRequest(
                                  accessToken: token,
                                  depositId: depositProvider.depositId!,
                                );
                            message = ok
                                ? "Huỷ yêu cầu nạp tiền thành công"
                                : (depositProvider.errorMessage ??
                                      "Không thể huỷ yêu cầu nạp tiền");
                            color = ok ? Colors.green : Colors.orange;
                          }

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: color,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Huỷ yêu cầu"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) async {
      countdownTimer?.cancel();
      await onRefreshProfile();
    });
  }

  void _showWithdrawDialog(BuildContext context) {
    if (profile == null) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Brand.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Brand.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Rút tiền",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Brand.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: WithdrawDialogContent(
          currentWallet: profile!.wallet.toDouble(),
          driverId: profile!.id,
        ),
      ),
    ).then((value) {
      if (value == true) {
        onRefreshProfile().then((_) async {
          if (!context.mounted) return;
          await WithdrawRequestSuccessPopup.show(context);
        });
      }
    });
  }
}

class WithdrawDialogContent extends StatefulWidget {
  final double currentWallet;
  final int driverId;

  const WithdrawDialogContent({
    super.key,
    required this.currentWallet,
    required this.driverId,
  });

  @override
  State<WithdrawDialogContent> createState() => _WithdrawDialogContentState();
}

class _WithdrawDialogContentState extends State<WithdrawDialogContent> {
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String? _selectedBankCode;
  String? _selectedBankName;
  String? _selectedBankShortName;

  List<dynamic> _banks = [];
  List<dynamic> _filteredBanks = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    try {
      final res = await ApiService.getBanks();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body["code"] == "00") {
          setState(() {
            _banks = body["data"];
            _filteredBanks = body["data"];
          });
        }
      }
    } catch (_) {}
  }

  void _showBankPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Chọn ngân hàng",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Tìm ngân hàng...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _filteredBanks = _banks.where((bank) {
                          final q = value.toLowerCase();
                          return bank['name'].toString().toLowerCase().contains(
                                q,
                              ) ||
                              bank['shortName']
                                  .toString()
                                  .toLowerCase()
                                  .contains(q);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredBanks.length,
                      itemBuilder: (context, index) {
                        final bank = _filteredBanks[index];
                        return ListTile(
                          leading: Image.network(bank['logo'], width: 35),
                          title: Text(bank['shortName']),
                          onTap: () {
                            setState(() {
                              _selectedBankCode = bank['code'];
                              _selectedBankName = bank['name'];
                              _selectedBankShortName = bank['shortName'];
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmWithdraw() async {
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountText) ?? 0;

    if (amount <= 0 || amount > widget.currentWallet) return;
    if (_selectedBankCode == null) return;

    _submitWithdraw(amount);
  }

  Future<void> _submitWithdraw(int amount) async {
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;
        await WithdrawRequestFailedPopup.show(
          context,
          message: "Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.",
        );
        return;
      }

      final res = await ApiService.createWithdrawal(
        accessToken: token,
        amount: amount,
        bankCode: _selectedBankCode!,
        bankName: _selectedBankName!,
        accountNumber: _accountNumberController.text,
        accountName: _accountNameController.text.toUpperCase(),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pop(context, true);
        return;
      }

      String message = "Không thể gửi yêu cầu rút tiền.";
      try {
        final body = jsonDecode(res.body);
        message = body['message']?.toString() ?? message;
      } catch (_) {}

      await WithdrawRequestFailedPopup.show(context, message: message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Brand.b50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Brand.navy.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Số dư khả dụng",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Brand.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${NumberFormat('#,###').format(widget.currentWallet.round())} đ",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Brand.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Brand.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Số tiền muốn rút",
              labelStyle: const TextStyle(color: Brand.inkMuted),
              prefixIcon: const Icon(Icons.payments_outlined),
              suffixText: "đ",
              suffixStyle: TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w800,
              ),
              filled: true,
              fillColor: const Color(0x1A041565),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Brand.navy),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showBankPicker(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: "Ngân hàng",
                labelStyle: const TextStyle(color: Brand.inkMuted),
                prefixIcon: const Icon(Icons.account_balance_rounded),
                filled: true,
                fillColor: const Color(0x1A041565),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              child: Text(
                _selectedBankShortName ?? "Chạm để chọn",
                style: TextStyle(
                  color: _selectedBankShortName == null
                      ? Brand.inkMuted
                      : Brand.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Brand.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Số tài khoản",
              labelStyle: const TextStyle(color: Brand.inkMuted),
              prefixIcon: const Icon(Icons.credit_card_rounded),
              filled: true,
              fillColor: const Color(0x1A041565),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Brand.navy),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            style: const TextStyle(
              color: Brand.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Tên chủ tài khoản",
              labelStyle: const TextStyle(color: Brand.inkMuted),
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: const Color(0x1A041565),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Brand.navy),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Gửi yêu cầu rút tiền"),
            ),
          ),
        ],
      ),
    );
  }
}
