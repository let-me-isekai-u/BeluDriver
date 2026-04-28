import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_profile_model.dart';
import '../../models/driver_onboarding_status_dto.dart';
import '../../providers/driver/profile_provider.dart';
import '../../providers/routes/register_route_provider.dart';
import '../change_password_screen.dart';
import '../register_route/register_route_popup.dart';
import 'driver_login_screen.dart';
import 'driver_update_profile_screen.dart';
import 'wallet_history_screen.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const _DriverProfileView(),
    );
  }
}

class _DriverProfileView extends StatefulWidget {
  const _DriverProfileView();

  @override
  State<_DriverProfileView> createState() => _DriverProfileViewState();
}

class _DriverProfileViewState extends State<_DriverProfileView> {
  bool _isOnboardingExpanded = false;
  bool _isSelectedProvincesExpanded = false;
  bool _isRoutesExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

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
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.primary,
            iconTheme: IconThemeData(color: theme.colorScheme.secondary),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  tooltip: 'Xoá tài khoản',
                  onPressed: profile == null
                      ? null
                      : () => _showDeleteDialog(context, theme, provider),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.shade400,
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.red,
                      size: 20,
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
              ? Center(
            child: Text(
              'Không có dữ liệu',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          )
              : SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomSafe),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme, profile),
                  const SizedBox(height: 16),
                  _buildWalletCard(theme, profile),
                  const SizedBox(height: 16),
                  _buildOnboardingCard(theme, onboarding),
                  const SizedBox(height: 16),
                  _buildSelectedProvincesCard(theme, profile),
                  const SizedBox(height: 16),
                  _buildRoutesCard(theme, profile),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, theme, provider, profile),
                  const SizedBox(height: 16),
                  _buildDetailsCard(theme, profile),
                  const SizedBox(height: 30),
                  _buildDangerousActions(context, theme, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandableCard({
    required ThemeData theme,
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
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
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
            crossFadeState:
            expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, DriverProfileModel profile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
              backgroundImage:
              profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
              child: profile.avatarUrl.isEmpty
                  ? Icon(
                Icons.person,
                size: 70,
                color: theme.colorScheme.secondary,
              )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile.fullName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.phone,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(ThemeData theme, DriverProfileModel profile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: theme.colorScheme.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Số dư ví",
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.wallet.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingCard(
      ThemeData theme,
      DriverOnboardingStatusDto? onboarding,
      ) {
    return _buildExpandableCard(
      theme: theme,
      title: "Trạng thái tài khoản",
      expanded: _isOnboardingExpanded,
      onTap: () {
        setState(() {
          _isOnboardingExpanded = !_isOnboardingExpanded;
        });
      },
      child: onboarding == null
          ? const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Không có dữ liệu trạng thái tài khoản",
          style: TextStyle(color: Colors.white70),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("KYC", _mapKycStatusLabel(onboarding.kycStatusText)),
          _buildInfoRow(
            "Đã đăng ký tuyến",
            onboarding.hasRegisteredRoute ? "Có" : "Chưa",
          ),
          _buildInfoRow(
            "Số tỉnh đã chọn",
            onboarding.selectedProvinceCount.toString(),
          ),
          _buildInfoRow(
            "Có thể nhận chuyến",
            _boolToVietnamese(onboarding.canReceiveRide),
          ),
          _buildInfoRow(
            "Trạng thái xử lý",
            _mapNextStepLabel(onboarding.nextStep),
          ),
          if ((onboarding.kycRejectReason ?? '').isNotEmpty)
            _buildInfoRow(
              "Lý do từ chối KYC",
              onboarding.kycRejectReason!,
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedProvincesCard(ThemeData theme, DriverProfileModel profile) {
    return _buildExpandableCard(
      theme: theme,
      title: "Tỉnh đã chọn",
      expanded: _isSelectedProvincesExpanded,
      onTap: () {
        setState(() {
          _isSelectedProvincesExpanded = !_isSelectedProvincesExpanded;
        });
      },
      child: profile.selectedProvinces.isEmpty
          ? const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Chưa có tỉnh nào",
          style: TextStyle(color: Colors.white70),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: profile.selectedProvinces
            .map(
              (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '• ${item.provinceName}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildRoutesCard(ThemeData theme, DriverProfileModel profile) {
    return _buildExpandableCard(
      theme: theme,
      title: "Tuyến đã đăng ký",
      expanded: _isRoutesExpanded,
      onTap: () {
        setState(() {
          _isRoutesExpanded = !_isRoutesExpanded;
        });
      },
      child: profile.routes.isEmpty
          ? const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Chưa có tuyến nào",
          style: TextStyle(color: Colors.white70),
        ),
      )
          : Column(
        children: profile.routes
            .map(
              (route) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withOpacity(0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã tuyến: ${route.code}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '${route.fromProvinceName} → ${route.toProvinceName}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme, DriverProfileModel profile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildProfileListItem(
            icon: Icons.directions_car_filled_rounded,
            title: "Biển số xe",
            subtitle: profile.licenseNumber,
            iconColor: theme.colorScheme.secondary,
            showArrow: false,
            onTap: () {},
          ),
          const Divider(height: 1),
          _buildProfileListItem(
            icon: Icons.email_rounded,
            title: "Email",
            subtitle: profile.email,
            iconColor: theme.colorScheme.secondary,
            showArrow: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context,
      ThemeData theme,
      ProfileProvider provider,
      DriverProfileModel profile,
      ) {
    return Column(
      children: [
        _buildProfileListItem(
          icon: Icons.alt_route_rounded,
          title: "Thay đổi tuyến hoạt động",
          iconColor: theme.colorScheme.secondary,
          onTap: () => _handleChangeRoute(provider),
        ),
        _buildProfileListItem(
          icon: Icons.edit_note_rounded,
          title: "Cập nhật Thông tin tài xế",
          iconColor: theme.colorScheme.secondary,
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
        _buildProfileListItem(
          icon: Icons.lock_reset_rounded,
          title: "Đổi Mật khẩu",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
        ),
        _buildProfileListItem(
          icon: Icons.attach_money,
          title: "Lịch sử tài chính",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletHistoryScreen()),
            );
          },
        ),
        _buildProfileListItem(
          icon: Icons.headset_mic_rounded,
          title: "Liên hệ hỗ trợ",
          iconColor: theme.colorScheme.secondary,
          onTap: () => _showSupportDialog(context, provider),
        ),
      ],
    );
  }

  Widget _buildDangerousActions(
      BuildContext context,
      ThemeData theme,
      ProfileProvider provider,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded),
          label: const Text("Đăng xuất tài khoản"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade700),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _handleLogout(provider),
        ),
      ],
    );
  }

  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor ?? Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Colors.white70),
      )
          : null,
      trailing: showArrow
          ? const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context, ProfileProvider provider) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Icon(
                Icons.headset_mic_rounded,
                size: 50,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                "Trung tâm hỗ trợ BeluCar",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Chúng tôi sẵn sàng giúp đỡ bạn 24/7. Vui lòng chọn phương thức liên hệ.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildSupportAction(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(Icons.phone_in_talk_rounded, color: Colors.green),
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
                leading: Image.asset(
                  'lib/assets/icons/icons8-zalo-100.png',
                  width: 40,
                  height: 40,
                ),
                title: "Nhắn tin với chúng tôi",
                subtitle: "Sẵn sàng hỗ trợ",
                onTap: () async {
                  Navigator.pop(context);
                  await _handleOpenZalo(provider);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportAction({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(" ", style: TextStyle(fontSize: 0)),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Xác nhận xóa tài khoản",
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: const Text(
          "Bạn có chắc chắn muốn xóa tài khoản tài xế không? "
              "Tất cả dữ liệu về ví, lịch sử chuyến xe sẽ bị mất vĩnh viễn và không thể khôi phục.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Quay lại", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount(provider);
            },
            child: const Text(
              "Xóa vĩnh viễn",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}