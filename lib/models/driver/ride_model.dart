import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideModel {
  final int id;
  final String code;
  final String createdAt;

  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;

  final String toProvince;
  final String toDistrict;
  final String toAddress;

  final double price;
  final int status;
  final String paymentMethod;

  final int rideSource; // 👈 thêm

  RideModel({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.fromProvince,
    required this.fromDistrict,
    required this.fromAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.toAddress,
    required this.price,
    required this.status,
    required this.paymentMethod,
    required this.rideSource, // 👈 thêm
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['rideId'] ?? json['id'] ?? 0,
      code: json['code'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),

      fromProvince: json['fromProvince'] ?? '',
      fromDistrict: json['fromDistrict'] ?? '',
      fromAddress: json['fromAddress'] ?? '',

      toProvince: json['toProvince'] ?? '',
      toDistrict: json['toDistrict'] ?? '',
      toAddress: json['toAddress'] ?? '',

      price: (json['price'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? -1,
      paymentMethod: json['paymentMethod'] ?? '',

      rideSource: json['rideSource'] ?? 1, // 👈 thêm
    );
  }

  // ------------ Helper getters used by UI ------------

  // Format createdAt (ISO string) -> "dd/MM/yyyy HH:mm"
  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return createdAt;
    }
  }

  // Format price as Vietnamese dong
  String get formattedPrice {
    try {
      final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
      return fmt.format(price);
    } catch (_) {
      return '${price.toStringAsFixed(0)} ₫';
    }
  }

  // Map status -> readable text
  String get statusText {
    switch (status) {
      case 0:
        return 'Chờ';
      case 1:
        return 'Đang đón';
      case 2:
        return 'Đang di chuyển';
      case 3:
        return 'Đang đến nơi';
      case 4:
        return 'Hoàn thành';
      case 5:
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  // Map status -> Color
  Color get statusColor {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.indigo;
      case 3:
        return Colors.green;
      case 4:
        return Colors.grey;
      case 5:
        return Colors.red;
      default:
        return Colors.black54;
    }
  }
}