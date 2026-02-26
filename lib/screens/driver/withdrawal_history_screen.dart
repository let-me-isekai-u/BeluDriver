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
  late Future<List<WithdrawalHistoryModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("hoàn thành") || s.contains("success")) return Colors.green;
    if (s.contains("đang xử lý") || s.contains("pending")) return Colors.orange;
    if (s.contains("từ chối") || s.contains("cancel") || s.contains("reject")) {
      return Colors.red;
    }
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
      return [];
    } catch (e) {
      debugPrint("Error loadHistory: $e");
      throw Exception("Không thể tải lịch sử rút tiền. Vui lòng thử lại!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Lịch sử rút tiền",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<WithdrawalHistoryModel>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: theme.colorScheme.secondary),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Text(
                      "Lỗi: ${snapshot.error}",
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Bạn chưa có yêu cầu rút tiền nào",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
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

                final String currentStatus = item.status.toLowerCase();
                final bool isReject = currentStatus.contains("từ chối") ||
                    currentStatus.contains("cancel");

                final bool hasReason = (item.reasonCancel?.isNotEmpty ?? false);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
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
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(item.createDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.35)),
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
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: Divider(
                            height: 24,
                            thickness: 0.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.12),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cancel_outlined,
                                  size: 14, color: Colors.redAccent),
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