class WaitingRide {
  final int id;
  final String? code;
  final String? fromAddress;
  final String? fromDistrict;
  final String? fromProvince;
  final String? toAddress;
  final String? toDistrict;
  final String? toProvince;
  final String? pickupTime;
  final double price;
  final int status;

  WaitingRide({
    required this.id,
    this.code,
    this.fromAddress,
    this.fromProvince,
    this.toAddress,
    this.toProvince,
    this.pickupTime,
    required this.price,
    required this.status,
    this.fromDistrict,
    this.toDistrict,
  });

  factory WaitingRide.fromJson(Map<String, dynamic> json) {
    return WaitingRide(
      id: json['id'] ?? 0,
      code: json['code'],
      fromAddress: json['fromAddress'],
      fromProvince: json['fromProvince'],
      toAddress: json['toAddress'],
      toProvince: json['toProvince'],
      pickupTime: json['pickupTime'],
      price: (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      fromDistrict: json['fromDistrict'],
      toDistrict: json['toDistrict'],
    );
  }
}