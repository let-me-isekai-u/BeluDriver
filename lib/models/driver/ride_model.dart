import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideModel {
  final int id;
  final String code;
  final String createdAt;
  final String fromAddress;
  final String toAddress;
  final double price;
  final int status;
  final String paymentMethod;

  RideModel({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    required this.status,
    required this.paymentMethod,
  });

  // Chuyển từ JSON API sang Object
  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['rideId'] ?? 0,
      code: json['code'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
      fromAddress: "${json['fromAddress']}, ${json['fromProvince']}",
      toAddress: "${json['toAddress']}, ${json['toProvince']}",
      price: (json['price'] ?? 0).toDouble(),
      status: int.tryParse(json['status'].toString()) ?? -1,
      paymentMethod: json['paymentMethod'] ?? "Chưa xác định",
    );
  }

  // Các Helper getters để xử lý logic hiển thị
  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(createdAt));

  String get formattedPrice => "${NumberFormat('#,###').format(price)}đ";

  String get statusText {
    switch (status) {
      case 3: return "Đang di chuyển";
      case 4: return "Hoàn thành";
      case 5: return "Đã hủy";
      default: return "Không xác định";
    }
  }

  Color get statusColor {
    switch (status) {
      case 3: return Colors.orange;
      case 4: return Colors.green;
      case 5: return Colors.red;
      default: return Colors.grey;
    }
  }
}