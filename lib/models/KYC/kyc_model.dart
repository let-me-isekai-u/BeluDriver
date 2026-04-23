import 'dart:convert';

// =============================================================================
// KYC STATUS MODEL
// Dùng cho: GET /kyc và response của POST /kyc/submit
// =============================================================================

class KycModel {
  final int status;
  final String kycStatusText;
  final String? rejectReason;
  final int resubmitCount;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final bool canSubmit;

  final String? vehiclePhotoUrl;
  final String? citizenFrontUrl;
  final String? citizenBackUrl;
  final String? vehicleRegistrationUrl;
  final String? driverLicenseUrl;
  final String? portraitUrl;
  final String? faceFrontUrl;
  final String? faceRightUrl;
  final String? faceLeftUrl;

  KycModel({
    required this.status,
    required this.kycStatusText,
    required this.rejectReason,
    required this.resubmitCount,
    required this.submittedAt,
    required this.reviewedAt,
    required this.canSubmit,
    required this.vehiclePhotoUrl,
    required this.citizenFrontUrl,
    required this.citizenBackUrl,
    required this.vehicleRegistrationUrl,
    required this.driverLicenseUrl,
    required this.portraitUrl,
    required this.faceFrontUrl,
    required this.faceRightUrl,
    required this.faceLeftUrl,
  });

  factory KycModel.fromRawJson(String str) {
    return KycModel.fromJson(jsonDecode(str));
  }

  String toRawJson() => jsonEncode(toJson());

  factory KycModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return KycModel(
      status: (json["status"] as num?)?.toInt() ?? 0,
      kycStatusText: json["kycStatusText"]?.toString() ?? "",
      rejectReason: json["rejectReason"]?.toString(),
      resubmitCount: (json["resubmitCount"] as num?)?.toInt() ?? 0,
      submittedAt: parseDate(json["submittedAt"]),
      reviewedAt: parseDate(json["reviewedAt"]),
      canSubmit: json["canSubmit"] == true,
      vehiclePhotoUrl: json["vehiclePhotoUrl"]?.toString(),
      citizenFrontUrl: json["citizenFrontUrl"]?.toString(),
      citizenBackUrl: json["citizenBackUrl"]?.toString(),
      vehicleRegistrationUrl: json["vehicleRegistrationUrl"]?.toString(),
      driverLicenseUrl: json["driverLicenseUrl"]?.toString(),
      portraitUrl: json["portraitUrl"]?.toString(),
      faceFrontUrl: json["faceFrontUrl"]?.toString(),
      faceRightUrl: json["faceRightUrl"]?.toString(),
      faceLeftUrl: json["faceLeftUrl"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "status": status,
      "kycStatusText": kycStatusText,
      "rejectReason": rejectReason,
      "resubmitCount": resubmitCount,
      "submittedAt": submittedAt?.toIso8601String(),
      "reviewedAt": reviewedAt?.toIso8601String(),
      "canSubmit": canSubmit,
      "vehiclePhotoUrl": vehiclePhotoUrl,
      "citizenFrontUrl": citizenFrontUrl,
      "citizenBackUrl": citizenBackUrl,
      "vehicleRegistrationUrl": vehicleRegistrationUrl,
      "driverLicenseUrl": driverLicenseUrl,
      "portraitUrl": portraitUrl,
      "faceFrontUrl": faceFrontUrl,
      "faceRightUrl": faceRightUrl,
      "faceLeftUrl": faceLeftUrl,
    };
  }

  KycStatus get statusEnum {
    switch (status) {
      case 0:
        return KycStatus.notStarted;
      case 1:
        return KycStatus.pending;
      case 2:
        return KycStatus.approved;
      case 3:
        return KycStatus.rejected;
      default:
        return KycStatus.unknown;
    }
  }

  bool get isPending => status == 1;
  bool get isApproved => status == 2;
  bool get isRejected => status == 3;
  bool get isNotStarted => status == 0;

  bool get canUploadKyc => canSubmit;
  bool get canFirstSubmit => isNotStarted && canSubmit;
  bool get canResubmit => isRejected && canSubmit;

  // Alias để tương thích với các chỗ đang dùng tên field khác
  int get kycStatus => status;
  String? get kycRejectReason => rejectReason;
}

enum KycStatus {
  notStarted,
  pending,
  approved,
  rejected,
  unknown,
}

// =============================================================================
// KYC UPLOAD SESSION MODEL
// Dùng cho: POST /kyc/init và POST /kyc/upload-batch
// DriverKycUploadSessionProgressDto
// =============================================================================

enum KycSessionStatus {
  inProgress,
  submitted,
  expired,
  unknown,
}

class KycBatchProgressModel {
  final String batchCode;
  final String label;
  final List<String> requiredSlots;
  final List<String> uploadedSlots;
  final bool isCompleted;

  KycBatchProgressModel({
    required this.batchCode,
    required this.label,
    required this.requiredSlots,
    required this.uploadedSlots,
    required this.isCompleted,
  });

  factory KycBatchProgressModel.fromJson(Map<String, dynamic> json) {
    return KycBatchProgressModel(
      batchCode: json["batchCode"]?.toString() ?? "",
      label: json["label"]?.toString() ?? "",
      requiredSlots: _parseStringList(json["requiredSlots"]),
      uploadedSlots: _parseStringList(json["uploadedSlots"]),
      isCompleted: json["isCompleted"] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    "batchCode": batchCode,
    "label": label,
    "requiredSlots": requiredSlots,
    "uploadedSlots": uploadedSlots,
    "isCompleted": isCompleted,
  };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  String get progressText => "${uploadedSlots.length}/${requiredSlots.length}";

  List<String> get missingSlots =>
      requiredSlots.where((s) => !uploadedSlots.contains(s)).toList();
}

class KycUploadSessionModel {
  final String uploadSessionId;
  final int status;
  final String statusText;
  final DateTime? expiresAt;
  final DateTime? lastUploadedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final int uploadedSlotCount;
  final int totalSlotCount;
  final bool canSubmit;
  final List<String> missingSlots;
  final List<KycBatchProgressModel> batches;

  KycUploadSessionModel({
    required this.uploadSessionId,
    required this.status,
    required this.statusText,
    required this.expiresAt,
    required this.lastUploadedAt,
    required this.submittedAt,
    required this.completedAt,
    required this.uploadedSlotCount,
    required this.totalSlotCount,
    required this.canSubmit,
    required this.missingSlots,
    required this.batches,
  });

  factory KycUploadSessionModel.fromRawJson(String str) {
    return KycUploadSessionModel.fromJson(jsonDecode(str));
  }

  String toRawJson() => jsonEncode(toJson());

  factory KycUploadSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    List<KycBatchProgressModel> parseBatches(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map((e) => KycBatchProgressModel.fromJson(e))
            .toList();
      }
      return [];
    }

    return KycUploadSessionModel(
      uploadSessionId: json["uploadSessionId"]?.toString() ?? "",
      status: (json["status"] as num?)?.toInt() ?? 0,
      statusText: json["statusText"]?.toString() ?? "",
      expiresAt: parseDate(json["expiresAt"]),
      lastUploadedAt: parseDate(json["lastUploadedAt"]),
      submittedAt: parseDate(json["submittedAt"]),
      completedAt: parseDate(json["completedAt"]),
      uploadedSlotCount: (json["uploadedSlotCount"] as num?)?.toInt() ?? 0,
      totalSlotCount: (json["totalSlotCount"] as num?)?.toInt() ?? 9,
      canSubmit: json["canSubmit"] == true,
      missingSlots: parseStringList(json["missingSlots"]),
      batches: parseBatches(json["batches"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "uploadSessionId": uploadSessionId,
    "status": status,
    "statusText": statusText,
    "expiresAt": expiresAt?.toIso8601String(),
    "lastUploadedAt": lastUploadedAt?.toIso8601String(),
    "submittedAt": submittedAt?.toIso8601String(),
    "completedAt": completedAt?.toIso8601String(),
    "uploadedSlotCount": uploadedSlotCount,
    "totalSlotCount": totalSlotCount,
    "canSubmit": canSubmit,
    "missingSlots": missingSlots,
    "batches": batches.map((b) => b.toJson()).toList(),
  };

  KycSessionStatus get sessionStatusEnum {
    switch (status) {
      case 0:
        return KycSessionStatus.inProgress;
      case 1:
        return KycSessionStatus.submitted;
      case 2:
        return KycSessionStatus.expired;
      default:
        return KycSessionStatus.unknown;
    }
  }

  bool get isExpired => sessionStatusEnum == KycSessionStatus.expired;
  bool get isSubmitted => sessionStatusEnum == KycSessionStatus.submitted;
  bool get isInProgress => sessionStatusEnum == KycSessionStatus.inProgress;

  bool get isActive => isInProgress && !isExpired;

  double get uploadProgress =>
      totalSlotCount > 0 ? uploadedSlotCount / totalSlotCount : 0.0;

  KycBatchProgressModel? getBatch(String batchCode) {
    try {
      return batches.firstWhere((b) => b.batchCode == batchCode);
    } catch (_) {
      return null;
    }
  }

  bool isBatchCompleted(String batchCode) =>
      getBatch(batchCode)?.isCompleted ?? false;
}