import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/driver/driver_profile_model.dart';
import 'driver_profile.dart';
import 'recieve_order_screen.dart';
import 'activity_history.dart';
import 'dart:async';
import 'withdrawal_history_screen.dart';
import 'package:intl/intl.dart';

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
      toolbarHeight: 90,
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Stack(
        children: [
          // Họa tiết lồng đèn trang trí góc AppBar
          Positioned(
            right: -10,
            top: 0,
            child: Opacity(
              opacity: 0.2,
              child: Icon(Icons.festival, size: 100, color: Colors.yellowAccent),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.yellowAccent.withOpacity(0.6), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundImage: (_profile != null && _profile!.avatarUrl.isNotEmpty)
                          ? NetworkImage(_profile!.avatarUrl)
                          : null,
                      child: (_profile == null || _profile!.avatarUrl.isEmpty)
                          ? const Icon(Icons.person, size: 28, color: Colors.white)
                          : null,
                    ),
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
                          color: Colors.redAccent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.yellowAccent, width: 0.5),
                        ),
                        child: const Text(
                          "🧧 CHÚC MỪNG NĂM MỚI",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
  final VoidCallback onRefreshProfile;

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
          // Banner Header Tết
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30)
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Vạn sự như ý! ✨",
                        style: TextStyle(color: Colors.yellowAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Text("Khai xuân nhận chuyến,\nrước lộc về nhà!",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: -10,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(Icons.brightness_7, color: Colors.yellowAccent, size: 80),
                ),
              )
            ],
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
                _buildMenuCard(context, "NHẬN ĐƠN MỚI", Icons.near_me_rounded, Colors.orange,
                        () => onNavigate(1), isSpecial: true),
                _buildMenuCard(context, "LỊCH SỬ CHUYẾN", Icons.assignment_rounded, Colors.blue,
                        () => onNavigate(2)),
                _buildMenuCard(context, "NẠP TIỀN VÍ", Icons.account_balance_wallet_rounded, Colors.green,
                        () => _showDepositDialog(context, theme)),
                _buildMenuCard(context, "RÚT TIỀN", Icons.payments_outlined, Colors.redAccent,
                        () => _showWithdrawDialog(context)),
                _buildMenuCard(
                  context,
                  "LỊCH SỬ RÚT",
                  Icons.history_rounded,
                  Colors.purple,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WithdrawalHistoryScreen()),
                  ),
                ),
              ],
            ),
          ),

          // Thêm một dòng chữ nhỏ cuối trang
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("Chúc bạn một năm mới bình an trên mọi nẻo đường!",
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap, {bool isSpecial = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: isSpecial ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSpecial ? const BorderSide(color: Colors.redAccent, width: 1.5) : BorderSide.none,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isSpecial)
                  const Icon(Icons.circle, color: Colors.yellowAccent, size: 45),
                Icon(icon, size: 38, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
            ),
          ],
        ),
      ),
    );
  }

  // --- Giữ nguyên các hàm Dialog của bạn ---
  void _showDepositDialog(BuildContext parentContext, ThemeData theme) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("🧧 Nạp tiền khai xuân"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Ví dụ: 500.000",
            suffixText: "đ",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0 || profile == null) return;
              final now = DateTime.now();
              final timeStr = DateFormat('HHmmss').format(now);
              final content = "${profile!.id}$timeStr";
              Navigator.pop(dialogContext);
              _showQRDialog(parentContext, theme, amount, content);
            },
            child: const Text("NẠP TIỀN"),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext parentContext, ThemeData theme, double amount, String content) async {
    final confirmed = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Lưu ý quan trọng"),
        content: const Text("Vui lòng KHÔNG tắt ứng dụng cho đến khi hệ thống xác nhận thành công."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Tôi đã hiểu")),
        ],
      ),
    );
    if (confirmed != true) return;

    final qrUrl = "https://img.vietqr.io/image/MB-246878888-compact2.png?amount=${amount.toStringAsFixed(0)}&addInfo=$content&accountName=CTY%20CP%20CN%20VA%20DV%20TT%20THE%20BELUGAS";
    int countdown = 300;
    Timer? countdownTimer;
    Timer? pollTimer;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown <= 0) {
                t.cancel();
                pollTimer?.cancel();
                Navigator.pop(dialogCtx);
              } else {
                setState(() => countdown--);
              }
            });

            pollTimer ??= Timer(const Duration(seconds: 15), () {
              pollTimer = Timer.periodic(const Duration(seconds: 7), (t) async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('accessToken') ?? '';
                  final res = await ApiService.depositWallet(accessToken: token, amount: amount, content: content);
                  if (res.statusCode == 200) {
                    final body = jsonDecode(res.body);
                    if (body['success'] == true) {
                      countdownTimer?.cancel();
                      t.cancel();
                      Navigator.pop(dialogCtx);
                      onRefreshProfile();
                    }
                  }
                } catch (_) {}
              });
            });

            final minutes = countdown ~/ 60;
            final seconds = (countdown % 60).toString().padLeft(2, '0');

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Quét mã QR để nạp tiền", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Image.network(qrUrl, height: 280),
                    const SizedBox(height: 8),
                    Text("Số tiền: ${amount.toStringAsFixed(0)} đ"),
                    Text("Còn lại: $minutes:$seconds", style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () {
                        countdownTimer?.cancel();
                        pollTimer?.cancel();
                        Navigator.pop(dialogCtx);
                      },
                      child: const Text("Đóng"),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    if (profile == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("🧧 Rút lộc may mắn"),
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

// Giữ nguyên lớp WithdrawDialogContent và logic rút tiền của bạn
class WithdrawDialogContent extends StatefulWidget {
  final double currentWallet;
  final int driverId;
  const WithdrawDialogContent({super.key, required this.currentWallet, required this.driverId});
  @override
  State<WithdrawDialogContent> createState() => _WithdrawDialogContentState();
}

class _WithdrawDialogContentState extends State<WithdrawDialogContent> {
  // ... Giữ nguyên toàn bộ code logic của WithdrawDialogContent cũ ...
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
                      hintText: "Tìm ngân hàng...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _filteredBanks = _banks.where((bank) {
                          final q = value.toLowerCase();
                          return bank['name'].toString().toLowerCase().contains(q) ||
                              bank['shortName'].toString().toLowerCase().contains(q);
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
        accessToken: token, amount: amount,
        bankCode: _selectedBankCode!, bankName: _selectedBankName!,
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Số tiền muốn rút")),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showBankPicker(context),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: "Chọn ngân hàng"),
              child: Text(_selectedBankShortName ?? "Chạm để chọn"),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _accountNumberController, decoration: const InputDecoration(labelText: "Số tài khoản")),
          const SizedBox(height: 12),
          TextField(controller: _accountNameController, decoration: const InputDecoration(labelText: "Tên chủ tài khoản")),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmWithdraw,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("GỬI YÊU CẦU RÚT TIỀN"),
            ),
          )
        ],
      ),
    );
  }
}