class RouteOptionModel {
  final int provinceId;
  final String provinceName;
  final int toHaNoiRouteId;
  final String toHaNoiRouteName;
  final int fromHaNoiRouteId;
  final String fromHaNoiRouteName;

  RouteOptionModel({
    required this.provinceId,
    required this.provinceName,
    required this.toHaNoiRouteId,
    required this.toHaNoiRouteName,
    required this.fromHaNoiRouteId,
    required this.fromHaNoiRouteName,
  });

  factory RouteOptionModel.fromJson(Map<String, dynamic> json) {
    return RouteOptionModel(
      provinceId: json['provinceId'] ?? 0,
      provinceName: json['provinceName'] ?? '',
      toHaNoiRouteId: json['toHaNoiRouteId'] ?? 0,
      toHaNoiRouteName: json['toHaNoiRouteName'] ?? '',
      fromHaNoiRouteId: json['fromHaNoiRouteId'] ?? 0,
      fromHaNoiRouteName: json['fromHaNoiRouteName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinceId': provinceId,
      'provinceName': provinceName,
      'toHaNoiRouteId': toHaNoiRouteId,
      'toHaNoiRouteName': toHaNoiRouteName,
      'fromHaNoiRouteId': fromHaNoiRouteId,
      'fromHaNoiRouteName': fromHaNoiRouteName,
    };
  }
}

class SelectedProvinceModel {
  final int provinceId;
  final String provinceName;

  SelectedProvinceModel({
    required this.provinceId,
    required this.provinceName,
  });

  factory SelectedProvinceModel.fromJson(Map<String, dynamic> json) {
    return SelectedProvinceModel(
      provinceId: json['provinceId'] ?? 0,
      provinceName: json['provinceName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinceId': provinceId,
      'provinceName': provinceName,
    };
  }
}

class DriverRouteModel {
  final int routeId;
  final String code;
  final String name;
  final int fromProvinceId;
  final String fromProvinceName;
  final int toProvinceId;
  final String toProvinceName;

  DriverRouteModel({
    required this.routeId,
    required this.code,
    required this.name,
    required this.fromProvinceId,
    required this.fromProvinceName,
    required this.toProvinceId,
    required this.toProvinceName,
  });

  factory DriverRouteModel.fromJson(Map<String, dynamic> json) {
    return DriverRouteModel(
      routeId: json['routeId'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      fromProvinceId: json['fromProvinceId'] ?? 0,
      fromProvinceName: json['fromProvinceName'] ?? '',
      toProvinceId: json['toProvinceId'] ?? 0,
      toProvinceName: json['toProvinceName'] ?? '',
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

class OnboardingModel {
  final int driverId;
  final bool hasRegisteredRoute;
  final int selectedProvinceCount;
  final int kycStatus;
  final String kycStatusText;
  final String? kycRejectReason;
  final bool canReceiveRide;
  final String nextStep;

  OnboardingModel({
    required this.driverId,
    required this.hasRegisteredRoute,
    required this.selectedProvinceCount,
    required this.kycStatus,
    required this.kycStatusText,
    required this.kycRejectReason,
    required this.canReceiveRide,
    required this.nextStep,
  });

  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    return OnboardingModel(
      driverId: json['driverId'] ?? 0,
      hasRegisteredRoute: json['hasRegisteredRoute'] ?? false,
      selectedProvinceCount: json['selectedProvinceCount'] ?? 0,
      kycStatus: json['kycStatus'] ?? 0,
      kycStatusText: json['kycStatusText'] ?? '',
      kycRejectReason: json['kycRejectReason'],
      canReceiveRide: json['canReceiveRide'] ?? false,
      nextStep: json['nextStep'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'hasRegisteredRoute': hasRegisteredRoute,
      'selectedProvinceCount': selectedProvinceCount,
      'kycStatus': kycStatus,
      'kycStatusText': kycStatusText,
      'kycRejectReason': kycRejectReason,
      'canReceiveRide': canReceiveRide,
      'nextStep': nextStep,
    };
  }
}

class RegisterRoutesResponseModel {
  final int maxProvinceCount;
  final List<SelectedProvinceModel> selectedProvinces;
  final List<DriverRouteModel> routes;
  final OnboardingModel? onboarding;

  RegisterRoutesResponseModel({
    required this.maxProvinceCount,
    required this.selectedProvinces,
    required this.routes,
    required this.onboarding,
  });

  factory RegisterRoutesResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterRoutesResponseModel(
      maxProvinceCount: json['maxProvinceCount'] ?? 0,
      selectedProvinces: (json['selectedProvinces'] as List? ?? [])
          .map((e) => SelectedProvinceModel.fromJson(e))
          .toList(),
      routes: (json['routes'] as List? ?? [])
          .map((e) => DriverRouteModel.fromJson(e))
          .toList(),
      onboarding: json['onboarding'] != null
          ? OnboardingModel.fromJson(json['onboarding'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxProvinceCount': maxProvinceCount,
      'selectedProvinces': selectedProvinces.map((e) => e.toJson()).toList(),
      'routes': routes.map((e) => e.toJson()).toList(),
      'onboarding': onboarding?.toJson(),
    };
  }
}

class UpdateRoutesRequestModel {
  final List<int> provinceIds;

  UpdateRoutesRequestModel({
    required this.provinceIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'provinceIds': provinceIds,
    };
  }
}