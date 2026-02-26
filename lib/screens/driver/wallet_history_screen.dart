import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _currentBalance = "0";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = "Phiên đăng nhập hết hạn.";
          _isLoading = false;
        });
        return;
      }

      // A) wallet balance
      final profileRes = await ApiService.getDriverProfile(accessToken: token);
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        final dynamic wallet = profileData['wallet'];
        if (wallet is num) {
          _currentBalance = wallet.toStringAsFixed(0);
        } else {
          // fallback if server returns string
          _currentBalance = (double.tryParse(wallet?.toString() ?? '') ?? 0)
              .toStringAsFixed(0);
        }
      }

      // B) history
      final historyRes = await ApiService.getWalletHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final Map<String, dynamic> historyData = jsonDecode(historyRes.body);
        if (historyData['success'] == true) {
          _transactions = historyData['data'] ?? [];
        }
      } else {
        _errorMessage = "Lỗi kết nối lịch sử (${historyRes.statusCode})";
      }
    } catch (e) {
      _errorMessage = "Đã có lỗi xảy ra: $e";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Lịch sử giao dịch",
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
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.secondary),
            onPressed: _fetchData,
          )
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(theme),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Biến động số dư",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.secondary,
              ),
            )
                : _errorMessage != null
                ? _buildErrorWidget(theme)
                : _transactions.isEmpty
                ? Center(
              child: Text(
                "Bạn chưa có giao dịch nào.",
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            )
                : _buildTransactionList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Số dư ví BeluDriver",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "$_currentBalance đ",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: theme.colorScheme.onSurface.withOpacity(0.12),
      ),
      itemBuilder: (context, index) {
        final item = _transactions[index];
        final num amount = item['amount'] ?? 0;
        final bool isNegative = amount < 0;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isNegative
                    ? Colors.red.withOpacity(0.12)
                    : Colors.green.withOpacity(0.12),
                child: Icon(
                  isNegative
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                  color: isNegative ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['type']?.toString() ?? "Giao dịch",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(item['createdDate']?.toString()),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${isNegative ? '' : '+'}$amount đ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNegative ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: Colors.black87,
            ),
            child: const Text("Thử lại"),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "--:--";
    try {
      final DateTime dt = DateTime.parse(dateStr);
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }
}