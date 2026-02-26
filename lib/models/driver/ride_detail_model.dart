class RideDetailModel {
  final int id;
  final String code;
  final int status;
  final double price;
  final int type;
  final String paymentMethod;
  final String? pickupTime;
  final String? note;

  final String customerName;
  final String customerPhone; // 👈 đổi tên đúng theo API

  final String fromAddress;
  final String fromProvince;
  final String fromDistrict;

  final String toAddress;
  final String toProvince;
  final String toDistrict;

  final String createdAt; // 👈 thêm
  final int quantity;     // 👈 thêm

  RideDetailModel({
    required this.id,
    required this.code,
    required this.status,
    required this.price,
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
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      status: json['status'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: int.tryParse(json['type'].toString()) ?? 1,
      paymentMethod: json['paymentMethod'] ?? 'Tiền mặt',
      pickupTime: json['pickupTime'],
      note: json['note'],
      customerName: json['customerName'] ?? 'Khách hàng',
      customerPhone: json['customerPhone'] ?? '',
      fromAddress: json['fromAddress'] ?? '',
      fromProvince: json['fromProvince'] ?? '',
      fromDistrict: json['fromDistrict'] ?? '',
      toAddress: json['toAddress'] ?? '',
      toProvince: json['toProvince'] ?? '',
      toDistrict: json['toDistrict'] ?? '',
      createdAt: json['createdAt'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }

  String get typeText {
    switch (type) {
      case 1:
        return "Chở người";
      case 2:
        return "Chở người - bao xe";
      case 3:
        return "Chở hàng";
      case 4:
        return "Chở hàng hoả tốc";
      default:
        return "Không xác định";
    }
  }
}