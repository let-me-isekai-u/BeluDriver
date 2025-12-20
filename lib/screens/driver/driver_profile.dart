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
        // Xoá local data
        await prefs.clear();

        if (!mounted) return;

        // Về login
        _goToLogin();
      } else {
        _showError("Xoá tài khoản thất bại");
      }
    } catch (e) {
      _showError("Lỗi kết nối server");
    }
  }


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOGIC LOAD PROFILE (GIỮ NGUYÊN) =================
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
        setState(() {
          _profile = DriverProfileModel.fromJson(data);
          _loading = false;
          print('📥 PROFILE RAW BODY = ${res.body}');

        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
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

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ tài xế'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? const Center(child: Text('Không có dữ liệu'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Avatar và Tên)
            _buildHeader(primaryColor),
            const SizedBox(height: 24),

            // 2. Thông tin chi tiết (Email, Biển số, Ví)
            _buildDetailsCard(),
            const SizedBox(height: 30),

            // 3. Các Lựa chọn Thao tác (Cập nhật, Đổi mật khẩu, tài chính, hỗ trợ)
            _buildActionButtons(context),
            const SizedBox(height: 24),

            // 4. Đăng xuất và Xóa tài khoản
            _buildDangerousActions(context),
          ],
        ),
      ),
    );
  }

  // 1. Header: Avatar và Tên tài xế
  Widget _buildHeader(Color primaryColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: primaryColor.withOpacity(0.15),
              backgroundImage: _profile!.avatarUrl.isNotEmpty
                  ? NetworkImage(_profile!.avatarUrl)
                  : null,
              child: _profile!.avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 60, color: primaryColor)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _profile!.fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _profile!.phone,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }


  // 2. Card chi tiết thông tin (Ví, Biển số, Email)
  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildProfileListItem(
            icon: Icons.account_balance_wallet_rounded,
            title: "Số dư ví",
            // subtitle: '1.000.000 đ',
            subtitle: '${_profile!.wallet.toStringAsFixed(0)} đ',
            showArrow: false,
            onTap: () {},
          ),
          const Divider(height: 1),
          _buildProfileListItem(
            icon: Icons.directions_car_filled_rounded,
            title: "Biển số xe",
            subtitle: _profile!.licenseNumber,
            showArrow: false,
            onTap: () {},
          ),

          const Divider(height: 1),
          _buildProfileListItem(
            icon: Icons.email_rounded,
            title: "Email",
            subtitle: _profile!.email,
            showArrow: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  //dialog hỗ trợ giống home
  void _showSupportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Để chiều cao vừa đủ nội dung
            children: [
              // Thanh gạch nhỏ trên đầu cho đúng chuẩn BottomSheet
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const Icon(Icons.headset_mic_rounded, size: 50, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "Trung tâm hỗ trợ BeluCar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Chúng tôi sẵn sàng giúp đỡ bạn 24/7. Vui lòng chọn phương thức liên hệ.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Nút Gọi Tổng Đài
              _buildSupportAction(
                icon: Icons.phone_in_talk_rounded,
                title: "Gọi tổng đài hỗ trợ",
                subtitle: "1900 xxxx (Miễn phí)",
                color: Colors.green,
                onTap: () {
                  // Logic thực hiện cuộc gọi
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),

              // Nút Nhắn tin Zalo/Chat
              _buildSupportAction(
                icon: Icons.chat_bubble_rounded,
                title: "Chat với tư vấn viên",
                subtitle: "Phản hồi trong vòng 5 phút",
                color: Colors.blue,
                onTap: () {
                  // Logic mở chat
                  Navigator.pop(context);
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
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
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
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // 3. Nút Cập nhật, Đổi mật khẩu, hỗ trợ
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildProfileListItem(
          icon: Icons.edit_note_rounded,
          title: "Cập nhật Thông tin tài xế",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverUpdateProfileScreen(profile: _profile!),
              ),
            ).then((updated) {
              if (updated == true) {
                _loadProfile(); // reload lại profile sau khi update
              }
            });

          },
        ),
        _buildProfileListItem(
          icon: Icons.lock_reset_rounded,
          title: "Đổi Mật khẩu",
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
          onTap: () => _showSupportDialog(context),
    ),
      ],
    );
  }

  // 4. Các nút nguy hiểm (Đăng xuất, Xóa)
  Widget _buildDangerousActions(BuildContext context) {
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
          onPressed: () {
            // 1. Hiển thị popup xác nhận trước
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text("Xác nhận xóa tài khoản"),
                  content: const Text(
                    "Bạn có chắc chắn muốn xóa tài khoản tài xế không? "
                        "Tất cả dữ liệu về ví, lịch sử chuyến xe sẽ bị mất vĩnh viễn và không thể khôi phục.",
                  ),
                  actions: [
                    // Nút Hủy: Chỉ đóng popup
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Quay lại", style: TextStyle(color: Colors.grey)),
                    ),
                    // Nút Xóa: Đóng popup và thực hiện xóa
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context); // Đóng popup xác nhận
                        await _deleteAccount(); // Thực hiện hàm xóa tài khoản của bạn
                      },
                      child: const Text(
                        "Xóa vĩnh viễn",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          child: const Text(
            "Xoá tài khoản tài xế",
            style: TextStyle(decoration: TextDecoration.underline, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // Helper cho danh sách
  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.blueGrey)) : null,
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }

  // Logic Logout
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}