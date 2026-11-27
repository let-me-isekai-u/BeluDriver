import 'dart:async';

import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/active_session_mode.dart';
import '../services/startup_session_restore.dart';
import 'driver/driver_login_screen.dart';
import '../services/driver_session_navigation.dart';
import '../features/carrier_vehicle/carrier_vehicle_service.dart';
import '../features/carrier_vehicle/carrier_vehicle_screens.dart';
import '../services/kyc_service.dart';
import '../services/firebase_notification_service.dart';

void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _video;
  Timer? _watchdog;
  bool _introDone = false;
  bool _videoFailed = false;
  bool _authDone = false;
  RestoredAppSession? _restoredSession;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset(
      'assets/videos/intro_splash.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video.addListener(_onVideo);
    _watchdog = Timer(const Duration(seconds: 20), _failVideo);
    unawaited(_startVideo());
    unawaited(_checkAuth());
    // Notification permissions must not gate playback or session validation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        FirebaseNotificationService.init().catchError((Object error) {
          debugPrint(
            'Notification initialization unavailable: ${error.runtimeType}',
          );
        }),
      );
    });
  }

  Future<void> _startVideo() async {
    try {
      await _video.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || _videoFailed) return;
      await _video.setVolume(0);
      await _video.setLooping(false);
      // The asset ends at the Dong Duong logo, before the next scene.
      await _video.setPlaybackSpeed(1.5);
      if (!mounted || _videoFailed) return;
      setState(() {});
      await _video.play();
      if (!mounted || _introDone) return;
      _watchdog?.cancel();
      // Handles a decoder that stalls without reporting an error.
      _watchdog = Timer(
        _video.value.duration + const Duration(seconds: 8),
        _failVideo,
      );
    } catch (_) {
      _failVideo();
    }
  }

  void _onVideo() {
    if (!mounted || _introDone) return;
    final value = _video.value;
    if (value.hasError) {
      _failVideo();
    } else if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _watchdog?.cancel();
      setState(() => _introDone = true);
      _navigateIfReady();
    }
  }

  void _failVideo() {
    if (!mounted || _introDone) return;
    _watchdog?.cancel();
    unawaited(_video.pause().catchError((Object _) {}));
    setState(() {
      _videoFailed = true;
      _introDone = true;
    });
    _navigateIfReady();
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
    if (mounted) {
      setState(() {
        _restoreError = null;
        _authDone = false;
      });
    }
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
      if (!mounted || _navigationStarted) return;
      setState(() {
        _restoredSession = restored;
        _authDone = true;
      });
      _navigateIfReady();
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

  void _navigateIfReady() {
    if (!mounted || !_introDone || !_authDone || _navigationStarted) return;
    final restored = _restoredSession;
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
          builder: (_) => CarrierVehicleHomeScreen(initialRuns: restored.runs),
        ),
      );
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
  void dispose() {
    _watchdog?.cancel();
    _video.removeListener(_onVideo);
    unawaited(_video.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFECEDE8),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFECEDE8),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: !_videoFailed && _video.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _video.value.size.width,
                              height: _video.value.size.height,
                              child: VideoPlayer(_video),
                            ),
                          ),
                        )
                      // Match the native launch screen and the video's first
                      // frame while loading or if playback is unavailable.
                      : const SizedBox.expand(),
                ),
              ),
              // Reserve space: loading never overlays any part of the video.
              if (_introDone && _restoreError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_restoreError!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _checkAuth,
                        child: const Text('Thử lại'),
                      ),
                      const Text('Phiên đã lưu được giữ lại.'),
                      TextButton(
                        onPressed: _chooseDriverLogin,
                        child: const Text('Đăng nhập tài xế'),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 28,
                child: _introDone && !_authDone && _restoreError == null
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
