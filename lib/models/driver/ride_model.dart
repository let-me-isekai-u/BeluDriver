import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../broker_ride_models.dart';

class RideModel {
  final int id;
  final String code;
  final String createdAt;
  final String? pickupTime;

  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;

  final String toProvince;
  final String toDistrict;
  final String toAddress;

  final double price;
  final double netIncome;
  final int status;
  final String paymentMethod;
  final int type;
  final int? quantity;

  final int rideSource;

  RideModel({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.pickupTime,
    required this.fromProvince,
    required this.fromDistrict,
    required this.fromAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.toAddress,
    required this.price,
    required this.netIncome,
    required this.status,
    required this.paymentMethod,
    required this.type,
    required this.quantity,
    required this.rideSource,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: _parseInt(json['rideId'] ?? json['id']),
      code: (json['code'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? DateTime.now().toIso8601String())
          .toString(),
      pickupTime: json['pickupTime']?.toString(),

      fromProvince: (json['fromProvince'] ?? '').toString(),
      fromDistrict: (json['fromDistrict'] ?? '').toString(),
      fromAddress: (json['fromAddress'] ?? '').toString(),

      toProvince: (json['toProvince'] ?? '').toString(),
      toDistrict: (json['toDistrict'] ?? '').toString(),
      toAddress: (json['toAddress'] ?? '').toString(),

      price: _parseDouble(json['price']),
      netIncome: _parseDouble(json['netIncome']),

      status: _parseInt(json['status'], defaultValue: -1),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      type: _parseInt(json['type'], defaultValue: 1),
      quantity: _parseNullableInt(json['quantity']),

      rideSource: _parseInt(json['rideSource'], defaultValue: 1),
    );
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return createdAt;
    }
  }

  String get formattedPrice {
    try {
      final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
      return fmt.format(price);
    } catch (_) {
      return '${price.toStringAsFixed(0)} ₫';
    }
  }

  String get formattedNetIncome {
    try {
      final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
      return fmt.format(netIncome);
    } catch (_) {
      return '${netIncome.toStringAsFixed(0)} ₫';
    }
  }

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

  String get rideTypeOrQuantityText {
    switch (type) {
      case BrokerRideType.passenger:
        if (quantity != null) {
          return '$quantity ghế';
        }
        return '';
      case BrokerRideType.charter5Seats:
        return 'Bao xe 5 chỗ';
      case BrokerRideType.charter7Seats:
        return 'Bao xe 7 chỗ';
      default:
        return '';
    }
  }
}
