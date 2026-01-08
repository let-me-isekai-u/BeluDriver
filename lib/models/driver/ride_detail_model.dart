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
  final String customerNumber;

  final String fromAddress;
  final String fromProvince;

  final String toAddress;
  final String toProvince;

  final String fromDistrict;
  final String toDistrict;

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
    required this.customerNumber,
    required this.fromAddress,
    required this.fromProvince,
    required this.toAddress,
    required this.toProvince,
    required this.fromDistrict,
    required this.toDistrict,
  });

  factory RideDetailModel.fromJson(Map<String, dynamic> json) {
    return RideDetailModel(
      id: json['id'],
      code: json['code'] ?? '',
      status: json['status'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: int.tryParse(json['type'].toString()) ?? 1,
      paymentMethod: json['paymentMethod'] ?? 'Tiền mặt',
      pickupTime: json['pickupTime'],
      note: json['note'],
      customerName: json['customerName'] ?? 'Khách hàng',
      customerNumber: json['customerNumber'] ?? '',
      fromAddress: json['fromAddress'] ?? '',
      fromProvince: json['fromProvince'] ?? '',
      toAddress: json['toAddress'] ?? '',
      toProvince: json['toProvince'] ?? '',
      fromDistrict: json['fromDistrict'],
      toDistrict: json['toDistrict'],
    );
  }

  String get typeText{
    switch (type){
      case 1: return "Chở người";
      case 2: return "Chở người - bao xe";
      case 3: return "Chở hàng";
      case 4: return "Chở hàng hoả tốc";
      default: return "Lỗi không xác định, vui lòng liên hệ cskh";
    }
  }
}
