import '../broker_ride_models.dart';

class RideDetailModel {
  final int id;
  final String code;
  final int status;
  final double price;
  final double netIncome;
  final int type;
  final String paymentMethod;
  final String? pickupTime;
  final String? note;

  final String customerName;
  final String customerPhone;

  final String fromAddress;
  final String fromProvince;
  final String fromDistrict;

  final String toAddress;
  final String toProvince;
  final String toDistrict;

  final String createdAt;
  final int quantity;

  RideDetailModel({
    required this.id,
    required this.code,
    required this.status,
    required this.price,
    required this.netIncome,
    required this.type,
    required this.paymentMethod,
    this.pickupTime,
    this.note,
    required this.customerName,
    required this.customerPhone,
    required this.fromAddress,
    required this.fromProvince,
    required this.fromDistrict,
    required this.toAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.createdAt,
    required this.quantity,
  });

  factory RideDetailModel.fromJson(Map<String, dynamic> json) {
    return RideDetailModel(
      id: _parseInt(json['id']),
      code: (json['code'] ?? '').toString(),
      status: _parseInt(json['status']),
      price: _parseDouble(json['price']),
      netIncome: _parseDouble(json['netIncome'] ?? json['net_income']),
      type: _parseInt(json['type'], defaultValue: 1),
      paymentMethod: (json['paymentMethod'] ?? 'Tiền mặt').toString(),
      pickupTime: json['pickupTime']?.toString(),
      note: json['note']?.toString(),
      customerName: (json['customerName'] ?? 'Khách hàng').toString(),
      customerPhone: (json['customerPhone'] ?? json['customerNumber'] ?? '').toString(),
      fromAddress: (json['fromAddress'] ?? '').toString(),
      fromProvince: (json['fromProvince'] ?? '').toString(),
      fromDistrict: (json['fromDistrict'] ?? '').toString(),
      toAddress: (json['toAddress'] ?? '').toString(),
      toProvince: (json['toProvince'] ?? '').toString(),
      toDistrict: (json['toDistrict'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      quantity: _parseInt(json['quantity'], defaultValue: 1),
    );
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  String get typeText {
    return BrokerRideType.labelOf(type);
  }
}