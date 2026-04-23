class DriverProfileModel {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String licenseNumber;
  final double wallet;
  final String avatarUrl;
  final List<SelectedProvince> selectedProvinces;
  final List<DriverRoute> routes;

  DriverProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.wallet,
    required this.avatarUrl,
    required this.selectedProvinces,
    required this.routes,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      licenseNumber: json['licenseNumber']?.toString() ?? '',
      wallet: (json['wallet'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      selectedProvinces: (json['selectedProvinces'] as List<dynamic>? ?? [])
          .map((e) => SelectedProvince.fromJson(e as Map<String, dynamic>))
          .toList(),
      routes: (json['routes'] as List<dynamic>? ?? [])
          .map((e) => DriverRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      'selectedProvinces': selectedProvinces.map((e) => e.toJson()).toList(),
      'routes': routes.map((e) => e.toJson()).toList(),
    };
  }
}

class SelectedProvince {
  final int provinceId;
  final String provinceName;

  SelectedProvince({
    required this.provinceId,
    required this.provinceName,
  });

  factory SelectedProvince.fromJson(Map<String, dynamic> json) {
    return SelectedProvince(
      provinceId: (json['provinceId'] as num?)?.toInt() ?? 0,
      provinceName: json['provinceName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinceId': provinceId,
      'provinceName': provinceName,
    };
  }
}

class DriverRoute {
  final int routeId;
  final String code;
  final String name;
  final int fromProvinceId;
  final String fromProvinceName;
  final int toProvinceId;
  final String toProvinceName;

  DriverRoute({
    required this.routeId,
    required this.code,
    required this.name,
    required this.fromProvinceId,
    required this.fromProvinceName,
    required this.toProvinceId,
    required this.toProvinceName,
  });

  factory DriverRoute.fromJson(Map<String, dynamic> json) {
    return DriverRoute(
      routeId: (json['routeId'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fromProvinceId: (json['fromProvinceId'] as num?)?.toInt() ?? 0,
      fromProvinceName: json['fromProvinceName']?.toString() ?? '',
      toProvinceId: (json['toProvinceId'] as num?)?.toInt() ?? 0,
      toProvinceName: json['toProvinceName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'code': code,
      'name': name,
      'fromProvinceId': fromProvinceId,
      'fromProvinceName': fromProvinceName,
      'toProvinceId': toProvinceId,
      'toProvinceName': toProvinceName,
    };
  }
}