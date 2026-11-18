import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/active_session_mode.dart';
import '../services/startup_session_restore.dart';
import 'driver/driver_login_screen.dart';
import '../services/driver_session_navigation.dart';
import '../features/carrier_vehicle/carrier_vehicle_service.dart';
import '../features/carrier_vehicle/carrier_vehicle_screens.dart';
import '../services/kyc_service.dart';
import '../ui/ui.dart';

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

  bool _checkingAuth = false;
  bool _navigationStarted = false;
  String? _restoreError;

  Future<void> _checkAuth() async {
    if (_checkingAuth || _navigationStarted) return;
    _checkingAuth = true;
    if (mounted) setState(() => _restoreError = null);
    try {
      final restored = await StartupSessionRestore.restore();
      if (!mounted || _navigationStarted) return;
      if (restored?.mode == SessionMode.driver) {
        final prefs = await SharedPreferences.getInstance();
        await _saveOnboardingState(
          prefs: prefs,
          accessToken: restored!.driverToken!,
        );
      }
      await _ensureMinDisplay();
      if (!mounted || _navigationStarted) return;
      if (restored == null) {
        _goToLogin();
      } else if (restored.mode == SessionMode.driver) {
        _navigationStarted = true;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _navigationStarted = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: carrierRouteName),
            builder: (_) =>
                CarrierVehicleHomeScreen(initialRuns: restored.runs),
          ),
        );
      }
    } on TokenStorageException catch (error) {
      if (mounted && !_navigationStarted) {
        setState(() => _restoreError = error.toString());
      }
    } on CarrierVehicleException catch (error) {
      if (mounted && !_navigationStarted) {
        setState(() => _restoreError = error.message);
      }
    } catch (_) {
      if (mounted && !_navigationStarted) {
        setState(
          () => _restoreError =
              'Chưa thể khôi phục phiên. Kiểm tra kết nối rồi thử lại.',
        );
      }
    } finally {
      _checkingAuth = false;
    }
  }

  Future<void> _chooseDriverLogin() async {
    if (_navigationStarted) return;
    // Guard before awaiting preferences: a late startup response cannot redirect.
    _navigationStarted = true;
    await ActiveSessionMode.remember(SessionMode.driver);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _goToLogin() {
    if (!mounted || _navigationStarted) return;
    _navigationStarted = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => DriverLoginScreen(
          initialMessage: CarrierVehicleService.sessionEndMessage,
        ),
      ),
    );
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
                    colors: [Colors.transparent, const Color(0x33041565)],
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
                    if (_restoreError == null)
                      _ShimmerLoadingBar(animation: _shimmerAnimation),
                    if (_restoreError != null) ...[
                      Text(
                        _restoreError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Brand.ink),
                      ),
                      TextButton(
                        onPressed: _checkAuth,
                        child: const Text('Thử lại'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _restoreError == null
                          ? 'Đang tải...'
                          : 'Phiên đã lưu được giữ lại.',
                      style: TextStyle(
                        color: Brand.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextButton(
                      onPressed: _chooseDriverLogin,
                      child: const Text('Đăng nhập tài xế'),
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
            color: Brand.b50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(color: Colors.white),
                  FractionallySizedBox(
                    alignment: Alignment((animation.value * 3.0) - 1.5, 0),
                    widthFactor: 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Brand.inkMuted,
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
