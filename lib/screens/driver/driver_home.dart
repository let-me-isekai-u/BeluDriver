import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/driver/driver_profile_model.dart';
import 'driver_profile.dart';
import 'recieve_order_screen.dart';
import 'activity_history.dart';
import 'dart:async';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  DriverProfileModel? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // 1. LOGIC LẤY PROFILE TÀI XẾ
  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isNotEmpty) {
        final res = await ApiService.getDriverProfile(accessToken: token);
        if (res.statusCode == 200) {
          setState(() {
            _profile = DriverProfileModel.fromJson(jsonDecode(res.body));
            _isLoadingProfile = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải profile: $e");
    }
    setState(() => _isLoadingProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> screens = [
      _HomeDashboard(
        profile: _profile,
        isLoading: _isLoadingProfile,
        onNavigate: (index) => setState(() => _currentIndex = index),
        onRefreshProfile: _fetchProfile,
      ),
      const ReceiveOrderTab(),
      const ActivityScreen(),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      appBar: _currentIndex == 0 ? _buildCustomAppBar(theme) : null,
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: 'Nhận đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Hoạt động'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar(ThemeData theme) {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundImage: (_profile != null && _profile!.avatarUrl.isNotEmpty)
                ? NetworkImage(_profile!.avatarUrl)
                : null,
            child: (_profile == null || _profile!.avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 28, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLoadingProfile ? "Đang tải..." : (_profile?.fullName ?? "Tài xế"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _profile != null
                      ? "Ví: ${_profile!.wallet.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} VND"
                      : "Ví: 0đ",
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ===== TRANG CHỦ DASHBOARD =====
class _HomeDashboard extends StatelessWidget {
  final DriverProfileModel? profile;
  final bool isLoading;
  final Function(int) onNavigate;
  final VoidCallback onRefreshProfile;

  const _HomeDashboard({
    required this.profile,
    required this.isLoading,
    required this.onNavigate,
    required this.onRefreshProfile,
  });

  void _showDepositDialog(BuildContext context, ThemeData theme) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nạp tiền vào ví"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Ví dụ: 500,000", suffixText: "đ"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0 || profile == null) return;
              Navigator.pop(context);
              _showQRDialog(context, theme, amount, "${profile!.id}${DateTime.now().millisecondsSinceEpoch}");
            },
            child: const Text("NẠP TIỀN"),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext context, ThemeData theme, double amount, String content) {
    // Logic Polling nạp tiền của bạn...
  }

  void _showWithdrawDialog(BuildContext context) {
    if (profile == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Yêu cầu rút tiền"),
        content: WithdrawDialogContent(
          currentWallet: profile!.wallet.toDouble(),
          driverId: profile!.id,
        ),
      ),
    ).then((value) {
      if (value == true) onRefreshProfile();
    });
  }

  void _showSupportDialog(BuildContext context) {
    // Logic Support của bạn...
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Fix lỗi thiếu biến theme
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hôm nay bạn thế nào?", style: TextStyle(color: Colors.white70, fontSize: 16)),
                SizedBox(height: 8),
                Text("Sẵn sàng nhận chuyến xe mới!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                _buildMenuCard(context, "NHẬN ĐƠN MỚI", Icons.near_me_rounded, Colors.orange, () => onNavigate(1)),
                _buildMenuCard(context, "LỊCH SỬ CHUYẾN", Icons.assignment_rounded, Colors.blue, () => onNavigate(2)),
                _buildMenuCard(
                    context, "NẠP TIỀN VÍ", Icons.account_balance_wallet_rounded, Colors.green, () => _showDepositDialog(context, theme)),
                _buildMenuCard(
                    context,
                    "RÚT TIỀN",
                    Icons.payments_outlined,
                    Colors.redAccent,
                        () => _showWithdrawDialog(context)),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// ===== DIALOG RÚT TIỀN (VỚI PICKER NGÂN HÀNG CÓ FILTER & LOGO) =====
class WithdrawDialogContent extends StatefulWidget {
  final double currentWallet;
  final int driverId;
  const WithdrawDialogContent({super.key, required this.currentWallet, required this.driverId});

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
    } catch (e) {
      if(mounted) setState(() => _loadingBanks = false);
    }
  }

  void _showBankPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("Chọn ngân hàng", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Tìm tên hoặc mã ngân hàng...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _filteredBanks = _banks.where((bank) {
                          final query = value.toLowerCase();
                          return bank['name'].toString().toLowerCase().contains(query) ||
                              bank['shortName'].toString().toLowerCase().contains(query) ||
                              bank['code'].toString().toLowerCase().contains(query);
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
                          leading: Image.network(bank['logo'], width: 35, errorBuilder: (_,__,___)=>const Icon(Icons.account_balance)),
                          title: Text(bank['shortName']),
                          subtitle: Text(bank['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Future<void> _handleWithdraw() async {
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountText) ?? 0;

    if (amount <= 0 || amount > widget.currentWallet) {
      _showMsg("Số tiền không hợp lệ hoặc vượt quá số dư");
      return;
    }
    if (_selectedBankCode == null || _accountNumberController.text.isEmpty || _accountNameController.text.isEmpty) {
      _showMsg("Vui lòng điền đủ thông tin");
      return;
    }

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

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['message']), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        _showMsg(body['message'] ?? "Thất bại");
      }
    } catch (e) {
      _showMsg("Lỗi kết nối: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMsg(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Số tiền muốn rút", suffixText: "đ"),
          ),
          const SizedBox(height: 12),
          _loadingBanks
              ? const LinearProgressIndicator()
              : InkWell(
            onTap: () => _showBankPicker(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Chọn ngân hàng",
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Row(
                children: [
                  if (_selectedBankLogo != null) ...[
                    Image.network(_selectedBankLogo!, width: 24, height: 24),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: Text(_selectedBankShortName ?? "Chạm để chọn")),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _accountNumberController, decoration: const InputDecoration(labelText: "Số tài khoản")),
          const SizedBox(height: 12),
          TextField(
              controller: _accountNameController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: "Tên chủ tài khoản (viết hoa không dấu)")
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleWithdraw,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("GỬI YÊU CẦU RÚT TIỀN"),
            ),
          )
        ],
      ),
    );
  }
}