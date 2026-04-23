import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class KYCService {
  // -----------------------------------------------------------
  // BASE URL
  // -----------------------------------------------------------
  static const String _baseUrl = "https://xeghepdongduong.com/api/accountdriverapi";

  // -----------------------------------------------------------
  // HEADERS
  // -----------------------------------------------------------
  static Map<String, String> _authHeaders(String accessToken) => {
    "Accept": "application/json",
    "Authorization": "Bearer $accessToken",
  };

  static Map<String, String> _jsonAuthHeaders(String accessToken) => {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Authorization": "Bearer $accessToken",
  };

  // -----------------------------------------------------------
  // ERROR HANDLER
  // -----------------------------------------------------------
  static http.Response _errorResponse(Object e) {
    final body = jsonEncode({
      "success": false,
      "message": "Lỗi kết nối tới server: $e",
    });

    debugPrint('[KYC_SERVICE] _errorResponse: $body');

    return http.Response(
      body,
      500,
      headers: {"Content-Type": "application/json"},
    );
  }

  // -----------------------------------------------------------
  // GET KYC
  // -----------------------------------------------------------
  static Future<http.Response> getKYC(String accessToken) async {
    try {
      final uri = Uri.parse("$_baseUrl/kyc");
      debugPrint('[KYC_SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: _authHeaders(accessToken),
      );

      debugPrint('[KYC_SERVICE] GET statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] GET body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] GET exception = $e');
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // NEW BATCH FLOW - STEP 1: INIT SESSION
  // POST /kyc/init
  // Tạo session mới hoặc trả lại session đang upload nếu còn hạn.
  // Response: DriverKycUploadSessionProgressDto với uploadSessionId và tiến độ.
  // -----------------------------------------------------------
  static Future<http.Response> initKycSession(String accessToken) async {
    try {
      final uri = Uri.parse("$_baseUrl/kyc/init");
      debugPrint('[KYC_SERVICE] POST $uri');

      final response = await http.post(
        uri,
        headers: _jsonAuthHeaders(accessToken),
      );

      debugPrint('[KYC_SERVICE] initKycSession statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] initKycSession body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] initKycSession exception = $e');
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // NEW BATCH FLOW - STEP 2: UPLOAD BATCH
  // POST /kyc/upload-batch
  // Content-Type: multipart/form-data
  //
  // Gọi riêng cho từng batch. Mỗi lần chỉ gửi đúng 1 batch.
  // batchCode phải là một trong: vehicle_basic | vehicle_docs | identity_docs | face_verification
  //
  // Batch vehicle_basic  → files: vehicle_photo, portrait
  // Batch vehicle_docs   → files: vehicle_registration, driver_license
  // Batch identity_docs  → files: citizen_front, citizen_back
  // Batch face_verification → files: face_front, face_right, face_left
  //
  // Nếu muốn upload lại 1 batch, gọi lại hàm này với đủ file của batch đó.
  // Response: DriverKycUploadSessionProgressDto (giống init).
  // -----------------------------------------------------------
  static Future<http.Response> uploadKycBatch({
    required String accessToken,
    required String uploadSessionId,
    required String batchCode,
    required Map<String, File> files,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/kyc/upload-batch");
      debugPrint('[KYC_SERVICE] POST $uri');
      debugPrint('[KYC_SERVICE] uploadSessionId = $uploadSessionId');
      debugPrint('[KYC_SERVICE] batchCode = $batchCode');
      debugPrint('[KYC_SERVICE] files keys = ${files.keys.toList()}');

      final request = http.MultipartRequest("POST", uri);

      request.headers.addAll({
        "Authorization": "Bearer $accessToken",
        "Accept": "application/json",
      });

      // Required text fields
      request.fields['uploadSessionId'] = uploadSessionId;
      request.fields['batchCode'] = batchCode;

      // Attach files for this batch
      for (final entry in files.entries) {
        final fieldName = entry.key;
        final file = entry.value;
        debugPrint('[KYC_SERVICE] attach $fieldName = ${file.path}');
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, file.path),
        );
      }

      debugPrint('[KYC_SERVICE] total attached files = ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[KYC_SERVICE] uploadKycBatch statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] uploadKycBatch body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] uploadKycBatch exception = $e');
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // Convenience wrappers cho từng batch cụ thể
  // (Tùy chọn - giúp caller không cần nhớ tên field)
  // -----------------------------------------------------------

  /// Batch 1: vehicle_basic
  /// Bắt buộc: vehicle_photo, portrait
  static Future<http.Response> uploadBatchVehicleBasic({
    required String accessToken,
    required String uploadSessionId,
    required File vehiclePhoto,
    required File portrait,
  }) {
    return uploadKycBatch(
      accessToken: accessToken,
      uploadSessionId: uploadSessionId,
      batchCode: 'vehicle_basic',
      files: {
        'vehicle_photo': vehiclePhoto,
        'portrait': portrait,
      },
    );
  }

  /// Batch 2: vehicle_docs
  /// Bắt buộc: vehicle_registration, driver_license
  static Future<http.Response> uploadBatchVehicleDocs({
    required String accessToken,
    required String uploadSessionId,
    required File vehicleRegistration,
    required File driverLicense,
  }) {
    return uploadKycBatch(
      accessToken: accessToken,
      uploadSessionId: uploadSessionId,
      batchCode: 'vehicle_docs',
      files: {
        'vehicle_registration': vehicleRegistration,
        'driver_license': driverLicense,
      },
    );
  }

  /// Batch 3: identity_docs
  /// Bắt buộc: citizen_front, citizen_back
  static Future<http.Response> uploadBatchIdentityDocs({
    required String accessToken,
    required String uploadSessionId,
    required File citizenFront,
    required File citizenBack,
  }) {
    return uploadKycBatch(
      accessToken: accessToken,
      uploadSessionId: uploadSessionId,
      batchCode: 'identity_docs',
      files: {
        'citizen_front': citizenFront,
        'citizen_back': citizenBack,
      },
    );
  }

  /// Batch 4: face_verification
  /// Bắt buộc: face_front, face_right, face_left
  static Future<http.Response> uploadBatchFaceVerification({
    required String accessToken,
    required String uploadSessionId,
    required File faceFront,
    required File faceRight,
    required File faceLeft,
  }) {
    return uploadKycBatch(
      accessToken: accessToken,
      uploadSessionId: uploadSessionId,
      batchCode: 'face_verification',
      files: {
        'face_front': faceFront,
        'face_right': faceRight,
        'face_left': faceLeft,
      },
    );
  }

  // -----------------------------------------------------------
  // NEW BATCH FLOW - STEP 3: SUBMIT SESSION
  // POST /kyc/submit
  // Content-Type: application/json
  //
  // Chỉ gọi khi canSubmit = true từ response upload-batch hoặc init.
  // Sau khi submit: KYC chuyển sang Pending, session bị đóng,
  // file temp bị xóa, không upload thêm vào session cũ được nữa.
  // -----------------------------------------------------------
  static Future<http.Response> submitKycSession({
    required String accessToken,
    required String uploadSessionId,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/kyc/submit");
      final body = jsonEncode({
        "uploadSessionId": uploadSessionId,
      });

      debugPrint('[KYC_SERVICE] POST $uri');
      debugPrint('[KYC_SERVICE] submitKycSession body = $body');

      final response = await http.post(
        uri,
        headers: _jsonAuthHeaders(accessToken),
        body: body,
      );

      debugPrint('[KYC_SERVICE] submitKycSession statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] submitKycSession body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] submitKycSession exception = $e');
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // LEGACY API (giữ lại để backward compatibility)
  // POST /kyc - gửi 9 file trong 1 request
  // Không dùng cho mobile app mới, chỉ giữ để tương thích cũ.
  // -----------------------------------------------------------
  @Deprecated('Dùng initKycSession + uploadKycBatch + submitKycSession thay thế')
  static Future<http.Response> submitKYC({
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
    try {
      final uri = Uri.parse("$_baseUrl/kyc");
      debugPrint('[KYC_SERVICE] POST (legacy) $uri');

      final request = http.MultipartRequest("POST", uri);

      request.headers.addAll({
        "Authorization": "Bearer $accessToken",
        "Accept": "application/json",
      });

      Future<void> addFile(String field, File? file) async {
        if (file != null) {
          debugPrint('[KYC_SERVICE] attach $field = ${file.path}');
          request.files.add(
            await http.MultipartFile.fromPath(field, file.path),
          );
        } else {
          debugPrint('[KYC_SERVICE] skip $field = null');
        }
      }

      await addFile("VehiclePhoto", vehiclePhoto);
      await addFile("CitizenFront", citizenFront);
      await addFile("CitizenBack", citizenBack);
      await addFile("VehicleRegistration", vehicleRegistration);
      await addFile("DriverLicense", driverLicense);
      await addFile("Portrait", portrait);
      await addFile("FaceFront", faceFront);
      await addFile("FaceRight", faceRight);
      await addFile("FaceLeft", faceLeft);

      debugPrint('[KYC_SERVICE] total attached files = ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[KYC_SERVICE] POST (legacy) statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] POST (legacy) body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] POST (legacy) exception = $e');
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // ROUTE REGISTRATION (xảy ra trước khi làm KYC)
  // -----------------------------------------------------------

  /// GET /route-options
  static Future<http.Response> getRouteOptions(String accessToken) async {
    try {
      final uri = Uri.parse("$_baseUrl/route-options");
      debugPrint('[KYC_SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: _authHeaders(accessToken),
      );

      debugPrint('[KYC_SERVICE] GET route-options statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] GET route-options body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] GET route-options exception = $e');
      return _errorResponse(e);
    }
  }

  /// GET /routes
  static Future<http.Response> getRoutes(String accessToken) async {
    try {
      final uri = Uri.parse("$_baseUrl/routes");
      debugPrint('[KYC_SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: _authHeaders(accessToken),
      );

      debugPrint('[KYC_SERVICE] GET routes statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] GET routes body = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] GET routes exception = $e');
      return _errorResponse(e);
    }
  }

  /// PUT /routes
  /// Thay thế toàn bộ danh sách tỉnh hiện tại.
  /// provinceIds: tối đa 3 phần tử, [] để xóa hết.
  static Future<http.Response> updateRoutes({
    required String accessToken,
    required List<int> provinceIds,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/routes");
      final body = jsonEncode({
        "provinceIds": provinceIds,
      });

      debugPrint('[KYC_SERVICE] PUT $uri');
      debugPrint('[KYC_SERVICE] PUT routes body = $body');

      final response = await http.put(
        uri,
        headers: _jsonAuthHeaders(accessToken),
        body: body,
      );

      debugPrint('[KYC_SERVICE] PUT routes statusCode = ${response.statusCode}');
      debugPrint('[KYC_SERVICE] PUT routes response = ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[KYC_SERVICE] PUT routes exception = $e');
      return _errorResponse(e);
    }
  }
}