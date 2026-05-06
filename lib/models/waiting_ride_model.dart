class WaitingRide {
  final int id;
  final int rideSource;
  final String? code;
  final String? createdAt;
  final String? fromAddress;
  final String? fromDistrict;
  final String? fromProvince;
  final String? toAddress;
  final String? toDistrict;
  final String? toProvince;
  final String? pickupTime;
  final double price;
  final double netIncome;
  final int status;

  WaitingRide({
    required this.id,
    required this.rideSource,
    this.code,
    this.createdAt,
    this.fromAddress,
    this.fromProvince,
    this.toAddress,
    this.toProvince,
    this.pickupTime,
    required this.price,
    required this.netIncome,
    required this.status,
    this.fromDistrict,
    this.toDistrict,
  });

  factory WaitingRide.fromJson(Map<String, dynamic> json) {
    return WaitingRide(
      id: _parseInt(json['id']),
      rideSource: _parseInt(json['rideSource'], defaultValue: 1),
      code: json['code']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['createAt']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      fromProvince: json['fromProvince']?.toString(),
      toAddress: json['toAddress']?.toString(),
      toProvince: json['toProvince']?.toString(),
      pickupTime: json['pickupTime']?.toString(),
      price: _parseDouble(json['price']),
      netIncome: _parseDouble(json['netIncome'] ?? json['net_income']),
      status: _parseInt(json['status']),
      fromDistrict: json['fromDistrict']?.toString(),
      toDistrict: json['toDistrict']?.toString(),
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
}