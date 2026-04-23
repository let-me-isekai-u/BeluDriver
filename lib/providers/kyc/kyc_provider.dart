import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/KYC/kyc_model.dart';
import '../../services/kyc_service.dart';

class KycProvider extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // STATE - KYC Status (GET /kyc và submit response)
  // ---------------------------------------------------------------------------
  KycModel? _kyc;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ---------------------------------------------------------------------------
  // STATE - Upload Session (init + upload-batch)
  // ---------------------------------------------------------------------------
  KycUploadSessionModel? _uploadSession;
  bool _isInitializingSession = false;
  bool _isUploadingBatch = false;
  bool _isSubmitting = false;

  /// Theo dõi batch nào đang upload (để hiển thị loading đúng chỗ)
  String? _uploadingBatchCode;

  // ---------------------------------------------------------------------------
  // GETTERS - KYC Status
  // ---------------------------------------------------------------------------
  KycModel? get kyc => _kyc;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get hasData => _kyc != null;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get canSubmitKyc => _kyc?.canUploadKyc ?? false;
  bool get isPending => _kyc?.isPending ?? false;
  bool get isApproved => _kyc?.isApproved ?? false;
  bool get isRejected => _kyc?.isRejected ?? false;
  bool get isNotStarted => _kyc?.isNotStarted ?? false;

  int get kycStatus => (_kyc?.kycStatus as num?)?.toInt() ?? 0;
  String get kycStatusText => _kyc?.kycStatusText ?? '';
  String? get kycRejectReason => _kyc?.kycRejectReason;

  // ---------------------------------------------------------------------------
  // GETTERS - Upload Session
  // ---------------------------------------------------------------------------
  KycUploadSessionModel? get uploadSession => _uploadSession;
  bool get isInitializingSession => _isInitializingSession;
  bool get isUploadingBatch => _isUploadingBatch;
  String? get uploadingBatchCode => _uploadingBatchCode;
  bool get hasActiveSession => _uploadSession?.isActive ?? false;

  /// canSubmit từ session (đủ 9 slot) → dùng để enable nút "Gửi KYC"
  bool get sessionCanSubmit => _uploadSession?.canSubmit ?? false;

  /// Tiến độ upload: 0.0 → 1.0
  double get uploadProgress => _uploadSession?.uploadProgress ?? 0.0;

  /// Kiểm tra 1 batch đã hoàn thành chưa
  bool isBatchCompleted(String batchCode) =>
      _uploadSession?.isBatchCompleted(batchCode) ?? false;

  /// Lấy tiến độ của 1 batch
  KycBatchProgressModel? getBatch(String batchCode) =>
      _uploadSession?.getBatch(batchCode);

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSession() {
    _uploadSession = null;
    _uploadingBatchCode = null;
    notifyListeners();
  }

  Future<void> _setKycPendingReview(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kycPendingReview', value);
      debugPrint('[KYC_PROVIDER] kycPendingReview = $value');
    } catch (e) {
      debugPrint('[KYC_PROVIDER] set kycPendingReview error = $e');
    }
  }

  Future<void> clearKycPendingReview() async {
    await _setKycPendingReview(false);
  }

  // ---------------------------------------------------------------------------
  // GET KYC STATUS
  // GET /kyc
  // ---------------------------------------------------------------------------
  Future<bool> fetchKyc(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.getKYC(accessToken);

      debugPrint('[KYC_PROVIDER] fetchKyc statusCode = ${response.statusCode}');
      debugPrint('[KYC_PROVIDER] fetchKyc body = ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _kyc = KycModel.fromJson(data);
        _successMessage = null;
        return true;
      } else {
        _errorMessage =
            _extractMessage(response.body) ?? "Không thể lấy thông tin KYC.";
        return false;
      }
    } catch (e) {
      _errorMessage = "Lỗi khi tải thông tin KYC: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: INIT SESSION
  // POST /kyc/init
  // Gọi khi vào màn KYC. Nếu có session cũ còn hạn thì backend trả lại.
  // Client đọc batches từ response để biết batch nào đã xong.
  // ---------------------------------------------------------------------------
  Future<bool> initKycSession(String accessToken) async {
    debugPrint('[KYC_PROVIDER] initKycSession called');

    _isInitializingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.initKycSession(accessToken);

      debugPrint('[KYC_PROVIDER] initKycSession statusCode = ${response.statusCode}');
      debugPrint('[KYC_PROVIDER] initKycSession body = ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _uploadSession = KycUploadSessionModel.fromJson(data);
        await _setKycPendingReview(false);

        debugPrint('[KYC_PROVIDER] session id = ${_uploadSession?.uploadSessionId}');
        debugPrint('[KYC_PROVIDER] uploaded = ${_uploadSession?.uploadedSlotCount}/${_uploadSession?.totalSlotCount}');
        return true;
      } else if (response.statusCode == 423) {
        await _setKycPendingReview(true);
        _errorMessage =
            _extractMessage(response.body) ?? "KYC đang chờ duyệt, không thể gửi lại.";
        return false;
      } else {
        _errorMessage =
            _extractMessage(response.body) ?? "Không thể khởi tạo phiên KYC.";
        return false;
      }
    } catch (e) {
      _errorMessage = "Lỗi khi khởi tạo phiên KYC: $e";
      debugPrint('[KYC_PROVIDER] initKycSession exception = $e');
      return false;
    } finally {
      _isInitializingSession = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 2A: UPLOAD BATCH - vehicle_basic
  // Fields: vehicle_photo, portrait
  // ---------------------------------------------------------------------------
  Future<bool> uploadBatchVehicleBasic({
    required String accessToken,
    required File vehiclePhoto,
    required File portrait,
  }) async {
    return _uploadBatch(
      accessToken: accessToken,
      batchCode: 'vehicle_basic',
      files: {
        'vehicle_photo': vehiclePhoto,
        'portrait': portrait,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2B: UPLOAD BATCH - vehicle_docs
  // Fields: vehicle_registration, driver_license
  // ---------------------------------------------------------------------------
  Future<bool> uploadBatchVehicleDocs({
    required String accessToken,
    required File vehicleRegistration,
    required File driverLicense,
  }) async {
    return _uploadBatch(
      accessToken: accessToken,
      batchCode: 'vehicle_docs',
      files: {
        'vehicle_registration': vehicleRegistration,
        'driver_license': driverLicense,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2C: UPLOAD BATCH - identity_docs
  // Fields: citizen_front, citizen_back
  // ---------------------------------------------------------------------------
  Future<bool> uploadBatchIdentityDocs({
    required String accessToken,
    required File citizenFront,
    required File citizenBack,
  }) async {
    return _uploadBatch(
      accessToken: accessToken,
      batchCode: 'identity_docs',
      files: {
        'citizen_front': citizenFront,
        'citizen_back': citizenBack,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2D: UPLOAD BATCH - face_verification
  // Fields: face_front, face_right, face_left
  // ---------------------------------------------------------------------------
  Future<bool> uploadBatchFaceVerification({
    required String accessToken,
    required File faceFront,
    required File faceRight,
    required File faceLeft,
  }) async {
    return _uploadBatch(
      accessToken: accessToken,
      batchCode: 'face_verification',
      files: {
        'face_front': faceFront,
        'face_right': faceRight,
        'face_left': faceLeft,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // INTERNAL: _uploadBatch
  // ---------------------------------------------------------------------------
  Future<bool> _uploadBatch({
    required String accessToken,
    required String batchCode,
    required Map<String, File> files,
  }) async {
    final sessionId = _uploadSession?.uploadSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _errorMessage = "Chưa có phiên upload. Vui lòng thử lại.";
      notifyListeners();
      return false;
    }

    if (_uploadSession?.isExpired == true) {
      debugPrint('[KYC_PROVIDER] Session expired, re-initializing...');
      final reinited = await initKycSession(accessToken);
      if (!reinited) return false;
    }

    debugPrint('[KYC_PROVIDER] uploadBatch batchCode = $batchCode');
    debugPrint('[KYC_PROVIDER] uploadBatch files = ${files.keys.toList()}');

    _isUploadingBatch = true;
    _uploadingBatchCode = batchCode;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.uploadKycBatch(
        accessToken: accessToken,
        uploadSessionId: _uploadSession!.uploadSessionId,
        batchCode: batchCode,
        files: files,
      );

      debugPrint('[KYC_PROVIDER] uploadBatch statusCode = ${response.statusCode}');
      debugPrint('[KYC_PROVIDER] uploadBatch body = ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _uploadSession = KycUploadSessionModel.fromJson(data);
        debugPrint('[KYC_PROVIDER] batch $batchCode completed = ${_uploadSession?.isBatchCompleted(batchCode)}');
        debugPrint('[KYC_PROVIDER] canSubmit = ${_uploadSession?.canSubmit}');
        return true;
      } else {
        _errorMessage = _extractMessage(response.body) ??
            "Upload batch $batchCode thất bại.";
        return false;
      }
    } catch (e) {
      _errorMessage = "Lỗi khi upload batch $batchCode: $e";
      debugPrint('[KYC_PROVIDER] uploadBatch exception = $e');
      return false;
    } finally {
      _isUploadingBatch = false;
      _uploadingBatchCode = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 3: SUBMIT SESSION
  // ---------------------------------------------------------------------------
  Future<bool> submitKycSession(String accessToken) async {
    final sessionId = _uploadSession?.uploadSessionId;

    debugPrint('[KYC_PROVIDER] submitKycSession called');
    debugPrint('[KYC_PROVIDER] sessionId = $sessionId');
    debugPrint('[KYC_PROVIDER] canSubmit = ${_uploadSession?.canSubmit}');

    if (sessionId == null || sessionId.isEmpty) {
      _errorMessage = "Không tìm thấy phiên upload.";
      notifyListeners();
      return false;
    }

    if (_uploadSession?.canSubmit != true) {
      _errorMessage = "Chưa upload đủ ảnh. Vui lòng kiểm tra lại.";
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.submitKycSession(
        accessToken: accessToken,
        uploadSessionId: sessionId,
      );

      debugPrint('[KYC_PROVIDER] submitKycSession statusCode = ${response.statusCode}');
      debugPrint('[KYC_PROVIDER] submitKycSession body = ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _kyc = KycModel.fromJson(data);
        _successMessage = "Gửi KYC thành công.";
        _uploadSession = null;
        await _setKycPendingReview(true);
        debugPrint('[KYC_PROVIDER] submitKycSession success, kycStatus = ${_kyc?.kycStatusText}');
        return true;
      } else {
        _errorMessage =
            _extractMessage(response.body) ?? "Gửi KYC thất bại.";
        return false;
      }
    } catch (e) {
      _errorMessage = "Lỗi khi gửi KYC: $e";
      debugPrint('[KYC_PROVIDER] submitKycSession exception = $e');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @Deprecated('Dùng initKycSession + uploadBatchXxx + submitKycSession thay thế')
  Future<bool> submitKyc({
    required String accessToken,
    File? vehiclePhoto,
    File? citizenFront,
    File? citizenBack,
    File? vehicleRegistration,
    File? driverLicense,
    File? portrait,
    File? faceFront,
    File? faceRight,
    File? faceLeft,
  }) async {
    debugPrint('[KYC_PROVIDER] submitKyc (legacy) called');

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // ignore: deprecated_member_use
      final response = await KYCService.submitKYC(
        accessToken: accessToken,
        vehiclePhoto: vehiclePhoto,
        citizenFront: citizenFront,
        citizenBack: citizenBack,
        vehicleRegistration: vehicleRegistration,
        driverLicense: driverLicense,
        portrait: portrait,
        faceFront: faceFront,
        faceRight: faceRight,
        faceLeft: faceLeft,
      );

      debugPrint('[KYC_PROVIDER] legacy statusCode = ${response.statusCode}');
      debugPrint('[KYC_PROVIDER] legacy body = ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _kyc = KycModel.fromJson(data);
        _successMessage = "Gửi KYC thành công.";
        await _setKycPendingReview(true);
        return true;
      } else {
        _errorMessage = _extractMessage(response.body) ?? "Gửi KYC thất bại.";
        return false;
      }
    } catch (e) {
      _errorMessage = "Lỗi khi gửi KYC: $e";
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER
  // ---------------------------------------------------------------------------
  String? _extractMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        if (data["message"] != null) return data["message"].toString();
        if (data["title"] != null) return data["title"].toString();
        if (data["error"] != null) return data["error"].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}