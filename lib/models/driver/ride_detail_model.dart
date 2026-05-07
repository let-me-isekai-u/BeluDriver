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
    String pickCustomerName() {
      // Ver2 (rideSource=2) có thể trả tên ở key khác nhau so với Ver1.
      // Ưu tiên customerNameV2 trước, sau đó fallback sang V1, rồi tới customerName.
      final candidates = <String?>[
        json['customerNameV2']?.toString(),
        json['customer_name_v2']?.toString(),
        json['customerNameV1']?.toString(),
        json['customer_name_v1']?.toString(),
        json['customerName']?.toString(),
        json['customer_name']?.toString(),
      ];
      for (final v in candidates) {
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return 'Khách hàng';
    }

    String pickCustomerPhone() {
      final candidates = <String?>[
        json['customerPhoneV2']?.toString(),
        json['customer_phone_v2']?.toString(),
        json['customerPhoneV1']?.toString(),
        json['customer_phone_v1']?.toString(),
        json['customerPhone']?.toString(),
        json['customer_number']?.toString(),
        json['customerNumber']?.toString(),
      ].whereType<String>();

      for (final v in candidates) {
        final trimmed = v.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

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
      customerName: pickCustomerName(),
      customerPhone: pickCustomerPhone(),
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