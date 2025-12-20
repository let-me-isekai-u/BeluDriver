class DriverProfileModel {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String licenseNumber;
  final double wallet;
  final String avatarUrl;

  DriverProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.wallet,
    required this.avatarUrl,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      wallet: (json['wallet'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'wallet': wallet,
      'avatarUrl': avatarUrl,
    };
  }
}
