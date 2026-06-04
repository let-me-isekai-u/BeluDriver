import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../models/driver/driver_profile_model.dart';
import '../../models/driver_onboarding_status_dto.dart';
import '../../providers/driver/deposit_provider.dart';
import '../../providers/driver/profile_provider.dart';
import '../../providers/routes/register_route_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';
import '../change_password_screen.dart';
import '../popup_list/withdraw_request_failed_popup.dart';
import '../popup_list/withdraw_request_success_popup.dart';
import '../register_route/register_route_popup.dart';
import 'driver_login_screen.dart';
import 'driver_update_profile_screen.dart';
import 'wallet_history_screen.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => DepositProvider()),
      ],
      child: const _DriverProfileView(),
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
              color: Colors.black.withValues(alpha: 0.58),
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

class _DriverProfileView extends StatefulWidget {
  const _DriverProfileView();

  @override
  State<_DriverProfileView> createState() => _DriverProfileViewState();
}

class _DriverProfileViewState extends State<_DriverProfileView> {
  bool _isFinanceExpanded = false;
  bool _isOnboardingExpanded = true;
  bool _isSelectedProvincesExpanded = false;
  bool _isRoutesExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ProfileProvider>();
      final hasToken = await provider.loadProfile();

      if (!mounted) return;
      if (!hasToken) {
        _goToLogin();
      }
    });
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
      (_) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _boolToVietnamese(bool value) {
    return value ? 'Có' : 'Không';
  }

  Color _kycStatusColor(int kycStatus) {
    return kycStatus == 2 ? const Color(0xFF6ED39B) : const Color(0xFFFFB347);
  }

  Future<void> _handleDeleteAccount(ProfileProvider provider) async {
    final success = await provider.deleteAccount();

    if (!mounted) return;

    if (success) {
      _goToLogin();
    } else {
      _showError("Xoá tài khoản thất bại");
    }
  }

  Future<void> _handleLogout(ProfileProvider provider) async {
    await provider.logout();
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _handleOpenZalo(ProfileProvider provider) async {
    final success = await provider.openZalo();
    if (!mounted) return;
    if (!success) {
      _showError("Không thể mở Zalo");
    }
  }

  Future<void> _handleCallSupport(ProfileProvider provider) async {
    final success = await provider.callSupport();
    if (!mounted) return;
    if (!success) {
      _showError("Không thể gọi điện");
    }
  }

  Future<void> _handleChangeRoute(ProfileProvider provider) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => RegisterRouteProvider(),
        child: const RegisterRoutePopup(),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      await provider.loadProfile();
    }
  }

  String _mapNextStepLabel(String nextStep) {
    switch (nextStep.trim().toLowerCase()) {
      case 'select_route':
      case 'register_route':
        return 'Đăng ký tuyến';
      case 'submit_kyc':
        return 'Bổ sung hồ sơ KYC';
      case 'resubmit_kyc':
        return 'Cập nhật lại hồ sơ KYC';
      case 'waiting_kyc_approval':
        return 'Chờ duyệt hồ sơ KYC';
      case 'ready':
        return 'Sẵn sàng hoạt động';
      default:
        return nextStep.isEmpty ? 'Không xác định' : nextStep;
    }
  }

  String _mapKycStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'Đang chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Bị từ chối';
      case 'notstarted':
      case 'not_started':
        return 'Chưa gửi hồ sơ';
      default:
        return status.isEmpty ? 'Không xác định' : status;
    }
  }

  String _formatWallet(double amount) {
    return '${NumberFormat('#,###', 'vi_VN').format(amount.round())} đ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final DriverProfileModel? profile = provider.profile;
        final DriverOnboardingStatusDto? onboarding = provider.onboardingStatus;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Hồ sơ tài xế',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            backgroundColor: theme.colorScheme.primary,
            iconTheme: IconThemeData(color: theme.colorScheme.secondary),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton(
                  tooltip: 'Xoá tài khoản',
                  onPressed: profile == null
                      ? null
                      : () => _showDeleteDialog(context, theme, provider),
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A8A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF8A8A).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF8A8A),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: provider.loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.secondary,
                  ),
                )
              : profile == null
              ? const DriverEmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Không có dữ liệu hồ sơ',
                  message:
                      'Vui lòng thử tải lại hoặc đăng nhập lại để đồng bộ thông tin tài khoản.',
                )
              : Stack(
                  children: [
                    Positioned(
                      top: -80,
                      left: -50,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: provider.loadProfile,
                      child: ListView(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          bottomSafe + 28,
                        ),
                        children: [
                          _buildHero(theme, profile, onboarding),
                          const SizedBox(height: 16),
                          _buildWalletCard(theme, profile),
                          const SizedBox(height: 16),
                          _buildFinanceSection(
                            context,
                            theme,
                            provider,
                            profile,
                          ),
                          const SizedBox(height: 16),
                          _buildOnboardingSection(theme, onboarding),
                          const SizedBox(height: 16),
                          _buildSelectedProvincesSection(theme, profile),
                          const SizedBox(height: 16),
                          _buildRoutesSection(theme, profile),
                          const SizedBox(height: 16),
                          _buildActionsSection(
                            context,
                            theme,
                            provider,
                            profile,
                          ),
                          const SizedBox(height: 16),
                          _buildDetailsSection(theme, profile),
                          const SizedBox(height: 16),
                          _buildDangerZone(theme, provider),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHero(
    ThemeData theme,
    DriverProfileModel profile,
    DriverOnboardingStatusDto? onboarding,
  ) {
    final canReceive = onboarding?.canReceiveRide ?? false;
    final statusLabel = onboarding == null
        ? 'Đang đồng bộ'
        : _mapKycStatusLabel(onboarding.kycStatusText);

    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.14,
                ),
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: theme.colorScheme.secondary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DriverPill(
                      label: "Tài khoản tài xế",
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.fullName.isEmpty
                          ? "Chưa cập nhật tên"
                          : profile.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DriverPill(
                label: statusLabel,
                icon: Icons.verified_user_rounded,
                color: onboarding == null
                    ? theme.colorScheme.secondary
                    : _kycStatusColor(onboarding.kycStatus),
              ),
              DriverPill(
                label: canReceive
                    ? "Có thể nhận chuyến"
                    : "Chưa sẵn sàng nhận chuyến",
                icon: canReceive
                    ? Icons.check_circle_rounded
                    : Icons.timelapse_rounded,
                color: canReceive
                    ? const Color(0xFF6ED39B)
                    : const Color(0xFFFFB347),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(ThemeData theme, DriverProfileModel profile) {
    return DriverSectionCard(
      title: "Tổng quan tài khoản",
      subtitle: "Số dư ví và phạm vi hoạt động hiện tại của bạn.",
      icon: Icons.account_balance_wallet_rounded,
      child: Row(
        children: [
          Expanded(
            child: DriverStatTile(
              label: "Số dư ví",
              value: _formatWallet(profile.wallet),
              icon: Icons.savings_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DriverStatTile(
              label: "Tỉnh đã chọn",
              value: profile.selectedProvinces.length.toString(),
              icon: Icons.map_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DriverStatTile(
              label: "Tuyến đăng ký",
              value: profile.routes.length.toString(),
              icon: Icons.alt_route_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(
    BuildContext context,
    ThemeData theme,
    ProfileProvider provider,
    DriverProfileModel profile,
  ) {
    return _buildExpandableSection(
      theme: theme,
      title: "Tài chính",
      subtitle: "Lịch sử ví, nạp tiền và gửi yêu cầu rút tiền.",
      icon: Icons.account_balance_wallet_outlined,
      expanded: _isFinanceExpanded,
      onTap: () {
        setState(() {
          _isFinanceExpanded = !_isFinanceExpanded;
        });
      },
      child: Column(
        children: [
          _buildActionTile(
            theme,
            icon: Icons.history_rounded,
            title: "Lịch sử tài chính",
            subtitle: "Xem toàn bộ giao dịch ví",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletHistoryScreen()),
              );
            },
          ),
          _buildActionTile(
            theme,
            icon: Icons.account_balance_wallet_rounded,
            title: "Nạp tiền",
            subtitle: "Tạo yêu cầu nạp tiền vào ví",
            onTap: () => _showDepositDialog(context, theme, provider),
          ),
          _buildActionTile(
            theme,
            icon: Icons.payments_outlined,
            title: "Yêu cầu rút tiền",
            subtitle: "Gửi yêu cầu rút tiền từ ví tài xế",
            onTap: () => _showWithdrawDialog(context, provider, profile),
            isLast: true,
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(
    BuildContext parentContext,
    ThemeData theme,
    ProfileProvider provider,
  ) {
    final TextEditingController amountController = TextEditingController();
    final depositProvider = parentContext.read<DepositProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

    bool isSubmitting = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceGreen,
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
                    color: theme.colorScheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Nạp tiền vào ví",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
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
                  "Nhập số tiền bạn muốn nạp. Sau đó hệ thống sẽ tạo mã QR để bạn chuyển khoản nhanh hơn.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(
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
                          color: AppColors.textSubtle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ví dụ: 100000",
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.32),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Icon(
                            Icons.payments_outlined,
                            color: theme.colorScheme.secondary,
                          ),
                          suffixText: "đ",
                          suffixStyle: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.12),
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
                              color: theme.colorScheme.secondary,
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
                            provider,
                            depositProvider,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
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
    ProfileProvider provider,
    DepositProvider depositProvider,
  ) async {
    if (!mounted || !parentContext.mounted) return;

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
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.qr_code_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "QR nạp ví",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
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
                          color: AppColors.primaryGreen,
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
                            valueColor: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DriverDepositInfoTile(
                            label: 'Nội dung',
                            value: content,
                            valueColor: theme.colorScheme.secondary,
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
      await provider.loadProfile();
    });
  }

  void _showWithdrawDialog(
    BuildContext context,
    ProfileProvider provider,
    DriverProfileModel profile,
  ) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A8A).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Color(0xFFFF8A8A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Rút tiền",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: ProfileWithdrawDialogContent(
          currentWallet: profile.wallet.toDouble(),
          driverId: profile.id,
        ),
      ),
    ).then((value) {
      if (value == true) {
        provider.loadProfile().then((_) async {
          if (!context.mounted) return;
          await WithdrawRequestSuccessPopup.show(context);
        });
      }
    });
  }

  Widget _buildOnboardingSection(
    ThemeData theme,
    DriverOnboardingStatusDto? onboarding,
  ) {
    return _buildExpandableSection(
      theme: theme,
      title: "Trạng thái tài khoản",
      subtitle: "Theo dõi KYC, tuyến đăng ký và bước cần thực hiện tiếp theo.",
      icon: Icons.shield_rounded,
      expanded: _isOnboardingExpanded,
      onTap: () {
        setState(() {
          _isOnboardingExpanded = !_isOnboardingExpanded;
        });
      },
      child: onboarding == null
          ? Text(
              "Không có dữ liệu trạng thái tài khoản.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
              ),
            )
          : Column(
              children: [
                _buildInfoCardRow(
                  theme,
                  "Trạng thái KYC",
                  _mapKycStatusLabel(onboarding.kycStatusText),
                  valueColor: _kycStatusColor(onboarding.kycStatus),
                ),
                _buildInfoCardRow(
                  theme,
                  "Đã đăng ký tuyến",
                  onboarding.hasRegisteredRoute ? "Đã đăng ký" : "Chưa đăng ký",
                ),
                _buildInfoCardRow(
                  theme,
                  "Số tỉnh đã chọn",
                  onboarding.selectedProvinceCount.toString(),
                ),
                _buildInfoCardRow(
                  theme,
                  "Có thể nhận chuyến",
                  _boolToVietnamese(onboarding.canReceiveRide),
                ),
                _buildInfoCardRow(
                  theme,
                  "Hành động ưu tiên",
                  _mapNextStepLabel(onboarding.nextStep),
                ),
                if ((onboarding.kycRejectReason ?? '').isNotEmpty)
                  _buildInfoCardRow(
                    theme,
                    "Lý do từ chối KYC",
                    onboarding.kycRejectReason!,
                    isLast: true,
                    valueColor: const Color(0xFFFF8A8A),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
    );
  }

  Widget _buildSelectedProvincesSection(
    ThemeData theme,
    DriverProfileModel profile,
  ) {
    return _buildExpandableSection(
      theme: theme,
      title: "Khu vực hoạt động",
      subtitle: "Danh sách các tỉnh bạn đã chọn để nhận tuyến và chuyến.",
      icon: Icons.map_outlined,
      expanded: _isSelectedProvincesExpanded,
      onTap: () {
        setState(() {
          _isSelectedProvincesExpanded = !_isSelectedProvincesExpanded;
        });
      },
      child: profile.selectedProvinces.isEmpty
          ? const DriverEmptyState(
              icon: Icons.place_outlined,
              title: "Chưa chọn tỉnh hoạt động",
              message:
                  "Bạn có thể cập nhật khu vực làm việc để nhận được nhiều chuyến phù hợp hơn.",
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: profile.selectedProvinces
                  .map(
                    (item) => DriverPill(
                      label: item.provinceName,
                      icon: Icons.location_city_rounded,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildRoutesSection(ThemeData theme, DriverProfileModel profile) {
    return _buildExpandableSection(
      theme: theme,
      title: "Tuyến đã đăng ký",
      subtitle: "Các tuyến đang được áp dụng cho tài khoản tài xế của bạn.",
      icon: Icons.route_rounded,
      expanded: _isRoutesExpanded,
      onTap: () {
        setState(() {
          _isRoutesExpanded = !_isRoutesExpanded;
        });
      },
      child: profile.routes.isEmpty
          ? const DriverEmptyState(
              icon: Icons.alt_route_rounded,
              title: "Chưa có tuyến nào",
              message:
                  "Hãy đăng ký tuyến hoạt động để hệ thống phân phối chuyến phù hợp hơn.",
            )
          : Column(
              children: profile.routes
                  .map(
                    (route) => Padding(
                      padding: EdgeInsets.only(
                        bottom: route == profile.routes.last ? 0 : 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mã tuyến: ${route.code}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSubtle,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${route.fromProvinceName} → ${route.toProvinceName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    ThemeData theme,
    ProfileProvider provider,
    DriverProfileModel profile,
  ) {
    return DriverSectionCard(
      title: "Tiện ích tài khoản",
      subtitle: "Các thao tác thường dùng để quản lý hồ sơ và hỗ trợ vận hành.",
      icon: Icons.grid_view_rounded,
      child: Column(
        children: [
          _buildActionTile(
            theme,
            icon: Icons.alt_route_rounded,
            title: "Thay đổi tuyến hoạt động",
            subtitle: "Cập nhật tuyến đang đăng ký",
            onTap: () => _handleChangeRoute(provider),
          ),
          _buildActionTile(
            theme,
            icon: Icons.edit_note_rounded,
            title: "Cập nhật thông tin tài xế",
            subtitle: "Sửa tên, email, biển số và ảnh đại diện",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverUpdateProfileScreen(profile: profile),
                ),
              ).then((updated) {
                if (updated == true) {
                  provider.loadProfile();
                }
              });
            },
          ),
          _buildActionTile(
            theme,
            icon: Icons.lock_reset_rounded,
            title: "Đổi mật khẩu",
            subtitle: "Tăng độ an toàn cho tài khoản",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _buildActionTile(
            theme,
            icon: Icons.headset_mic_rounded,
            title: "Liên hệ hỗ trợ",
            subtitle: "Gọi điện hoặc nhắn Zalo cho trung tâm hỗ trợ",
            onTap: () => _showSupportDialog(context, provider),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(ThemeData theme, DriverProfileModel profile) {
    return DriverSectionCard(
      title: "Thông tin cơ bản",
      subtitle: "Các dữ liệu nhận diện của tài khoản tài xế.",
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _buildInfoCardRow(
            theme,
            "Biển số xe",
            profile.licenseNumber.isEmpty
                ? "Chưa cập nhật"
                : profile.licenseNumber,
          ),
          _buildInfoCardRow(
            theme,
            "Email",
            profile.email.isEmpty ? "Chưa cập nhật" : profile.email,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(ThemeData theme, ProfileProvider provider) {
    return DriverSectionCard(
      title: "Bảo mật tài khoản",
      subtitle: "Đăng xuất khi bạn kết thúc ca làm việc hoặc đổi thiết bị.",
      icon: Icons.logout_rounded,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleLogout(provider),
          icon: const Icon(Icons.logout_rounded),
          label: const Text("Đăng xuất tài khoản"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF8A8A),
            side: const BorderSide(color: Color(0xFFFF8A8A)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGreen.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: theme.colorScheme.secondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.secondary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: child,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardRow(
    ThemeData theme,
    String title,
    String value, {
    Color? valueColor,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: theme.colorScheme.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context, ProfileProvider provider) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Trung tâm hỗ trợ",
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  "Chọn phương thức liên hệ phù hợp để được hỗ trợ nhanh nhất.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _buildSupportAction(
                  theme,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6ED39B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Color(0xFF6ED39B),
                    ),
                  ),
                  title: "Gọi điện thoại hỗ trợ",
                  subtitle: "08 2341 6820",
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleCallSupport(provider);
                  },
                ),
                const SizedBox(height: 12),
                _buildSupportAction(
                  theme,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'lib/assets/icons/icons8-zalo-100.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: "Nhắn tin qua Zalo",
                  subtitle: "Hỗ trợ trực tuyến",
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleOpenZalo(provider);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportAction(
    ThemeData theme, {
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ThemeData theme,
    ProfileProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Xác nhận xoá tài khoản",
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          "Bạn có chắc chắn muốn xoá tài khoản tài xế không? Tất cả dữ liệu về ví và lịch sử chuyến xe sẽ bị mất vĩnh viễn.",
          style: TextStyle(color: Colors.white, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Quay lại"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount(provider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A8A),
              foregroundColor: Colors.black87,
            ),
            child: const Text("Xoá vĩnh viễn"),
          ),
        ],
      ),
    );
  }
}

class ProfileWithdrawDialogContent extends StatefulWidget {
  final double currentWallet;
  final int driverId;

  const ProfileWithdrawDialogContent({
    super.key,
    required this.currentWallet,
    required this.driverId,
  });

  @override
  State<ProfileWithdrawDialogContent> createState() =>
      _ProfileWithdrawDialogContentState();
}

class _ProfileWithdrawDialogContentState
    extends State<ProfileWithdrawDialogContent> {
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
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Số dư khả dụng",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${NumberFormat('#,###').format(widget.currentWallet.round())} đ",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Số tiền muốn rút",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.payments_outlined),
              suffixText: "đ",
              suffixStyle: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.12),
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
                borderSide: BorderSide(color: theme.colorScheme.secondary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showBankPicker(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: "Ngân hàng",
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.account_balance_rounded),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.12),
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
                      ? Colors.white70
                      : Colors.white,
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Số tài khoản",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.credit_card_rounded),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.12),
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
                borderSide: BorderSide(color: theme.colorScheme.secondary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: "Tên chủ tài khoản",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.12),
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
                borderSide: BorderSide(color: theme.colorScheme.secondary),
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
