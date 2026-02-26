import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/driver_profile_model.dart';
import '../../services/api_service.dart';
import 'driver_login_screen.dart';
import '../change_password_screen.dart';

import 'driver_update_profile_screen.dart';
import 'wallet_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  DriverProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null || accessToken.isEmpty) {
      _goToLogin();
      return;
    }

    try {
      final res = await ApiService.deleteAccount(accessToken: accessToken);

      if (res.statusCode == 200) {
        await prefs.clear();
        if (!mounted) return;
        _goToLogin();
      } else {
        _showError("Xoá tài khoản thất bại");
      }
    } catch (e) {
      _showError("Lỗi kết nối server");
    }
  }

  Future<void> _openZalo() async {
    final Uri zaloUrl = Uri.parse('https://zalo.me/0379550130');
    if (await canLaunchUrl(zaloUrl)) {
      await launchUrl(zaloUrl, mode: LaunchMode.externalApplication);
    } else {
      _showError("Không thể mở Zalo");
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');

      if (accessToken == null || accessToken.isEmpty) {
        _goToLogin();
        return;
      }

      final res = await ApiService.getDriverProfile(accessToken: accessToken);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          _profile = DriverProfileModel.fromJson(data);
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

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
      ),
      body: _loading
          ? Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      )
          : _profile == null
          ? Center(
        child: Text(
          'Không có dữ liệu',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      )
          : SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          // ✅ FIX iOS: chừa thêm khoảng trống đáy để không bị "bounce" đúng vào vùng nút cuối,
          // giúp bấm nút/gesture ở item cuối ổn định hơn.
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomSafe),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 16),
              _buildWalletCard(theme),
              const SizedBox(height: 24),
              _buildActionButtons(context, theme),
              const SizedBox(height: 16),
              _buildDetailsCard(theme),
              const SizedBox(height: 30),
              _buildDangerousActions(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Sections ======

  Widget _buildHeader(ThemeData theme) {
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
              backgroundImage: (_profile!.avatarUrl.isNotEmpty)
                  ? NetworkImage(_profile!.avatarUrl)
                  : null,
              child: _profile!.avatarUrl.isEmpty
                  ? Icon(
                Icons.person,
                size: 70,
                color: theme.colorScheme.secondary,
              )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _profile!.fullName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _profile!.phone,
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

  Widget _buildWalletCard(ThemeData theme) {
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
                    '${_profile!.wallet.toStringAsFixed(0)} đ',
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

  Widget _buildDetailsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildProfileListItem(
            icon: Icons.directions_car_filled_rounded,
            title: "Biển số xe",
            subtitle: _profile!.licenseNumber,
            iconColor: theme.colorScheme.secondary,
            showArrow: false,
            onTap: () {},
          ),
          const Divider(height: 1),
          _buildProfileListItem(
            icon: Icons.email_rounded,
            title: "Email",
            subtitle: _profile!.email,
            iconColor: theme.colorScheme.secondary,
            showArrow: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _buildProfileListItem(
          icon: Icons.edit_note_rounded,
          title: "Cập nhật Thông tin tài xế",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverUpdateProfileScreen(profile: _profile!),
              ),
            ).then((updated) {
              if (updated == true) _loadProfile();
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
          onTap: () => _showSupportDialog(context),
        ),
      ],
    );
  }

  Widget _buildDangerousActions(BuildContext context, ThemeData theme) {
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
          onPressed: _logout,
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          onPressed: () => _showDeleteDialog(context, theme),
          child: const Text(
            "Xoá tài khoản tài xế",
            style: TextStyle(decoration: TextDecoration.underline, fontSize: 13),
          ),
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

  void _showSupportDialog(BuildContext context) {
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
                  final uri = Uri.parse('tel:0823416820');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
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
                onTap: () {
                  Navigator.pop(context);
                  _openZalo();
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

  void _showDeleteDialog(BuildContext context, ThemeData theme) {
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
              await _deleteAccount();
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken != null) {
      await ApiService.Driverlogout(accessToken);
    }
    await prefs.clear();
    if (!mounted) return;
    _goToLogin();
  }
}