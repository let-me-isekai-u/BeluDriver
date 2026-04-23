import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/kyc_service.dart';

void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  static const Duration _minDisplayDuration = Duration(seconds: 3);
  late final DateTime _splashStart;

  @override
  void initState() {
    super.initState();
    appLog('SPLASH', 'initState called. Setting up animations.');
    _splashStart = DateTime.now();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    _checkAuth();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _ensureMinDisplay() async {
    final elapsed = DateTime.now().difference(_splashStart);
    if (elapsed < _minDisplayDuration) {
      await Future.delayed(_minDisplayDuration - elapsed);
    }
  }

  Future<void> _saveOnboardingState({
    required SharedPreferences prefs,
    required String accessToken,
  }) async {
    final onboarding = await ApiService.getOnboardingStatus(accessToken);

    if (onboarding == null) {
      appLog('ONBOARDING', 'getOnboardingStatus returned null');
      return;
    }

    final int kycStatus = onboarding.kycStatus;
    final String kycStatusText = onboarding.kycStatusText;
    final String kycRejectReason = onboarding.kycRejectReason ?? '';
    final String nextStep = onboarding.nextStep;
    final bool hasRegisteredRoute = onboarding.hasRegisteredRoute;
    final int selectedProvinceCount = onboarding.selectedProvinceCount;
    final bool canReceiveRide = onboarding.canReceiveRide;

    final bool shouldShowRegisterRoutePopup =
        nextStep == 'select_route' || nextStep == 'register_route';

    final bool shouldShowKycPopup =
        nextStep == 'submit_kyc' || nextStep == 'resubmit_kyc';

    final bool kycPendingReview =
        nextStep == 'waiting_kyc_approval' || kycStatus == 1;

    appLog('ONBOARDING', 'hasRegisteredRoute = $hasRegisteredRoute');
    appLog('ONBOARDING', 'selectedProvinceCount = $selectedProvinceCount');
    appLog('ONBOARDING', 'kycStatus = $kycStatus');
    appLog('ONBOARDING', 'kycStatusText = $kycStatusText');
    appLog('ONBOARDING', 'kycRejectReason = $kycRejectReason');
    appLog('ONBOARDING', 'canReceiveRide = $canReceiveRide');
    appLog('ONBOARDING', 'nextStep = $nextStep');
    appLog(
      'ONBOARDING',
      'shouldShowRegisterRoutePopup = $shouldShowRegisterRoutePopup',
    );
    appLog('ONBOARDING', 'shouldShowKycPopup = $shouldShowKycPopup');
    appLog('ONBOARDING', 'kycPendingReview = $kycPendingReview');

    await prefs.setInt("loginKycStatus", kycStatus);
    await prefs.setString("loginKycStatusText", kycStatusText);
    await prefs.setString("loginKycRejectReason", kycRejectReason);
    await prefs.setString("loginNextStep", nextStep);
    await prefs.setBool("loginHasRegisteredRoute", hasRegisteredRoute);
    await prefs.setInt("loginSelectedProvinceCount", selectedProvinceCount);
    await prefs.setBool("loginCanReceiveRide", canReceiveRide);

    await prefs.setBool(
      "shouldShowRegisterRoutePopup",
      shouldShowRegisterRoutePopup,
    );
    await prefs.setBool("shouldShowKycPopup", shouldShowKycPopup);
    await prefs.setBool("kycPendingReview", kycPendingReview);

    await prefs.remove("cachedKycJson");

    if (nextStep == 'resubmit_kyc' || kycStatus == 3) {
      try {
        final kycRes = await KYCService.getKYC(accessToken);
        appLog('KYC', 'preload GET /kyc statusCode = ${kycRes.statusCode}');
        appLog('KYC', 'preload GET /kyc body = ${kycRes.body}');

        if (kycRes.statusCode >= 200 && kycRes.statusCode < 300) {
          await prefs.setString("cachedKycJson", kycRes.body);
          appLog('KYC', 'cachedKycJson saved');
        }
      } catch (e) {
        appLog('KYC', 'Preload rejected KYC failed: $e');
      }
    }
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken");
    final refreshToken = prefs.getString("refreshToken");

    appLog('AUTH', '--- Starting Token Check ---');
    appLog('AUTH', 'Access Token Exists: ${accessToken != null}');
    appLog('AUTH', 'Refresh Token Exists: ${refreshToken != null}');

    await Future.delayed(const Duration(milliseconds: 1500));

    if (accessToken != null) {
      appLog('AUTH', 'Found Access Token -> Verifying...');

      try {
        final res = await ApiService.getDriverProfile(accessToken: accessToken);

        if (res.statusCode == 200) {
          await _saveOnboardingState(
            prefs: prefs,
            accessToken: accessToken,
          );

          appLog('AUTH', 'Access Token VALID -> Go to Home.');
          await _ensureMinDisplay();
          _goToHome();
          return;
        }

        if (res.statusCode == 401) {
          appLog('AUTH', 'Access Token EXPIRED -> Try Refresh.');
          await prefs.remove("accessToken");
        }
      } catch (e) {
        appLog('AUTH', 'Verify token ERROR: $e');
        await prefs.remove("accessToken");
      }
    }

    if (refreshToken == null) {
      appLog('AUTH', 'No tokens found -> Go to Login.');
      await _ensureMinDisplay();
      _goToLogin();
      return;
    }

    appLog('AUTH', 'Access Token missing, attempting Refresh Token...');

    try {
      final res = await ApiService.refreshToken(refreshToken: refreshToken);
      appLog('AUTH', 'Refresh API Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final newAccessToken = data["accessToken"];
        final newRefreshToken = data["refreshToken"];

        if (newAccessToken != null && newRefreshToken != null) {
          await prefs.setString("accessToken", newAccessToken);
          await prefs.setString("refreshToken", newRefreshToken);

          try {
            final profileRes = await ApiService.getDriverProfile(
              accessToken: newAccessToken,
            );

            if (profileRes.statusCode == 200) {
              await _saveOnboardingState(
                prefs: prefs,
                accessToken: newAccessToken,
              );
            }
          } catch (e) {
            appLog('AUTH', 'Get profile after refresh ERROR: $e');
          }

          appLog(
            'AUTH',
            'Refresh SUCCESS -> New tokens saved -> Go to Home.',
          );
          await _ensureMinDisplay();
          _goToHome();
          return;
        } else {
          appLog(
            'AUTH',
            'Refresh 200 but missing new tokens in body. Clearing tokens -> Go to Login.',
          );
          await _goToLoginAndClear(prefs);
          return;
        }
      } else {
        String message = "Unknown Error";
        try {
          final errorBody = jsonDecode(res.body);
          message = errorBody["message"] ?? message;
        } catch (_) {}
        appLog(
          'AUTH',
          'Refresh FAILED (${res.statusCode}): $message. Clearing tokens -> Go to Login.',
        );
        await _goToLoginAndClear(prefs);
      }
    } catch (e) {
      appLog(
        'AUTH',
        'Refresh ERROR (Network/Parsing): $e. Clearing tokens -> Go to Login.',
      );
      await _goToLoginAndClear(prefs);
    }
  }

  Future<void> _goToLoginAndClear(SharedPreferences prefs) async {
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    await prefs.remove("shouldShowRegisterRoutePopup");
    await prefs.remove("shouldShowKycPopup");
    await prefs.remove("cachedKycJson");
    await prefs.remove("kycPendingReview");
    await prefs.remove("loginKycStatus");
    await prefs.remove("loginKycStatusText");
    await prefs.remove("loginKycRejectReason");
    await prefs.remove("loginNextStep");
    await prefs.remove("loginHasRegisteredRoute");
    await prefs.remove("loginSelectedProvinceCount");
    await prefs.remove("loginCanReceiveRide");
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/home");
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF4AB8E8),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'lib/assets/summer_splash.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShimmerLoadingBar(animation: _shimmerAnimation),
                    const SizedBox(height: 10),
                    Text(
                      'Đang tải...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLoadingBar extends StatelessWidget {
  final Animation<double> animation;

  const _ShimmerLoadingBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    color: Colors.white.withOpacity(0.25),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment(
                      (animation.value * 3.0) - 1.5,
                      0,
                    ),
                    widthFactor: 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}