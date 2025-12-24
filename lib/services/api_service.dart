///Tài liệu cho file api này:
///https://docs.google.com/document/d/1MD5Tx42I-CpFgTNwrrwUhB8FsdQFhiiqAN_Xy0kUfAc/edit?tab=t.d9q2g56xpd8j
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static dynamic safeDecode(String? body) {
    if (body == null || body.isEmpty) return {};

    try {
      return jsonDecode(body);
    } catch (e) {
      print("⚠️ safeDecode() JSON lỗi: $e");
      print("⚠️ raw body: $body");
      return {};
    }
  }

  // -----------------------------------------------------------
  // BASE URL CHUẨN
  // -----------------------------------------------------------
  static const String _baseUrl =
      "https://belucar.belugaexpress.com/api/accountdriverapi";

  // Default headers
  static Map<String, String> _defaultHeaders() => {
    "Accept": "application/json",
    "Content-Type": "application/json",
  };

  // Auth headers
  static Map<String, String> _authHeaders(String accessToken) => {
    "Accept": "application/json",
    "Authorization": "Bearer $accessToken",
  };

  // Lỗi fallback
  static http.Response _errorResponse(Object e) {
    final body = jsonEncode({
      "success": false,
      "message": "Lỗi kết nối tới server: $e",
    });
    return http.Response(body, 500,
        headers: {"Content-Type": "application/json"});
  }

  // -----------------------------------------------------------
  // 1️⃣ LOGIN
  // -----------------------------------------------------------
  static Future<http.Response> driverLogin({
    required String phone,
    required String password,
    required String deviceToken,
  }) async {
    final url = Uri.parse("$_baseUrl/driver/login");

    try {
      final body = jsonEncode({
        "phone": phone,
        "password": password,
        "deviceToken": deviceToken,
      });

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 2️⃣ LOGOUT
  // -----------------------------------------------------------
  static Future<http.Response> Driverlogout(String accessToken) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/logout");

    try {
      return await http
          .post(url, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 3️⃣ ĐĂNG KÝ (FORM-DATA + FILE)
  // -----------------------------------------------------------
  static Future<http.Response> driverRegister({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required licenseNumber,
    required String avatarFilePath, // Giữ nguyên type, logic xử lý bên dưới
  }) async {
    final url = Uri.parse("$_baseUrl/driver-register");

    try {
      final request = http.MultipartRequest("POST", url);

      request.fields["fullName"] = fullName;
      request.fields["phone"] = phone;
      request.fields["email"] = email;
      request.fields["password"] = password;
      request.fields["licenseNumber"] = licenseNumber;

      // Chỉ đính kèm file nếu đường dẫn không rỗng
      if (avatarFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath("avatar", avatarFilePath),
        );
      }
      // ------------------------------------------------------------------

      final resStream = await request.send();
      return await http.Response.fromStream(resStream);
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 4️⃣ REFRESH TOKEN
  // -----------------------------------------------------------
  static Future<http.Response> refreshToken({
    required String refreshToken,
  }) async {
    final url = Uri.parse("$_baseUrl/refresh-token");

    try {
      final body = jsonEncode({"refreshToken": refreshToken});

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 5️⃣ UPDATE PROFILE (PUT – FORM-DATA)
  // -----------------------------------------------------------
  static Future<http.Response> updateProfile({
    required String accessToken,
    required String fullName,
    required String email,
    required String licenseNumber,
    String? avatarFilePath, // optional
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/driver-update-profile");

    try {
      final request = http.MultipartRequest("PUT", url);

      request.headers["Authorization"] = "Bearer $accessToken";
      request.headers["Accept"] = "application/json";

      request.fields["fullName"] = fullName;
      request.fields["email"] = email;
      request.fields["licenseNumber"] = licenseNumber;

      if (avatarFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath("avatar", avatarFilePath),
        );
      }

      final responseStream = await request.send();
      return await http.Response.fromStream(responseStream);
    } catch (e) {
      return _errorResponse(e);
    }
  }

  //Gửi OTP khi quên mật khẩu
  static Future<http.Response> sendForgotPasswordOtp({
    required String email,
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/forgot-password");

    try {
      final body = jsonEncode({"email": email});

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  //Nhập mật khẩu mới khi quên
  static Future<http.Response> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/reset-password");

    try {
      final body =
      jsonEncode({"email": email, "otp": otp, "newPassword": newPassword});

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  //Lấy profile tài xế
  static Future<http.Response> getDriverProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse("$_baseUrl/profile");

    try {
      return await http
          .get(url, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // Đổi mật khẩu
  static Future<http.Response> changePassword({
    required String accessToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/change-password");

    print("🔵 [API] CALL CHANGE PASSWORD → $url");
    print("📌 oldPassword: $oldPassword");
    print("📌 newPassword: $newPassword");

    try {
      final body = jsonEncode({
        "oldPassword": oldPassword,
        "newPassword": newPassword,
      });

      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] Status: ${res.statusCode}");
      print("📥 [API] Body: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] ERROR CHANGE PASSWORD: $e");
      return _errorResponse(e);
    }
  }

  //Xoá tài khoản
  static Future<http.Response> deleteAccount({
    required String accessToken,
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountdriverapi/delete");

    print("🔵 [API] CALL DELETE ACCOUNT → $url");

    try {
      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 30));

      print("📥 [API] Status: ${res.statusCode}");
      print("📥 [API] Body: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] ERROR DELETE ACCOUNT: $e");
      return _errorResponse(e);
    }
  }

  //Nạp tiền vào ví tài xế
  static Future<http.Response> depositWallet({
    required String accessToken,
    required double amount,
    required String content,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/paymentapi/deposite",
    );

    print("🔵 [API] DEPOSIT WALLET → $url");
    print("➡️ amount: $amount | content: $content");

    try {
      final body = jsonEncode({
        "amount": amount,
        "content": content,
      });

      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] DEPOSIT ERROR: $e");
      return _errorResponse(e);
    }
  }

  //lấy danh sách đơn chưa có tài xế nhận
  static Future<http.Response> getWaitingRides({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/rideapi/waiting",
    );

    print("🔵 [API] GET WAITING RIDES → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] GET WAITING RIDES ERROR: $e");
      return _errorResponse(e);
    }
  }

  //lấy danh sách chuyến xe mà tài xế đang dùng app đã nhận
  static Future<http.Response> getAcceptedRides({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/ride-confirmed",
    );

    print("🔵 [API] GET WAITING RIDES → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] GET ACCEPTED RIDES ERROR: $e");
      return _errorResponse(e);
    }
  }

  //xác nhận đơn của tài xế POST
  static Future<http.Response> acceptRide({
    required String accessToken,
    required int id, // id của đơn trạng thái 1
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/rideapi/accept/$id",
    );

    print("🔵 [API] ACCEPT RIDE → $url");

    try {
      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] ACCEPT RIDE ERROR: $e");
      return _errorResponse(e);
    }
  }


  //lịch sử thay đổi số dư ví của tài xế GET
  static Future<http.Response> getWalletHistory({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/paymentapi/history",
    );

    print("🔵 [API] WALLET HISTORY → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] WALLET HISTORY ERROR: $e");
      return _errorResponse(e);
    }
  }

  //lấy tỉnh để lọc đơn
  static Future<List<dynamic>> getProvinces() async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/provinceapi/active",
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        }
      }

      print("⚠️ getProvinces(): Unexpected response ${response.statusCode}");
      return [];
    } catch (e) {
      print("🔥 getProvinces() ERROR: $e");
      return [];
    }
  }


//Lấy chi tiết chuyến xe
  static Future<http.Response> getRideDetail({
    required String accessToken,
    required int rideId,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/ride-detail/$rideId",
    );

    // 🔍 LOG TRƯỚC KHI CALL API
    print("══════════════════════════════════════");
    print("🚀 [API] GET RIDE DETAIL");
    print("➡️ URL: $url");
    print("➡️ rideId: $rideId");
    print("➡️ Token: ${accessToken.isNotEmpty ? "OK" : "EMPTY"}");
    print("══════════════════════════════════════");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      // 📥 LOG RESPONSE
      print("📥 [API] RESPONSE STATUS: ${res.statusCode}");
      print("📥 [API] RESPONSE BODY:");
      print(res.body);
      print("══════════════════════════════════════");

      return res;
    } catch (e) {
      print("❌ [API] GET RIDE DETAIL ERROR: $e");
      print("══════════════════════════════════════");
      return _errorResponse(e);
    }
  }


  // Bắt đầu chuyến đi
  static Future<http.Response> startRide({
    required String accessToken,
    required int rideId,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/start/$rideId",
    );

    print("🔵 [API] START RIDE → $url");

    try {
      final res = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] START RIDE ERROR: $e");
      return _errorResponse(e);
    }
  }

  // Hoàn thành chuyến đi
  static Future<http.Response> completeRide({
    required String accessToken,
    required int rideId,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/complete/$rideId",
    );

    print("🔵 [API] COMPLETE RIDE → $url");

    try {
      final res = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] COMPLETE RIDE ERROR: $e");
      return _errorResponse(e);
    }
  }

  // Lấy danh sách chuyến đang đi (status = 3)
  static Future<http.Response> getProcessingRides({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/ride-process",
    );

    print("🔵 [API] GET PROCESSING RIDES → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] GET PROCESSING RIDES ERROR: $e");
      return _errorResponse(e);
    }
  }


  // Lấy lịch sử chuyến xe (status = 4, 5)
  static Future<http.Response> getRideHistory({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/driverapi/ride-history",
    );

    print("🔵 [API] GET RIDE HISTORY → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] GET RIDE HISTORY ERROR: $e");
      return _errorResponse(e);
    }
  }

  //tạo yêu cầu rút tiền
  static Future<http.Response> createWithdrawal({
    required String accessToken,
    required int amount,
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,

  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/withdrawalapi/create",
    );

    return http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode({
        "amount": amount,
        "bankCode": bankCode,
        "bankName": bankName,
        "accountNumber": accountNumber,
        "accountName": accountName,
      }),
    );
  }

  // Lấy danh sách yêu cầu rút tiền của tài xế
  static Future<http.Response> getWithdrawalHistory({
    required String accessToken,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/withdrawalapi/history-withdrawal",
    );

    try {
      return await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      return _errorResponse(e);
    }
  }

//Lấy danh sách ngân hàng
  static Future<http.Response> getBanks() async {
    final url = Uri.parse("https://api.vietqr.io/v2/banks");
    try {
      return await http.get(url, headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      }).timeout(const Duration(seconds: 30));
    } catch (e) {
      return _errorResponse(e);
    }
  }

}
