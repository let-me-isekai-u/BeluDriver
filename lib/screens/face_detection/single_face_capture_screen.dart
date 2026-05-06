import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

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

  // Gallery picker state
  bool _isPickingFromGallery = false;

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

      // Default "bad frame" values (no reset, only decay).
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
        _stableFrames = (_stableFrames > 0) ? _stableFrames - 1 : 0;
        _debugPoseMatched = false;
        if (mounted) {
          setState(() {
            _statusText = 'Đang phân tích góc khuôn mặt...';
            _lastYaw = null;
          });
        }
        return;
      }

      yaw = rawYaw;
      ratio = _getFaceRatioAndroid(face, image);
      final offsets = _getFaceCenterOffsetsAndroid(face, image);
      centerOffsetX = offsets.$1;
      centerOffsetY = offsets.$2;

      _lastYaw = yaw;
      _lastFaceRatio = ratio;
      _lastCenterOffsetX = centerOffsetX;
      _lastCenterOffsetY = centerOffsetY;

      // --- Soft scoring ---
      final double poseScore = _androidPoseScore(yaw);
      final double sizeScore = _androidSizeScore(ratio);
      final double centerScore = _androidCenterScore(centerOffsetX, centerOffsetY);

      poseOk = poseScore > 0;
      sizeOk = sizeScore > 0;
      centerOk = centerScore > 0;

      totalScore = _androidPoseScoreWeight * poseScore +
          _androidSizeScoreWeight * sizeScore +
          _androidCenterScoreWeight * centerScore;

      _androidLastScore = totalScore;
      _debugPoseMatched = poseOk;
      _debugLargeEnough = sizeOk;
      _debugCenterOk = centerOk;

      if (_isCountingDown) {
        if (totalScore < _androidCountdownCancelScore) {
          _androidCountdownBadFrames++;
          if (_androidCountdownBadFrames > _androidCountdownGraceBadFrames) {
            _androidCountdownBadFrames = 0;
            _stableFrames = 0;
            _resetCaptureState();
            if (mounted) {
              setState(() {
                _statusText = _getDynamicPoseInstructionAndroid(
                  yaw: yaw,
                  sizeOk: sizeOk,
                  centerOk: centerOk,
                );
              });
            }
          }
        } else {
          _androidCountdownBadFrames = 0;
        }
        return;
      }

      if (totalScore >= _androidFramePassScore) {
        _stableFrames++;
      } else {
        _stableFrames = (_stableFrames > 0) ? _stableFrames - 1 : 0;
      }

      if (mounted) {
        final instruction = _getDynamicPoseInstructionAndroid(
          yaw: yaw,
          sizeOk: sizeOk,
          centerOk: centerOk,
          score: totalScore,
        );
        setState(() {
          _statusText = instruction;
        });
      }

      if (_stableFrames < _requiredStableFramesAndroid) return;

      if (totalScore < _androidStartScore) {
        _logFail(
          'score_too_low',
          yaw: yaw,
          ratio: ratio,
          centerOffsetX: centerOffsetX,
          centerOffsetY: centerOffsetY,
          requiredStableFrames: _requiredStableFramesAndroid,
        );
        return;
      }

      _isCountingDown = true;
      _androidCountdownBadFrames = 0;
      _stableFrames = 0;
      final token = ++_countdownToken;

      if (mounted) {
        setState(() {
          _statusText = 'Vui lòng giữ nguyên trong 2 giây';
        });
      }

      _log('COUNTDOWN START step=$_stepLabel token=$token score=${totalScore.toStringAsFixed(2)}');
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

  double _androidPoseScore(double yaw) {
    final target = widget.mode == FaceCaptureMode.front
        ? 0.0
        : widget.mode == FaceCaptureMode.left
        ? -40.0
        : 40.0;
    final tolerance = widget.mode == FaceCaptureMode.front
        ? _androidYawFrontAbsTolerance
        : _androidYawSideAbsTolerance;
    final diff = (yaw - target).abs();
    if (diff > tolerance) return 0.0;
    return (1.0 - (diff / tolerance)).clamp(0.0, 1.0);
  }

  double _androidSizeScore(double ratio) {
    if (ratio < _androidMinFaceRatio) return 0.0;
    return (ratio * _androidRatioScoreFullMultiplier).clamp(0.0, 1.0);
  }

  double _androidCenterScore(double offsetX, double offsetY) {
    final relaxX = _androidCenterRelaxRangeX;
    final relaxY = _androidCenterRelaxRangeY;
    final maxX = _androidMaxCenterOffsetX;
    final maxY = _androidMaxCenterOffsetY;

    double sx = 1.0;
    if (offsetX.abs() > relaxX) {
      sx = 1.0 - ((offsetX.abs() - relaxX) / (maxX - relaxX)).clamp(0.0, 1.0);
    }

    double sy = 1.0;
    if (offsetY.abs() > relaxY) {
      sy = 1.0 - ((offsetY.abs() - relaxY) / (maxY - relaxY)).clamp(0.0, 1.0);
    }

    return (sx * sy).clamp(0.0, 1.0);
  }

  double _getFaceRatioAndroid(Face face, CameraImage image) {
    final rotation = _lastInputImageRotationRaw ?? 90;
    final isPortrait = rotation == 90 || rotation == 270;
    final screenW = isPortrait ? image.height.toDouble() : image.width.toDouble();
    final screenH = isPortrait ? image.width.toDouble() : image.height.toDouble();
    final faceW = face.boundingBox.width;
    final faceH = face.boundingBox.height;
    return (faceW * faceH) / (screenW * screenH);
  }

  (double, double) _getFaceCenterOffsetsAndroid(Face face, CameraImage image) {
    final rotation = _lastInputImageRotationRaw ?? 90;
    final isPortrait = rotation == 90 || rotation == 270;
    final screenW = isPortrait ? image.height.toDouble() : image.width.toDouble();
    final screenH = isPortrait ? image.width.toDouble() : image.height.toDouble();
    final faceCenterX = face.boundingBox.left + face.boundingBox.width / 2;
    final faceCenterY = face.boundingBox.top + face.boundingBox.height / 2;
    final offsetX = (faceCenterX - screenW / 2) / screenW;
    final offsetY = (faceCenterY - screenH / 2) / screenH;
    return (offsetX, offsetY);
  }

  String _getDynamicPoseInstructionAndroid({
    required double yaw,
    required bool sizeOk,
    required bool centerOk,
    double? score,
  }) {
    if (!sizeOk) return 'Đưa mặt lại gần hơn một chút';
    if (!centerOk) return 'Đưa mặt vào gần giữa màn hình hơn';
    return _getDynamicPoseInstruction(
      yaw: yaw,
      isFaceLargeEnough: sizeOk,
      isCenterOk: centerOk,
    );
  }

  void _resetCaptureState() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _isCountingDown = false;
    _isTakingShot = false;
    _countdownToken++;
  }

  bool _isPoseMatched(double yaw) {
    switch (widget.mode) {
      case FaceCaptureMode.front:
        return yaw.abs() <= 14;
      case FaceCaptureMode.left:
        return yaw >= -55 && yaw <= -25;
      case FaceCaptureMode.right:
        return yaw >= 25 && yaw <= 55;
    }
  }

  bool _isFaceCentered(double offsetX, double offsetY) {
    return offsetX.abs() <= 0.20 && offsetY.abs() <= 0.25;
  }

  String _initialInstruction() {
    switch (widget.mode) {
      case FaceCaptureMode.front:
        return 'Nhìn thẳng vào camera';
      case FaceCaptureMode.left:
        return 'Quay đầu sang trái khoảng 45°';
      case FaceCaptureMode.right:
        return 'Quay đầu sang phải khoảng 45°';
    }
  }

  String _getDynamicPoseInstruction({
    required double yaw,
    required bool isFaceLargeEnough,
    required bool isCenterOk,
  }) {
    if (!isFaceLargeEnough) return 'Đưa mặt lại gần hơn một chút';
    if (!isCenterOk) return 'Đưa mặt vào gần giữa màn hình hơn';
    switch (widget.mode) {
      case FaceCaptureMode.front:
        if (yaw > 14) return 'Quay mặt sang trái một chút';
        if (yaw < -14) return 'Quay mặt sang phải một chút';
        return 'Nhìn thẳng vào camera';
      case FaceCaptureMode.left:
        if (yaw > -25) return 'Quay đầu sang trái thêm';
        if (yaw < -55) return 'Quay đầu sang phải một chút';
        return 'Giữ nguyên góc này';
      case FaceCaptureMode.right:
        if (yaw < 25) return 'Quay đầu sang phải thêm';
        if (yaw > 55) return 'Quay đầu sang trái một chút';
        return 'Giữ nguyên góc này';
    }
  }

  double _getFaceRatio(Face face, CameraImage image) {
    final screenW = image.width.toDouble();
    final screenH = image.height.toDouble();
    final faceW = face.boundingBox.width;
    final faceH = face.boundingBox.height;
    return (faceW * faceH) / (screenW * screenH);
  }

  (double, double) _getFaceCenterOffsets(Face face, CameraImage image) {
    final screenW = image.width.toDouble();
    final screenH = image.height.toDouble();
    final faceCenterX = face.boundingBox.left + face.boundingBox.width / 2;
    final faceCenterY = face.boundingBox.top + face.boundingBox.height / 2;
    final offsetX = (faceCenterX - screenW / 2) / screenW;
    final offsetY = (faceCenterY - screenH / 2) / screenH;
    return (offsetX, offsetY);
  }

  Future<void> _ensureTtsReady() async {
    if (_isTtsReady) return;
    _ttsInitFuture ??= _tts
        .setLanguage('vi-VN')
        .then((_) => _tts.setSpeechRate(0.5))
        .then((_) => _tts.setVolume(1.0))
        .then((_) {
      _isTtsReady = true;
      _log('TTS READY');
    }).catchError((e) {
      _log('TTS INIT ERROR: $e');
      _isTtsReady = false;
      _ttsInitFuture = null;
    });
    await _ttsInitFuture;
  }

  Future<void> _speak(String text) async {
    try {
      await _ensureTtsReady();
      if (_isTtsReady) {
        await _tts.speak(text);
      }
    } catch (e) {
      _log('_speak error: $e');
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final controller = _controller;
      if (controller == null) return null;

      final camera = controller.description;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation rotation;

      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;
      } else {
        final deviceOrientation = controller.value.deviceOrientation;
        final orientationOffset = _orientations[deviceOrientation] ?? 0;

        int rotationCompensation = sensorOrientation - orientationOffset;

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + orientationOffset) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - orientationOffset + 360) % 360;
        }

        rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ??
            InputImageRotation.rotation0deg;
      }

      if (image.width == 0 || image.height == 0) {
        _log('SKIP FRAME: zero dimension');
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

  // ── NEW: Pick from gallery ────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    if (_isPickingFromGallery || _isTakingShot) return;

    setState(() => _isPickingFromGallery = true);
    _log('GALLERY PICK START step=$_stepLabel');

    // Pause the camera stream while the gallery is open so the detector
    // does not compete with the OS photo picker.
    await _stopImageStreamIfNeeded();

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (!mounted) return;

      if (picked != null) {
        _log('GALLERY PICK DONE step=$_stepLabel path=${picked.path}');
        Navigator.of(context).pop(picked.path);
      } else {
        _log('GALLERY PICK CANCELLED step=$_stepLabel');
        // User cancelled — resume the camera stream.
        await _startImageStream();
      }
    } catch (e, st) {
      _log('_pickFromGallery error: $e');
      _log('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở thư viện ảnh'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _startImageStream();
      }
    } finally {
      if (mounted) setState(() => _isPickingFromGallery = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

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

  // ── NEW: Gallery button pinned to top-right ───────────────────────────────

  Widget _buildGalleryButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: SafeArea(
        child: Material(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isPickingFromGallery ? null : _pickFromGallery,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _isPickingFromGallery
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Chọn từ thư viện',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

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
          _buildGalleryButton(),   // ← NEW
          _buildBottomStatus(),
        ],
      ),
    );
  }
}