import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/driver_profile_model.dart';
import '../../providers/home_provider.dart';
import '../../providers/driver/deposit_provider.dart';
import '../../services/api_service.dart';
import '../chat_to_order/chat_group_list_screen.dart';
import '../kyc/kyc_deposit_requirement_popup.dart';
import '../kyc/kyc_popup.dart';
import 'activity_history.dart';
import 'driver_booking_screen.dart';
import 'driver_profile.dart';
import 'recieve_order_screen.dart';
import 'withdrawal_history_screen.dart';

import '../../providers/kyc/kyc_provider.dart';
import '../../providers/routes/register_route_provider.dart';
import '../register_route/register_route_popup.dart';


///test màn hình facedetection
import '../face_detection/face_capture_screen.dart';

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

class _DriverHomeView extends StatefulWidget {
  const _DriverHomeView();

  @override
  State<_DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<_DriverHomeView> {
  int _currentIndex = 2;
  bool _didTryShowPopup = false;

  static const String _depositPopupShownKey =
      'hasShownKycDepositRequirementPopup';
  static const num _requiredDepositAmount = 100000;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryShowOnboardingPopup();
  }

  Future<void> _showDepositRequirementPopupIfNeeded(
    HomeProvider provider,
  ) async {
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
              backgroundColor: const Color(0xFFFFD700), // gold
              foregroundColor: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final homeProvider = context.watch<HomeProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tryShowOnboardingPopup();
      }
    });

    final List<Widget> screens = [
      const RecieveOrderScreen(),
      DriverBookingScreen(
        onGoToPushedOrdersTab: () => setState(() => _currentIndex = 3),
      ),
      _HomeDashboard(
        profile: homeProvider.profile,
        isLoading: homeProvider.isLoadingProfile,
        onNavigate: (index) => _handleNavigationRequest(index, homeProvider),
        onRefreshProfile: homeProvider.refreshProfile,
      ),
      const ActivityScreen(initialTabIndex: 2),
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
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => _handleNavigationRequest(index, homeProvider),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: goldColor,
          unselectedItemColor: Colors.grey,
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
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _currentIndex == 2 ? goldColor : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (_currentIndex == 2)
                      BoxShadow(
                        color: goldColor.withOpacity(0.4),
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
                      : Colors.grey.shade600,
                ),
              ),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              label: 'Hoạt động',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
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
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundImage: (profile != null && profile.avatarUrl.isNotEmpty)
                ? NetworkImage(profile.avatarUrl)
                : null,
            child: (profile == null || profile.avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 26, color: Colors.white)
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
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
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
  final Function(int) onNavigate;
  final Future<void> Function() onRefreshProfile;

  const _HomeDashboard({
    required this.profile,
    required this.isLoading,
    required this.onNavigate,
    required this.onRefreshProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sẵn sàng nhận chuyến?",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Vào tab Nhận đơn để bắt đầu làm việc",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildMenuCard(
                  context,
                  "NHẬN ĐƠN MỚI",
                  Icons.near_me_rounded,
                  Colors.orange,
                  () => onNavigate(0),
                ),
                _buildMenuCard(
                  context,
                  "ĐẨY ĐƠN",
                  Icons.upload_file_rounded,
                  theme.colorScheme.secondary,
                  () => onNavigate(1),
                ),
                _buildMenuCard(
                  context,
                  "LỊCH SỬ CHUYẾN",
                  Icons.assignment_rounded,
                  Colors.blue,
                  () => onNavigate(3),
                ),
                _buildMenuCard(
                  context,
                  "NHÓM CHAT",
                  Icons.forum_rounded,
                  const Color(0xFF145E44),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverChatGroupListScreen(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  "NẠP TIỀN VÍ",
                  Icons.account_balance_wallet_rounded,
                  Colors.green,
                  () => _showDepositDialog(context, theme),
                ),
                _buildMenuCard(
                  context,
                  "RÚT TIỀN",
                  Icons.payments_outlined,
                  Colors.redAccent,
                  () => _showWithdrawDialog(context),
                ),
                _buildMenuCard(
                  context,
                  "LỊCH SỬ RÚT",
                  Icons.history_rounded,
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WithdrawalHistoryScreen(),
                    ),
                  ),
                ),
                // _buildMenuCard(
                //   context,
                //   "XÁC THỰC KHUÔN MẶT",
                //   Icons.face_retouching_natural,
                //   Colors.teal,
                //       () => Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //       builder: (_) => const FaceCaptureScreen(),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final goldColor = Theme.of(context).colorScheme.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shadowColor: goldColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: goldColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.circle,
                  color: goldColor.withOpacity(0.15),
                  size: 45,
                ),
                Icon(icon, size: 38, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(BuildContext parentContext, ThemeData theme) {
    final TextEditingController amountController = TextEditingController();
    final depositProvider = parentContext.read<DepositProvider>();

    bool isSubmitting = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nạp tiền vào ví"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amount = int.tryParse(
                        amountController.text.replaceAll(',', '').trim(),
                      );

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text("Vui lòng nhập số tiền hợp lệ"),
                          ),
                        );
                        return;
                      }

                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('accessToken') ?? '';

                      if (token.isEmpty) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
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
                        ScaffoldMessenger.of(parentContext).showSnackBar(
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
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Không nhận được nội dung chuyển khoản",
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(dialogContext);

                      _showQRDialog(parentContext, theme, amount, content);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("TẠO YÊU CẦU"),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRDialog(
    BuildContext parentContext,
    ThemeData theme,
    int amount,
    String content,
  ) async {
    final confirmed = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Lưu ý quan trọng"),
        content: const Text(
          "Hệ thống đã tạo yêu cầu nạp tiền. Vui lòng chuyển khoản đúng số tiền và đúng nội dung để worker tự đối soát.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Tôi đã hiểu"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final qrUrl =
        "https://img.vietqr.io/image/MB-246878888-compact2.png?amount=$amount&addInfo=$content&accountName=CTY%20CP%20CN%20VA%20DV%20TT%20THE%20BELUGAS";

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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Quét mã QR để nạp tiền",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Image.network(qrUrl, height: 280),
                    const SizedBox(height: 12),
                    Text(
                      "Số tiền: ${NumberFormat('#,###').format(amount)} đ",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      "Nội dung: $content",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Sau khi chuyển khoản thành công, hệ thống sẽ tự đối soát và cộng ví.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Còn lại: $minutes:$seconds",
                      style: const TextStyle(color: Colors.red),
                    ),
                    TextButton(
                      onPressed: () {
                        countdownTimer?.cancel();
                        Navigator.pop(dialogCtx);
                      },
                      child: const Text("Đóng"),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Rút tiền"),
        content: WithdrawDialogContent(
          currentWallet: profile!.wallet.toDouble(),
          driverId: profile!.id,
        ),
      ),
    ).then((value) {
      if (value == true) onRefreshProfile();
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
  String? _selectedBankLogo;
  String? _selectedBankShortName;

  List<dynamic> _banks = [];
  List<dynamic> _filteredBanks = [];

  bool _loadingBanks = true;
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
            _loadingBanks = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
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
                              _selectedBankLogo = bank['logo'];
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

      final res = await ApiService.createWithdrawal(
        accessToken: token,
        amount: amount,
        bankCode: _selectedBankCode!,
        bankName: _selectedBankName!,
        accountNumber: _accountNumberController.text,
        accountName: _accountNameController.text.toUpperCase(),
      );

      if (res.statusCode == 200) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: "Số tiền muốn rút"),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showBankPicker(context),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: "Chọn ngân hàng"),
              child: Text(_selectedBankShortName ?? "Chạm để chọn"),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNumberController,
            decoration: const InputDecoration(labelText: "Số tài khoản"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            decoration: const InputDecoration(labelText: "Tên chủ tài khoản"),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text("GỬI YÊU CẦU RÚT TIỀN"),
            ),
          ),
        ],
      ),
    );
  }
}
