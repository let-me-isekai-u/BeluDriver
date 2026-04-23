class DriverOnboardingStatusDto {
  final int driverId;
  final bool hasRegisteredRoute;
  final int selectedProvinceCount;
  final int kycStatus;
  final String kycStatusText;
  final String? kycRejectReason;
  final bool canReceiveRide;
  final String nextStep;

  DriverOnboardingStatusDto({
    required this.driverId,
    required this.hasRegisteredRoute,
    required this.selectedProvinceCount,
    required this.kycStatus,
    required this.kycStatusText,
    this.kycRejectReason,
    required this.canReceiveRide,
    required this.nextStep,
  });

  factory DriverOnboardingStatusDto.fromJson(Map<String, dynamic> json) {
    return DriverOnboardingStatusDto(
      driverId: json['driverId'],
      hasRegisteredRoute: json['hasRegisteredRoute'],
      selectedProvinceCount: json['selectedProvinceCount'],
      kycStatus: json['kycStatus'],
      kycStatusText: json['kycStatusText'],
      kycRejectReason: json['kycRejectReason'],
      canReceiveRide: json['canReceiveRide'],
      nextStep: json['nextStep'],
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