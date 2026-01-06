import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../models/driver/withdrawal_history_model.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  // Khai báo Future để giữ trạng thái dữ liệu, tránh load lại khi build
  late Future<List<WithdrawalHistoryModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  // Hàm làm mới dữ liệu cho RefreshIndicator
  Future<void> _handleRefresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  // ======================
  // UTILS
  // ======================
  Color _getStatusColor(String status) {
    // Sử dụng toLowerCase() để so sánh an toàn hơn
    final s = status.toLowerCase();
    if (s.contains("hoàn thành") || s.contains("success")) return Colors.green;
    if (s.contains("đang xử lý") || s.contains("pending")) return Colors.orange;
    if (s.contains("từ chối") || s.contains("cancel") || s.contains("reject")) return Colors.red;
    return Colors.grey;
  }

  String _formatDateTime(String dateStr) {
    if (dateStr.isEmpty) return "---";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }

  // ======================
  // LOAD API → MODEL
  // ======================
  Future<List<WithdrawalHistoryModel>> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getWithdrawalHistory(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => WithdrawalHistoryModel.fromJson(e))
              .toList();
        }
      }
      return []; // Trả về list rỗng nếu không có data
    } catch (e) {
      debugPrint("Error loadHistory: $e");
      throw Exception("Không thể tải lịch sử rút tiền. Vui lòng thử lại!");
    }
  }

  // ======================
  // UI
  // ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            "Lịch sử rút tiền",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: FutureBuilder<List<WithdrawalHistoryModel>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView( // Dùng ListView để có thể kéo Refresh khi lỗi
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(child: Text("Lỗi: ${snapshot.error}")),
                  ],
                );
              }

              final list = snapshot.data ?? [];

              if (list.isEmpty) {
                return ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("Bạn chưa có yêu cầu rút tiền nào", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final statusColor = _getStatusColor(item.status);

                  // KIỂM TRA AN TOÀN TRƯỚC KHI DÙNG
                  final String currentStatus = item.status.toLowerCase();
                  final bool isReject = currentStatus.contains("từ chối") || currentStatus.contains("cancel");

                  // Tránh lỗi Null bằng cách kiểm tra rỗng
                  final bool hasReason = (item.reasonCancel?.isNotEmpty ?? false);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatCurrency(item.amount),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(item.createDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isReject && hasReason) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 56),
                            child: Divider(height: 24, thickness: 0.5),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 56),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.cancel_outlined, size: 14, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Lý do từ chối: ${item.reasonCancel}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );

            },
          ),
        ),
    );
    }
}