import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_capture_mode.dart';

class SingleFaceCaptureScreen extends StatefulWidget {
  const SingleFaceCaptureScreen({
    super.key,
    required this.mode,
    this.showDebugInfo = true,
  });

  final FaceCaptureMode mode;
  final bool showDebugInfo;

  @override
  State<SingleFaceCaptureScreen> createState() =>
      _SingleFaceCaptureScreenState();
}

class _SingleFaceCaptureScreenState extends State<SingleFaceCaptureScreen> {
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  late final FaceDetector _faceDetector;
  late final FlutterTts _tts;
  bool _isTtsReady = false;
  Future<void>? _ttsInitFuture;

  bool _isInitializing = true;
  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _isCountingDown = false;
  bool _isTakingShot = false;
  bool _hasLoggedFirstFrameMetadata = false;

  Timer? _captureTimer;

  String _statusText = 'Đang khởi tạo camera...';
  String? _errorText;

  double? _lastYaw;
  int _detectedFaceCount = 0;
  double _lastFaceRatio = 0;
  double _lastCenterOffsetX = 0;
  double _lastCenterOffsetY = 0;

  bool _debugPoseMatched = false;
  bool _debugLargeEnough = false;
  bool _debugCenterOk = false;

  int _stableFrames = 0;
  static const int _requiredStableFrames = 5;
  static const int _requiredStableFramesAndroid = 3;

  // Android-only tuning knobs (keep iOS thresholds/logic untouched).
  static const double _androidMinFaceRatio = 0.045; // was 0.06
  static const double _androidMaxCenterOffsetX = 0.23; // was 0.20
  static const double _androidMaxCenterOffsetY = 0.30; // was 0.25
  static const double _androidYawFrontAbsTolerance = 16; // was 14
  static const double _androidYawSideAbsTolerance = 16; // was 18
  static const double _androidYawScoreFalloffDeg = 6;
  static const double _androidRatioScoreFullMultiplier = 1.6;
  static const double _androidCenterRelaxRangeX = 0.10;
  static const double _androidCenterRelaxRangeY = 0.10;
  static const double _androidPoseScoreWeight = 0.45;
  static const double _androidSizeScoreWeight = 0.20;
  static const double _androidCenterScoreWeight = 0.35;

  // Soft-score thresholds for Android stability.
  static const double _androidFramePassScore = 0.60;
  static const double _androidStartScore = 0.66;
  static const double _androidCountdownCancelScore = 0.45;
  static const int _androidCountdownGraceBadFrames = 1;

  // Reduce Android load without skipping too aggressively.
  static const int _androidMinProcessIntervalMs = 50;
  int _androidCountdownBadFrames = 0;
  int _androidLastProcessMs = 0;
  double _androidLastScore = 0;

  // Captured during InputImage conversion; used to align bbox->center math.
  int? _lastInputImageRotationRaw;
  String _androidLastFailReason = '';
  int _androidLastFailLogMs = 0;
  int _countdownToken = 0;

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();
    _tts.setStartHandler(() => _log('TTS START'));
    _tts.setCompletionHandler(() => _log('TTS COMPLETE'));
    _tts.setErrorHandler((message) {
      _log('TTS ERROR: $message');
      _isTtsReady = false;
      _ttsInitFuture = null;
    });
    _tts.awaitSpeakCompletion(false);
    unawaited(_ensureTtsReady());

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: Platform.isAndroid
            ? FaceDetectorMode.fast
            : FaceDetectorMode.accurate,
      ),
    );

    _initCamera();
  }

  void _log(String message) {
    debugPrint('[FACE_CAPTURE][${widget.mode.name.toUpperCase()}] $message');
  }

  String get _stepLabel => widget.mode.name;

  void _logState({
    required String tag,
    double? yaw,
    double? ratio,
    double? centerOffsetX,
    double? centerOffsetY,
    int? requiredStableFrames,
  }) {
    final required = requiredStableFrames ?? _requiredStableFrames;
    debugPrint(
      '[FACE][$tag] '
      'step=$_stepLabel '
      'yaw=${yaw?.toStringAsFixed(1) ?? "--"} '
      'ratio=${ratio?.toStringAsFixed(3) ?? "--"} '
      'centerX=${centerOffsetX?.toStringAsFixed(3) ?? "--"} '
      'centerY=${centerOffsetY?.toStringAsFixed(3) ?? "--"} '
      'count=$_detectedFaceCount '
      'pose=$_debugPoseMatched '
      'large=$_debugLargeEnough '
      'center=$_debugCenterOk '
      'stable=$_stableFrames/$required '
      'counting=$_isCountingDown '
      'taking=$_isTakingShot '
      'token=$_countdownToken',
    );
  }

  void _logFail(
    String reason, {
    double? yaw,
    double? ratio,
    double? centerOffsetX,
    double? centerOffsetY,
    int? requiredStableFrames,
  }) {
    final required = requiredStableFrames ?? _requiredStableFrames;
    debugPrint(
      '[FACE][FAIL] '
      'step=$_stepLabel '
      'reason=$reason '
      'yaw=${yaw?.toStringAsFixed(1) ?? "--"} '
      'ratio=${ratio?.toStringAsFixed(3) ?? "--"} '
      'centerX=${centerOffsetX?.toStringAsFixed(3) ?? "--"} '
      'centerY=${centerOffsetY?.toStringAsFixed(3) ?? "--"} '
      'stable=$_stableFrames/$required '
      'token=$_countdownToken',
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _setError('Không tìm thấy camera trên thiết bị');
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        Platform.isAndroid ? ResolutionPreset.low : ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!_controller!.value.isInitialized) {
        _setError('Camera chưa được khởi tạo thành công');
        return;
      }

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _statusText = _initialInstruction();
      });

      _log('CAMERA READY');
      await _startImageStream();
      unawaited(_speak(_initialInstruction()));
    } catch (e, st) {
      _log('_initCamera error: $e');
      _log('$st');
      _setError('Không thể khởi tạo camera: $e');
    }
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _isStreaming) return;

    try {
      await _controller!.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _isStreaming = true;
      });

      _log('STREAM START');
    } catch (e, st) {
      _log('startImageStream error: $e');
      _log('$st');
      _setError('Không thể bật camera stream: $e');
    }
  }

  Future<void> _stopImageStreamIfNeeded() async {
    if (_controller == null) return;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
      _isStreaming = false;
      _log('STREAM STOP');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (Platform.isAndroid) {
      await _processCameraImageAndroid(image);
    } else {
      await _processCameraImageIOS(image);
    }
  }

  // iOS path: keep existing thresholds/behavior unchanged.
  Future<void> _processCameraImageIOS(CameraImage image) async {
    if (_isProcessing || _isTakingShot) {
      return;
    }

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      _detectedFaceCount = faces.length;

      if (faces.isEmpty) {
        _log('NO FACE');
        _stableFrames = 0;
        _resetCaptureState();
        setState(() {
          _lastYaw = null;
          _lastFaceRatio = 0;
          _lastCenterOffsetX = 0;
          _lastCenterOffsetY = 0;
          _debugPoseMatched = false;
          _debugLargeEnough = false;
          _debugCenterOk = false;
          _statusText = 'Không thấy khuôn mặt';
        });
        _logFail('no face');
        return;
      }

      if (faces.length > 1) {
        _log('MULTIPLE FACES: ${faces.length}');
        _stableFrames = 0;
        _resetCaptureState();
        setState(() {
          _lastYaw = null;
          _lastFaceRatio = 0;
          _lastCenterOffsetX = 0;
          _lastCenterOffsetY = 0;
          _debugPoseMatched = false;
          _debugLargeEnough = false;
          _debugCenterOk = false;
          _statusText = 'Chỉ để 1 khuôn mặt trong khung';
        });
        _logFail('multi faces');
        return;
      }

      final face = faces.first;
      final yaw = face.headEulerAngleY;
      if (yaw == null) {
        _stableFrames = 0;
        _resetCaptureState();
        setState(() {
          _lastYaw = null;
          _debugPoseMatched = false;
          _debugLargeEnough = false;
          _debugCenterOk = false;
          _statusText = 'Đang phân tích góc khuôn mặt...';
        });
        _logFail('missing yaw');
        return;
      }

      final ratio = _getFaceRatio(face, image);
      final centerOffsets = _getFaceCenterOffsets(face, image);
      final centerOffsetX = centerOffsets.$1;
      final centerOffsetY = centerOffsets.$2;

      _lastYaw = yaw;
      _lastFaceRatio = ratio;
      _lastCenterOffsetX = centerOffsetX;
      _lastCenterOffsetY = centerOffsetY;

      final isPoseMatched = _isPoseMatched(yaw);
      final isFaceLargeEnough = ratio > 0.06;
      final isCenterOk = _isFaceCentered(centerOffsetX, centerOffsetY);
      final isStillValid = isPoseMatched && isFaceLargeEnough && isCenterOk;

      _debugPoseMatched = isPoseMatched;
      _debugLargeEnough = isFaceLargeEnough;
      _debugCenterOk = isCenterOk;

      _logState(
        tag: 'FRAME',
        yaw: yaw,
        ratio: ratio,
        centerOffsetX: centerOffsetX,
        centerOffsetY: centerOffsetY,
      );

      if (_isCountingDown) {
        if (!isStillValid) {
          _log(
            'COUNTDOWN CANCEL (lost pose) '
            'pose=$isPoseMatched large=$isFaceLargeEnough center=$isCenterOk',
          );
          _stableFrames = 0;
          _resetCaptureState();
          if (mounted) {
            setState(() {
              _statusText = _getDynamicPoseInstruction(
                yaw: yaw,
                isFaceLargeEnough: isFaceLargeEnough,
                isCenterOk: isCenterOk,
              );
            });
          }
        }
        return;
      }

      if (isStillValid) {
        _stableFrames++;
      } else {
        _stableFrames = 0;
      }

      if (!isPoseMatched) {
        setState(() {
          _statusText = _getDynamicPoseInstruction(
            yaw: yaw,
            isFaceLargeEnough: isFaceLargeEnough,
            isCenterOk: isCenterOk,
          );
        });
        _logFail(
          'pose not matched',
          yaw: yaw,
          ratio: ratio,
          centerOffsetX: centerOffsetX,
          centerOffsetY: centerOffsetY,
        );
        return;
      }

      if (!isFaceLargeEnough) {
        setState(() {
          _statusText = 'Đưa mặt lại gần hơn một chút';
        });
        _logFail(
          'too small',
          yaw: yaw,
          ratio: ratio,
          centerOffsetX: centerOffsetX,
          centerOffsetY: centerOffsetY,
        );
        return;
      }

      if (!isCenterOk) {
        setState(() {
          _statusText = 'Đưa mặt vào gần giữa màn hình hơn';
        });
        _logFail(
          'not centered',
          yaw: yaw,
          ratio: ratio,
          centerOffsetX: centerOffsetX,
          centerOffsetY: centerOffsetY,
        );
        return;
      }

      if (_stableFrames < _requiredStableFrames) {
        _log(
          'STABLE WAIT step=$_stepLabel frame=$_stableFrames/$_requiredStableFrames',
        );
        if (mounted) {
          setState(() {
            _statusText = 'Giữ ổn định khuôn mặt một chút';
          });
        }
        return;
      }

      _logState(
        tag: 'PASS',
        yaw: yaw,
        ratio: ratio,
        centerOffsetX: centerOffsetX,
        centerOffsetY: centerOffsetY,
      );

      _isCountingDown = true;
      _stableFrames = 0;
      final token = ++_countdownToken;

      if (mounted) {
        setState(() {
          _statusText = 'Vui lòng giữ nguyên trong 2 giây';
        });
      }

      _log('COUNTDOWN START step=$_stepLabel token=$token');
      _speak('Vui lòng giữ nguyên trong 2 giây');

      _captureTimer = Timer(const Duration(seconds: 2), () async {
        if (!mounted) {
          _log('COUNTDOWN ABORT token=$token reason=not mounted');
          return;
        }
        if (token != _countdownToken) {
          _log('COUNTDOWN ABORT token=$token reason=stale token');
          return;
        }
        if (!_isCountingDown) {
          _log('COUNTDOWN ABORT token=$token reason=countdown reset');
          return;
        }
        if (_isTakingShot) {
          _log('COUNTDOWN ABORT token=$token reason=already taking');
          return;
        }

        _isTakingShot = true;

        if (mounted) {
          setState(() {
            _statusText = 'Đang chụp ảnh...';
          });
        }

        try {
          await _stopImageStreamIfNeeded();
          await Future.delayed(const Duration(milliseconds: 300));
          await _capturePhoto();
        } catch (e, st) {
          _log('capture timer error: $e');
          _log('$st');
          _isTakingShot = false;
          _resetCaptureState();

          if (_controller != null &&
              _controller!.value.isInitialized &&
              !_controller!.value.isStreamingImages) {
            await _startImageStream();
          }
        }
      });
    } catch (e, st) {
      _log('_processCameraImage error: $e');
      _log('$st');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processCameraImageAndroid(CameraImage image) async {
    if (_isProcessing || _isTakingShot) return;

    // Throttle expensive MLKit calls on Android.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_androidLastProcessMs != 0 &&
        nowMs - _androidLastProcessMs < _androidMinProcessIntervalMs) {
      return;
    }
    _androidLastProcessMs = nowMs;

    _isProcessing = true;
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;
      _detectedFaceCount = faces.length;

      // Default “bad frame” values (no reset, only decay).
      bool poseOk = false;
      bool sizeOk = false;
      bool centerOk = false;
      double yaw = 0;
      double ratio = 0;
      double centerOffsetX = 0;
      double centerOffsetY = 0;
      double totalScore = 0;

      if (faces.length != 1) {
        if (_isCountingDown) {
          _androidCountdownBadFrames++;
          if (_androidCountdownBadFrames >
              _androidCountdownGraceBadFrames) {
            _androidCountdownBadFrames = 0;
            _stableFrames = 0;
            _resetCaptureState();
            if (mounted) {
              setState(() {
                _statusText = faces.isEmpty
                    ? 'Không thấy khuôn mặt'
                    : 'Chỉ để 1 khuôn mặt trong khung';
                _lastYaw = null;
                _lastFaceRatio = 0;
                _lastCenterOffsetX = 0;
                _lastCenterOffsetY = 0;
              });
            }
          }
        } else {
          _stableFrames = (_stableFrames > 0) ? _stableFrames - 1 : 0;
          if (mounted) {
            setState(() {
              _statusText = faces.isEmpty
                  ? 'Không thấy khuôn mặt'
                  : 'Chỉ để 1 khuôn mặt trong khung';
              _lastYaw = null;
              _lastFaceRatio = 0;
              _lastCenterOffsetX = 0;
              _lastCenterOffsetY = 0;
            });
          }
        }

        _debugPoseMatched = false;
        _debugLargeEnough = false;
        _debugCenterOk = false;
        final failReason = faces.isEmpty ? 'no face' : 'multi faces';
        if (failReason != _androidLastFailReason ||
            nowMs - _androidLastFailLogMs > 500) {
          _androidLastFailReason = failReason;
          _androidLastFailLogMs = nowMs;
          _logFail(
            failReason,
            requiredStableFrames: _requiredStableFramesAndroid,
            yaw: null,
            ratio: null,
            centerOffsetX: null,
            centerOffsetY: null,
          );
        }
        return;
      }

      final face = faces.first;
      final rawYaw = face.headEulerAngleY;
      if (rawYaw == null) {
        if (_isCountingDown) {
          _androidCountdownBadFrames++;
          if (_androidCountdownBadFrames >
              _androidCountdownGraceBadFrames) {
            _androidCountdownBadFrames = 0;
            _stableFrames = 0;
            _resetCaptureState();
            if (mounted) {
              setState(() {
                _statusText = 'Đang phân tích góc khuôn mặt...';
                _lastYaw = null;
                _lastFaceRatio = 0;
                _lastCenterOffsetX = 0;
                _lastCenterOffsetY = 0;
              });
            }
          }
        } else {
          _stableFrames = (_stableFrames > 0) ? _stableFrames - 1 : 0;
          if (mounted) {
            setState(() {
              _statusText = 'Đang phân tích góc khuôn mặt...';
              _lastYaw = null;
              _lastFaceRatio = 0;
              _lastCenterOffsetX = 0;
              _lastCenterOffsetY = 0;
            });
          }
        }

        _debugPoseMatched = false;
        _debugLargeEnough = false;
        _debugCenterOk = false;
        if (_androidLastFailReason != 'missing yaw' ||
            nowMs - _androidLastFailLogMs > 500) {
          _androidLastFailReason = 'missing yaw';
          _androidLastFailLogMs = nowMs;
          _logFail(
            'missing yaw',
            requiredStableFrames: _requiredStableFramesAndroid,
          );
        }
        return;
      }

      yaw = rawYaw;
      ratio = _getFaceRatio(face, image);
      final centerOffsets = _getFaceCenterOffsetsAndroid(face, image);
      centerOffsetX = centerOffsets.$1;
      centerOffsetY = centerOffsets.$2;

      _lastYaw = yaw;
      _lastFaceRatio = ratio;
      _lastCenterOffsetX = centerOffsetX;
      _lastCenterOffsetY = centerOffsetY;

      poseOk = _isPoseMatchedAndroid(yaw);
      sizeOk = ratio > _androidMinFaceRatio;
      centerOk = _isFaceCenteredAndroid(centerOffsetX, centerOffsetY);

      _debugPoseMatched = poseOk;
      _debugLargeEnough = sizeOk;
      _debugCenterOk = centerOk;

      final poseScore = _scoreAndroidPose(yaw);
      final sizeScore = _scoreAndroidFaceSize(ratio);
      final centerScore =
          _scoreAndroidCenter(centerOffsetX: centerOffsetX, centerOffsetY: centerOffsetY);

      totalScore = poseScore * _androidPoseScoreWeight +
          sizeScore * _androidSizeScoreWeight +
          centerScore * _androidCenterScoreWeight;

      _androidLastScore = totalScore;

      // While counting down, don't “reset”, just cancel after sustained loss.
      if (_isCountingDown) {
        if (totalScore >= _androidCountdownCancelScore) {
          _androidCountdownBadFrames = 0;
        } else {
          _androidCountdownBadFrames++;
          if (_androidCountdownBadFrames >
              _androidCountdownGraceBadFrames) {
            _androidCountdownBadFrames = 0;
            _stableFrames = 0;
            _resetCaptureState();

            if (mounted) {
              setState(() {
                _statusText = _getDynamicPoseInstructionAndroid(
                  yaw: yaw,
                  isFaceLargeEnough: sizeOk,
                  isCenterOk: centerOk,
                );
              });
            }
          }
        }
        return;
      }

      // Soft-stable tracking: decay on failures instead of all-or-nothing reset.
      if (totalScore >= _androidFramePassScore) {
        _stableFrames++;
      } else {
        _stableFrames = (_stableFrames > 0) ? _stableFrames - 1 : 0;
      }

      if (_stableFrames < _requiredStableFramesAndroid) {
        final shouldShowGeneric = totalScore >= _androidFramePassScore &&
            _debugPoseMatched &&
            _debugLargeEnough &&
            _debugCenterOk;
        final guidance = shouldShowGeneric
            ? 'Giữ ổn định khuôn mặt một chút'
            : _getDynamicPoseInstructionAndroid(
                yaw: yaw,
                isFaceLargeEnough: sizeOk,
                isCenterOk: centerOk,
              );

        if (mounted && _statusText != guidance) {
          setState(() {
            _statusText = guidance;
          });
        }

        final poseFailReason = switch (widget.mode) {
          FaceCaptureMode.front =>
            'pose fail (abs(yaw)<${_androidYawFrontAbsTolerance.toStringAsFixed(0)})',
          FaceCaptureMode.left =>
            'pose fail (yaw<-${_androidYawSideAbsTolerance.toStringAsFixed(0)})',
          FaceCaptureMode.right =>
            'pose fail (yaw>${_androidYawSideAbsTolerance.toStringAsFixed(0)})',
        };

        final failReason = !_debugPoseMatched
            ? poseFailReason
            : !_debugLargeEnough
                ? 'size fail (ratio>${_androidMinFaceRatio.toStringAsFixed(3)})'
                : !_debugCenterOk
                    ? 'center fail (x<${_androidMaxCenterOffsetX.toStringAsFixed(2)} y<${_androidMaxCenterOffsetY.toStringAsFixed(2)})'
                    : 'score too low (score<${_androidFramePassScore.toStringAsFixed(2)})';

        if ((failReason != _androidLastFailReason ||
                nowMs - _androidLastFailLogMs > 500) &&
            totalScore < _androidFramePassScore) {
          _androidLastFailReason = failReason;
          _androidLastFailLogMs = nowMs;
          _logFail(
            failReason,
            requiredStableFrames: _requiredStableFramesAndroid,
            yaw: yaw,
            ratio: ratio,
            centerOffsetX: centerOffsetX,
            centerOffsetY: centerOffsetY,
          );
        }
        return;
      }

      // At this point we have enough “soft stable” frames.
      if (totalScore < _androidStartScore) {
        // Still wait for better score (prevents borderline false positives).
        _stableFrames = _stableFrames - 1;
        if (mounted) {
          setState(() {
            _statusText = 'Giữ ổn định khuôn mặt thêm một chút';
          });
        }
        return;
      }

      _logState(
        tag: 'PASS',
        yaw: yaw,
        ratio: ratio,
        centerOffsetX: centerOffsetX,
        centerOffsetY: centerOffsetY,
        requiredStableFrames: _requiredStableFramesAndroid,
      );

      _isCountingDown = true;
      _stableFrames = 0;
      _androidCountdownBadFrames = 0;
      final token = ++_countdownToken;

      if (mounted) {
        setState(() {
          _statusText = 'Vui lòng giữ nguyên trong 2 giây';
        });
      }

      _log('COUNTDOWN START step=$_stepLabel token=$token');
      _speak('Vui lòng giữ nguyên trong 2 giây');

      _captureTimer = Timer(const Duration(seconds: 2), () async {
        if (!mounted) {
          _log('COUNTDOWN ABORT token=$token reason=not mounted');
          return;
        }
        if (token != _countdownToken) {
          _log('COUNTDOWN ABORT token=$token reason=stale token');
          return;
        }
        if (!_isCountingDown) {
          _log('COUNTDOWN ABORT token=$token reason=countdown reset');
          return;
        }
        if (_isTakingShot) {
          _log('COUNTDOWN ABORT token=$token reason=already taking');
          return;
        }

        _isTakingShot = true;

        if (mounted) {
          setState(() {
            _statusText = 'Đang chụp ảnh...';
          });
        }

        try {
          await _stopImageStreamIfNeeded();
          await Future.delayed(const Duration(milliseconds: 300));
          await _capturePhoto();
        } catch (e, st) {
          _log('capture timer error: $e');
          _log('$st');
          _isTakingShot = false;
          _resetCaptureState();

          if (_controller != null &&
              _controller!.value.isInitialized &&
              !_controller!.value.isStreamingImages) {
            await _startImageStream();
          }
        }
      });
    } catch (e, st) {
      _log('_processCameraImageAndroid error: $e');
      _log('$st');
    } finally {
      _isProcessing = false;
    }
  }

  bool _isPoseMatchedAndroid(double yaw) {
    switch (widget.mode) {
      case FaceCaptureMode.front:
        return yaw.abs() < _androidYawFrontAbsTolerance;
      case FaceCaptureMode.left:
        return yaw < -_androidYawSideAbsTolerance;
      case FaceCaptureMode.right:
        return yaw > _androidYawSideAbsTolerance;
    }
  }

  bool _isFaceCenteredAndroid(double offsetX, double offsetY) {
    return offsetX < _androidMaxCenterOffsetX &&
        offsetY < _androidMaxCenterOffsetY;
  }

  double _scoreAndroidPose(double yaw) {
    final falloff = _androidYawScoreFalloffDeg;
    switch (widget.mode) {
      case FaceCaptureMode.front:
        final excess = yaw.abs() - _androidYawFrontAbsTolerance;
        if (excess <= 0) return 1;
        return (1 - excess / falloff).clamp(0.0, 1.0);
      case FaceCaptureMode.left:
        // Need yaw <= -tol
        final excess = yaw - (-_androidYawSideAbsTolerance);
        if (excess <= 0) return 1;
        return (1 - excess / falloff).clamp(0.0, 1.0);
      case FaceCaptureMode.right:
        // Need yaw >= tol
        final excess = _androidYawSideAbsTolerance - yaw;
        if (excess <= 0) return 1;
        return (1 - excess / falloff).clamp(0.0, 1.0);
    }
  }

  double _scoreAndroidFaceSize(double ratio) {
    final minRatio = _androidMinFaceRatio;
    final fullRatio = minRatio * _androidRatioScoreFullMultiplier;
    if (ratio <= minRatio) return 0;
    if (ratio >= fullRatio) return 1;
    return ((ratio - minRatio) / (fullRatio - minRatio)).clamp(0.0, 1.0);
  }

  double _scoreAndroidCenter({
    required double centerOffsetX,
    required double centerOffsetY,
  }) {
    double scoreX = 1;
    if (centerOffsetX > _androidMaxCenterOffsetX) {
      scoreX =
          1 - (centerOffsetX - _androidMaxCenterOffsetX) / _androidCenterRelaxRangeX;
    }
    scoreX = scoreX.clamp(0.0, 1.0);

    double scoreY = 1;
    if (centerOffsetY > _androidMaxCenterOffsetY) {
      scoreY =
          1 - (centerOffsetY - _androidMaxCenterOffsetY) / _androidCenterRelaxRangeY;
    }
    scoreY = scoreY.clamp(0.0, 1.0);

    return (scoreX + scoreY) / 2.0;
  }

  (double, double) _getFaceCenterOffsetsAndroid(Face face, CameraImage image) {
    final center = face.boundingBox.center;
    final rotationRaw = _lastInputImageRotationRaw;
    if (rotationRaw == null) {
      // Fallback to existing iOS math (may be slightly off on 90/270 rotations).
      final offsetX = (center.dx - image.width / 2).abs() / image.width;
      final offsetY = (center.dy - image.height / 2).abs() / image.height;
      return (offsetX, offsetY);
    }

    final rotationMod = rotationRaw % 180;
    final effectiveWidth = rotationMod != 0 ? image.height.toDouble() : image.width.toDouble();
    final effectiveHeight = rotationMod != 0 ? image.width.toDouble() : image.height.toDouble();

    final offsetX = (center.dx - effectiveWidth / 2).abs() / effectiveWidth;
    final offsetY =
        (center.dy - effectiveHeight / 2).abs() / effectiveHeight;
    return (offsetX, offsetY);
  }

  String _getDynamicPoseInstructionAndroid({
    required double yaw,
    required bool isFaceLargeEnough,
    required bool isCenterOk,
  }) {
    if (!isFaceLargeEnough) return 'Đưa mặt lại gần hơn một chút';
    if (!isCenterOk) return 'Đưa mặt vào gần giữa màn hình hơn';

    switch (widget.mode) {
      case FaceCaptureMode.front:
        if (yaw >= _androidYawFrontAbsTolerance) {
          return 'Quay mặt về giữa từ từ sang trái';
        }
        if (yaw <= -_androidYawFrontAbsTolerance) {
          return 'Quay mặt về giữa từ từ sang phải';
        }
        return 'Vui lòng nhìn thẳng vào camera';
      case FaceCaptureMode.left:
        if (yaw > -12) return 'Quay sang trái thêm một chút';
        if (yaw >= -_androidYawSideAbsTolerance) {
          return 'Quay sang trái thêm';
        }
        return 'Vui lòng quay sang trái';
      case FaceCaptureMode.right:
        if (yaw < 12) return 'Quay sang phải thêm một chút';
        if (yaw <= _androidYawSideAbsTolerance) {
          return 'Quay sang phải thêm';
        }
        return 'Vui lòng quay sang phải';
    }
  }

  bool _isPoseMatched(double yaw) {
    switch (widget.mode) {
      case FaceCaptureMode.front:
        return yaw.abs() < 14;
      case FaceCaptureMode.left:
        return yaw < -18;
      case FaceCaptureMode.right:
        return yaw > 18;
    }
  }

  (double, double) _getFaceCenterOffsets(Face face, CameraImage image) {
    final center = face.boundingBox.center;
    final offsetX = (center.dx - image.width / 2).abs() / image.width;
    final offsetY = (center.dy - image.height / 2).abs() / image.height;
    return (offsetX, offsetY);
  }

  bool _isFaceCentered(double offsetX, double offsetY) {
    return offsetX < 0.20 && offsetY < 0.25;
  }

  String _initialInstruction() {
    switch (widget.mode) {
      case FaceCaptureMode.front:
        return 'Đưa mặt vào camera và nhìn thẳng';
      case FaceCaptureMode.left:
        return 'Đưa mặt vào camera và quay sang trái';
      case FaceCaptureMode.right:
        return 'Đưa mặt vào camera và quay sang phải';
    }
  }

  String _getDynamicPoseInstruction({
    required double yaw,
    required bool isFaceLargeEnough,
    required bool isCenterOk,
  }) {
    if (!isFaceLargeEnough) {
      return 'Đưa mặt lại gần hơn một chút';
    }

    if (!isCenterOk) {
      return 'Đưa mặt vào gần giữa màn hình hơn';
    }

    switch (widget.mode) {
      case FaceCaptureMode.front:
        if (yaw > 14) return 'Quay mặt về giữa từ từ sang trái';
        if (yaw < -14) return 'Quay mặt về giữa từ từ sang phải';
        return 'Vui lòng nhìn thẳng vào camera';

      case FaceCaptureMode.left:
        if (yaw > -10) return 'Quay sang trái thêm một chút';
        if (yaw > -18) return 'Quay sang trái thêm';
        return 'Vui lòng quay sang trái';

      case FaceCaptureMode.right:
        if (yaw < 10) return 'Quay sang phải thêm một chút';
        if (yaw < 18) return 'Quay sang phải thêm';
        return 'Vui lòng quay sang phải';
    }
  }

  Future<void> _ensureTtsReady() {
    final initFuture = _ttsInitFuture;
    if (initFuture != null) return initFuture;

    final future = _initTts();
    _ttsInitFuture = future;
    return future;
  }

  String? _nonEmptyString(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  bool _ttsCallSucceeded(dynamic result) => result == 1 || result == true;

  Map<String, String>? _voiceFromDynamic(dynamic value) {
    if (value is! Map) return null;

    final name = _nonEmptyString(value['name']);
    final locale = _nonEmptyString(value['locale']);
    if (name == null || locale == null) {
      return null;
    }

    return <String, String>{'name': name, 'locale': locale};
  }

  List<Map<String, String>> _voicesFromDynamic(dynamic value) {
    if (value is! List) return const <Map<String, String>>[];

    final voices = <Map<String, String>>[];
    for (final item in value) {
      final voice = _voiceFromDynamic(item);
      if (voice != null) {
        voices.add(voice);
      }
    }
    return voices;
  }

  Map<String, String>? _pickPreferredVoice(List<Map<String, String>> voices) {
    for (final voice in voices) {
      final locale = (voice['locale'] ?? '').toLowerCase();
      if (locale.startsWith('vi')) {
        return voice;
      }
    }

    if (voices.isEmpty) return null;
    return voices.first;
  }

  String _describeVoice(Map<String, String> voice) =>
      'name=${voice['name'] ?? "unknown"} locale=${voice['locale'] ?? "unknown"}';

  Future<void> _initTts() async {
    try {
      Map<String, String>? defaultVoice;
      Map<String, String>? selectedVoice;
      var selectedVoiceApplied = false;

      if (Platform.isIOS) {
        // iOS sometimes fails silently if the audio session category isn't set.
        // Configure it explicitly for TTS playback prompts.
        await _tts.setSharedInstance(true);
        await _tts.autoStopSharedSession(true);
        final iosAudioResult = await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
        _log('TTS iOS audio category configured: $iosAudioResult');
      }

      if (Platform.isAndroid) {
        final enginesRaw = await _tts.getEngines;
        final engines = enginesRaw is List
            ? enginesRaw.map((engine) => engine.toString()).toList()
            : <String>[];

        _log('TTS ENGINES: ${engines.join(', ')}');

        if (engines.isEmpty) {
          _log('TTS unavailable: no installed engines found');
          _isTtsReady = false;
          return;
        }

        final defaultEngine = _nonEmptyString(await _tts.getDefaultEngine);
        _log('TTS DEFAULT ENGINE: ${defaultEngine ?? "null"}');

        final selectedEngine = defaultEngine ?? engines.first;
        _log('TTS SELECTED ENGINE: $selectedEngine');
        final engineResult = await _tts.setEngine(selectedEngine);
        _log('TTS SET ENGINE RESULT: $engineResult');

        await _tts.setAudioAttributesForNavigation();
        defaultVoice = _voiceFromDynamic(await _tts.getDefaultVoice);

        if (defaultVoice != null) {
          _log('TTS DEFAULT VOICE: ${_describeVoice(defaultVoice)}');
        } else {
          _log('TTS DEFAULT VOICE: null');
        }

        final voices = _voicesFromDynamic(await _tts.getVoices);
        if (voices.isNotEmpty) {
          final preview = voices.take(3).map(_describeVoice).join(' | ');
          _log('TTS VOICES: total=${voices.length} sample=$preview');
        } else {
          _log('TTS VOICES: none reported by engine');
        }

        selectedVoice = defaultVoice ?? _pickPreferredVoice(voices);
        if (selectedVoice != null) {
          final setVoiceResult = await _tts.setVoice(selectedVoice);
          selectedVoiceApplied = _ttsCallSucceeded(setVoiceResult);
          _log(
            'TTS SET VOICE RESULT: $setVoiceResult ${_describeVoice(selectedVoice)}',
          );
        }
      }

      dynamic languageResult = await _tts.setLanguage('vi-VN');
      _log('TTS LANGUAGE vi-VN: $languageResult');

      if (!_ttsCallSucceeded(languageResult)) {
        languageResult = await _tts.setLanguage('vi');
        _log('TTS LANGUAGE vi: $languageResult');
      }

      final vietnameseReady = _ttsCallSucceeded(languageResult);
      var usedVoiceFallback = false;
      if (!vietnameseReady) {
        if (Platform.isAndroid) {
          usedVoiceFallback = true;
          _log(
            selectedVoiceApplied
                ? 'TTS fallback to selected voice'
                : 'TTS fallback to engine default configuration',
          );
        } else {
          _log('TTS unavailable: failed to set Vietnamese language');
          _isTtsReady = false;
          return;
        }
      }

      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);

      _isTtsReady = true;
      _log(usedVoiceFallback ? 'TTS READY (voice fallback)' : 'TTS READY');
    } catch (e, st) {
      _isTtsReady = false;
      _log('TTS INIT ERROR: $e');
      _log('$st');
    } finally {
      if (!_isTtsReady) {
        _ttsInitFuture = null;
      }
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _ensureTtsReady();
      if (!_isTtsReady) {
        _log('TTS SKIP: engine not ready');
        return;
      }

      _log('TTS: $text');
      await _tts.stop();
      final result = await _tts.speak(text, focus: Platform.isAndroid);
      _log('TTS speak result: $result');

      // Some iOS setups may return a falsy value without throwing.
      if (!_ttsCallSucceeded(result)) {
        _log('TTS speak not confirmed; retrying with language vi');
        await _tts.setLanguage('vi');
        final retry = await _tts.speak(text, focus: Platform.isAndroid);
        _log('TTS retry result: $retry');
      }
    } catch (e, st) {
      _log('tts error: $e');
      _log('$st');
    }
  }

  void _resetCaptureState() {
    if (_captureTimer != null || _isCountingDown) {
      _log('RESET STATE token=$_countdownToken');
    }
    _countdownToken++;
    _captureTimer?.cancel();
    _captureTimer = null;
    _isCountingDown = false;
  }

  double _getFaceRatio(Face face, CameraImage image) {
    final box = face.boundingBox;
    return (box.width * box.height) / (image.width * image.height);
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final controller = _controller;
      if (controller == null) return null;
      final camera = controller.description;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation =
            _orientations[controller.value.deviceOrientation];
        if (rotationCompensation == null) {
          // Device orientation can be temporarily unavailable; assume portrait
          // instead of skipping the whole frame to keep detection stable.
          rotationCompensation = 0;
          _log('ANDROID frame: missing device orientation, assume 0°');
        }

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }

        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }

      if (rotation == null) {
        _log('SKIP FRAME: unsupported rotation=$sensorOrientation');
        return null;
      }

      if (image.planes.isEmpty) {
        _log('SKIP FRAME: no planes');
        return null;
      }

      InputImageFormat? format = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );

      if (Platform.isAndroid) {
        final isNv21LikeStream = image.planes.length == 1 &&
            (format == InputImageFormat.nv21 ||
                image.format.group == ImageFormatGroup.nv21 ||
                image.format.group == ImageFormatGroup.yuv420);

        final isYuv420888Stream = image.planes.length == 3 &&
            image.format.group == ImageFormatGroup.yuv420;

        if (isNv21LikeStream) {
          format = InputImageFormat.nv21;
        } else if (isYuv420888Stream) {
          // Some Android devices output YUV_420_888 (3 planes) even when
          // requesting NV21. MLKit can handle yuv_420_888 if we concatenate
          // Y + U + V bytes.
          format = InputImageFormat.yuv_420_888;
        } else {
          _log(
            'SKIP FRAME: unsupported Android stream '
            'raw=${image.format.raw} group=${image.format.group} planes=${image.planes.length}',
          );
          return null;
        }
      }

      if (Platform.isIOS && format != InputImageFormat.bgra8888) {
        _log('SKIP FRAME: iOS format must be bgra8888, got=$format');
        return null;
      }

      if (format == null) {
        _log('SKIP FRAME: unsupported format after normalization');
        return null;
      }

      final plane0 = image.planes.first;
      Uint8List bytes = plane0.bytes;
      int bytesPerRow = plane0.bytesPerRow;

      if (Platform.isAndroid &&
          format == InputImageFormat.yuv_420_888 &&
          image.planes.length == 3) {
        final planeU = image.planes[1];
        final planeV = image.planes[2];

        bytes = Uint8List(
          plane0.bytes.length + planeU.bytes.length + planeV.bytes.length,
        );
        // Y (plane0) + U (plane1) + V (plane2)
        bytes.setRange(0, plane0.bytes.length, plane0.bytes);
        bytes.setRange(
          plane0.bytes.length,
          plane0.bytes.length + planeU.bytes.length,
          planeU.bytes,
        );
        bytes.setRange(
          plane0.bytes.length + planeU.bytes.length,
          bytes.length,
          planeV.bytes,
        );
      }

      if (!_hasLoggedFirstFrameMetadata) {
        _hasLoggedFirstFrameMetadata = true;
        final yLen = image.planes.isNotEmpty ? image.planes[0].bytes.length : 0;
        final uLen = image.planes.length > 1 ? image.planes[1].bytes.length : 0;
        final vLen = image.planes.length > 2 ? image.planes[2].bytes.length : 0;
        _log(
          'FRAME META raw=${image.format.raw} '
          'group=${image.format.group} '
          'planes=${image.planes.length} '
          'yLen=$yLen uLen=$uLen vLen=$vLen '
          'bytesPerRow=${plane0.bytesPerRow} '
          'rotation=${rotation.rawValue} '
          'sensorOrientation=$sensorOrientation '
          'deviceOrientation=${controller.value.deviceOrientation} '
          'lens=${camera.lensDirection}',
        );
      }

      if (Platform.isAndroid) {
        _lastInputImageRotationRaw = rotation.rawValue;
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );
    } catch (e, st) {
      _log('_convert error: $e');
      _log('$st');
      return null;
    }
  }

  Future<void> _capturePhoto() async {
    try {
      if (_controller == null) return;
      if (!_controller!.value.isInitialized) return;
      if (_controller!.value.isTakingPicture) return;

      _log('CAPTURE START step=$_stepLabel');

      final imageFile = await _controller!.takePicture();

      _log('CAPTURE DONE step=$_stepLabel path=${imageFile.path}');

      _stableFrames = 0;
      _resetCaptureState();
      _isTakingShot = false;

      if (!mounted) return;

      setState(() {
        _statusText = 'Đã chụp thành công';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã chụp ảnh thành công')));

      unawaited(_speak('Đã chụp thành công'));

      if (!mounted) return;
      Navigator.of(context).pop(imageFile.path);
    } catch (e, st) {
      _log('_capturePhoto error: $e');
      _log('$st');
      _isTakingShot = false;
      _resetCaptureState();

      if (_controller != null &&
          _controller!.value.isInitialized &&
          !_controller!.value.isStreamingImages) {
        await _startImageStream();
      }
    }
  }

  void _setError(String message) {
    _log('ERROR: $message');
    if (!mounted) return;
    setState(() {
      _errorText = message;
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _log('DISPOSE');
    _captureTimer?.cancel();
    _tts.stop();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildDebugInfo() {
    final requiredStableFrames = Platform.isAndroid
        ? _requiredStableFramesAndroid
        : _requiredStableFrames;
    return Positioned(
      top: 60,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('step: $_stepLabel'),
              Text('faces: $_detectedFaceCount'),
              Text('yaw: ${_lastYaw?.toStringAsFixed(2) ?? "--"}'),
              Text('ratio: ${_lastFaceRatio.toStringAsFixed(3)}'),
              Text('centerX: ${_lastCenterOffsetX.toStringAsFixed(3)}'),
              Text('centerY: ${_lastCenterOffsetY.toStringAsFixed(3)}'),
              Text('poseMatched: $_debugPoseMatched'),
              Text('largeEnough: $_debugLargeEnough'),
              Text('centerOk: $_debugCenterOk'),
              Text('stableFrames: $_stableFrames/$requiredStableFrames'),
              Text('countdownToken: $_countdownToken'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStatus() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorText != null) {
      return Scaffold(body: Center(child: Text(_errorText!)));
    }

    if (_isInitializing || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;

    final previewSize = _controller!.value.previewSize;
    final previewWidth = previewSize?.height ?? size.width;
    final previewHeight = previewSize?.width ?? size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          if (widget.showDebugInfo) _buildDebugInfo(),
          _buildBottomStatus(),
        ],
      ),
    );
  }
}
