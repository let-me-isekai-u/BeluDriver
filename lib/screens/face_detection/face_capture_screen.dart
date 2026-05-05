// import 'dart:async';
// import 'dart:ui';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
//
// import 'face_capture_mode.dart';
//
// class SingleFaceCaptureScreen extends StatefulWidget {
//   const SingleFaceCaptureScreen({
//     super.key,
//     required this.mode,
//     this.showDebugInfo = true,
//   });
//
//   final FaceCaptureMode mode;
//   final bool showDebugInfo;
//
//   @override
//   State<SingleFaceCaptureScreen> createState() =>
//       _SingleFaceCaptureScreenState();
// }
//
// class _SingleFaceCaptureScreenState extends State<SingleFaceCaptureScreen> {
//   CameraController? _controller;
//   late final FaceDetector _faceDetector;
//   late final FlutterTts _tts;
//
//   bool _isInitializing = true;
//   bool _isStreaming = false;
//   bool _isProcessing = false;
//   bool _isCountingDown = false;
//   bool _isTakingShot = false;
//
//   Timer? _captureTimer;
//
//   String _statusText = 'Đang khởi tạo camera...';
//   String? _errorText;
//
//   double? _lastYaw;
//   int _detectedFaceCount = 0;
//   double _lastFaceRatio = 0;
//   double _lastCenterOffsetX = 0;
//   double _lastCenterOffsetY = 0;
//
//   bool _debugPoseMatched = false;
//   bool _debugLargeEnough = false;
//   bool _debugCenterOk = false;
//
//   int _stableFrames = 0;
//   static const int _requiredStableFrames = 5;
//   int _countdownToken = 0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _tts = FlutterTts();
//     _tts.setLanguage('vi-VN');
//     _tts.setSpeechRate(0.45);
//     _tts.setVolume(1.0);
//     _tts.awaitSpeakCompletion(true);
//
//     _faceDetector = FaceDetector(
//       options: FaceDetectorOptions(
//         enableClassification: true,
//         enableTracking: true,
//         performanceMode: FaceDetectorMode.fast,
//       ),
//     );
//
//     _initCamera();
//   }
//
//   void _log(String message) {
//     debugPrint('[FACE_CAPTURE][${widget.mode.name.toUpperCase()}] $message');
//   }
//
//   String get _stepLabel => widget.mode.name;
//
//   void _logState({
//     required String tag,
//     double? yaw,
//     double? ratio,
//     double? centerOffsetX,
//     double? centerOffsetY,
//   }) {
//     debugPrint(
//       '[FACE][$tag] '
//           'step=$_stepLabel '
//           'yaw=${yaw?.toStringAsFixed(1) ?? "--"} '
//           'ratio=${ratio?.toStringAsFixed(3) ?? "--"} '
//           'centerX=${centerOffsetX?.toStringAsFixed(3) ?? "--"} '
//           'centerY=${centerOffsetY?.toStringAsFixed(3) ?? "--"} '
//           'count=$_detectedFaceCount '
//           'pose=$_debugPoseMatched '
//           'large=$_debugLargeEnough '
//           'center=$_debugCenterOk '
//           'stable=$_stableFrames/$_requiredStableFrames '
//           'counting=$_isCountingDown '
//           'taking=$_isTakingShot '
//           'token=$_countdownToken',
//     );
//   }
//
//   void _logFail(
//       String reason, {
//         double? yaw,
//         double? ratio,
//         double? centerOffsetX,
//         double? centerOffsetY,
//       }) {
//     debugPrint(
//       '[FACE][FAIL] '
//           'step=$_stepLabel '
//           'reason=$reason '
//           'yaw=${yaw?.toStringAsFixed(1) ?? "--"} '
//           'ratio=${ratio?.toStringAsFixed(3) ?? "--"} '
//           'centerX=${centerOffsetX?.toStringAsFixed(3) ?? "--"} '
//           'centerY=${centerOffsetY?.toStringAsFixed(3) ?? "--"} '
//           'stable=$_stableFrames/$_requiredStableFrames '
//           'token=$_countdownToken',
//     );
//   }
//
//   Future<void> _initCamera() async {
//     try {
//       final cameras = await availableCameras();
//
//       if (cameras.isEmpty) {
//         _setError('Không tìm thấy camera trên thiết bị');
//         return;
//       }
//
//       final selectedCamera = cameras.firstWhere(
//             (camera) => camera.lensDirection == CameraLensDirection.front,
//         orElse: () => cameras.first,
//       );
//
//       _controller = CameraController(
//         selectedCamera,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420,
//       );
//
//       await _controller!.initialize();
//
//       if (!_controller!.value.isInitialized) {
//         _setError('Camera chưa được khởi tạo thành công');
//         return;
//       }
//
//       if (!mounted) return;
//       setState(() {
//         _isInitializing = false;
//         _statusText = _initialInstruction();
//       });
//
//       _log('CAMERA READY');
//       await _speak(_initialInstruction());
//       await _startImageStream();
//     } catch (e, st) {
//       _log('_initCamera error: $e');
//       _log('$st');
//       _setError('Không thể khởi tạo camera: $e');
//     }
//   }
//
//   Future<void> _startImageStream() async {
//     if (_controller == null || _isStreaming) return;
//
//     try {
//       await _controller!.startImageStream(_processCameraImage);
//
//       if (!mounted) return;
//       setState(() {
//         _isStreaming = true;
//       });
//
//       _log('STREAM START');
//     } catch (e, st) {
//       _log('startImageStream error: $e');
//       _log('$st');
//       _setError('Không thể bật camera stream: $e');
//     }
//   }
//
//   Future<void> _stopImageStreamIfNeeded() async {
//     if (_controller == null) return;
//     if (_controller!.value.isStreamingImages) {
//       await _controller!.stopImageStream();
//       _isStreaming = false;
//       _log('STREAM STOP');
//     }
//   }
//
//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isProcessing || _isTakingShot) {
//       return;
//     }
//
//     _isProcessing = true;
//
//     try {
//       final inputImage = _convertCameraImageToInputImage(image);
//       if (inputImage == null) return;
//
//       final faces = await _faceDetector.processImage(inputImage);
//
//       if (!mounted) return;
//
//       _detectedFaceCount = faces.length;
//
//       if (faces.isEmpty) {
//         _log('NO FACE');
//         _stableFrames = 0;
//         _resetCaptureState();
//         setState(() {
//           _lastYaw = null;
//           _lastFaceRatio = 0;
//           _lastCenterOffsetX = 0;
//           _lastCenterOffsetY = 0;
//           _debugPoseMatched = false;
//           _debugLargeEnough = false;
//           _debugCenterOk = false;
//           _statusText = 'Không thấy khuôn mặt';
//         });
//         _logFail('no face');
//         return;
//       }
//
//       if (faces.length > 1) {
//         _log('MULTIPLE FACES: ${faces.length}');
//         _stableFrames = 0;
//         _resetCaptureState();
//         setState(() {
//           _lastYaw = null;
//           _lastFaceRatio = 0;
//           _lastCenterOffsetX = 0;
//           _lastCenterOffsetY = 0;
//           _debugPoseMatched = false;
//           _debugLargeEnough = false;
//           _debugCenterOk = false;
//           _statusText = 'Chỉ để 1 khuôn mặt trong khung';
//         });
//         _logFail('multi faces');
//         return;
//       }
//
//       final face = faces.first;
//       final yaw = face.headEulerAngleY ?? 999.0;
//       final ratio = _getFaceRatio(face, image);
//       final centerOffsets = _getFaceCenterOffsets(face, image);
//       final centerOffsetX = centerOffsets.$1;
//       final centerOffsetY = centerOffsets.$2;
//
//       _lastYaw = yaw;
//       _lastFaceRatio = ratio;
//       _lastCenterOffsetX = centerOffsetX;
//       _lastCenterOffsetY = centerOffsetY;
//
//       final isPoseMatched = _isPoseMatched(yaw);
//       final isFaceLargeEnough = ratio > 0.06;
//       final isCenterOk = _isFaceCentered(centerOffsetX, centerOffsetY);
//       final isStillValid = isPoseMatched && isFaceLargeEnough && isCenterOk;
//
//       _debugPoseMatched = isPoseMatched;
//       _debugLargeEnough = isFaceLargeEnough;
//       _debugCenterOk = isCenterOk;
//
//       _logState(
//         tag: 'FRAME',
//         yaw: yaw,
//         ratio: ratio,
//         centerOffsetX: centerOffsetX,
//         centerOffsetY: centerOffsetY,
//       );
//
//       if (_isCountingDown) {
//         if (!isStillValid) {
//           _log(
//             'COUNTDOWN CANCEL (lost pose) '
//                 'pose=$isPoseMatched large=$isFaceLargeEnough center=$isCenterOk',
//           );
//           _stableFrames = 0;
//           _resetCaptureState();
//           if (mounted) {
//             setState(() {
//               _statusText = _getDynamicPoseInstruction(
//                 yaw: yaw,
//                 isFaceLargeEnough: isFaceLargeEnough,
//                 isCenterOk: isCenterOk,
//               );
//             });
//           }
//         }
//         return;
//       }
//
//       if (isStillValid) {
//         _stableFrames++;
//       } else {
//         _stableFrames = 0;
//       }
//
//       if (!isPoseMatched) {
//         setState(() {
//           _statusText = _getDynamicPoseInstruction(
//             yaw: yaw,
//             isFaceLargeEnough: isFaceLargeEnough,
//             isCenterOk: isCenterOk,
//           );
//         });
//         _logFail(
//           'pose not matched',
//           yaw: yaw,
//           ratio: ratio,
//           centerOffsetX: centerOffsetX,
//           centerOffsetY: centerOffsetY,
//         );
//         return;
//       }
//
//       if (!isFaceLargeEnough) {
//         setState(() {
//           _statusText = 'Đưa mặt lại gần hơn một chút';
//         });
//         _logFail(
//           'too small',
//           yaw: yaw,
//           ratio: ratio,
//           centerOffsetX: centerOffsetX,
//           centerOffsetY: centerOffsetY,
//         );
//         return;
//       }
//
//       if (!isCenterOk) {
//         setState(() {
//           _statusText = 'Đưa mặt vào gần giữa màn hình hơn';
//         });
//         _logFail(
//           'not centered',
//           yaw: yaw,
//           ratio: ratio,
//           centerOffsetX: centerOffsetX,
//           centerOffsetY: centerOffsetY,
//         );
//         return;
//       }
//
//       if (_stableFrames < _requiredStableFrames) {
//         _log(
//           'STABLE WAIT step=$_stepLabel frame=$_stableFrames/$_requiredStableFrames',
//         );
//         if (mounted) {
//           setState(() {
//             _statusText = 'Giữ ổn định khuôn mặt một chút';
//           });
//         }
//         return;
//       }
//
//       _logState(
//         tag: 'PASS',
//         yaw: yaw,
//         ratio: ratio,
//         centerOffsetX: centerOffsetX,
//         centerOffsetY: centerOffsetY,
//       );
//
//       _isCountingDown = true;
//       _stableFrames = 0;
//       final token = ++_countdownToken;
//
//       if (mounted) {
//         setState(() {
//           _statusText = 'Vui lòng giữ nguyên trong 2 giây';
//         });
//       }
//
//       _log('COUNTDOWN START step=$_stepLabel token=$token');
//       _speak('Vui lòng giữ nguyên trong 2 giây');
//
//       _captureTimer = Timer(const Duration(seconds: 2), () async {
//         if (!mounted) {
//           _log('COUNTDOWN ABORT token=$token reason=not mounted');
//           return;
//         }
//         if (token != _countdownToken) {
//           _log('COUNTDOWN ABORT token=$token reason=stale token');
//           return;
//         }
//         if (!_isCountingDown) {
//           _log('COUNTDOWN ABORT token=$token reason=countdown reset');
//           return;
//         }
//         if (_isTakingShot) {
//           _log('COUNTDOWN ABORT token=$token reason=already taking');
//           return;
//         }
//
//         _isTakingShot = true;
//
//         if (mounted) {
//           setState(() {
//             _statusText = 'Đang chụp ảnh...';
//           });
//         }
//
//         try {
//           await _stopImageStreamIfNeeded();
//           await Future.delayed(const Duration(milliseconds: 300));
//           await _capturePhoto();
//         } catch (e, st) {
//           _log('capture timer error: $e');
//           _log('$st');
//           _isTakingShot = false;
//           _resetCaptureState();
//
//           if (_controller != null &&
//               _controller!.value.isInitialized &&
//               !_controller!.value.isStreamingImages) {
//             await _startImageStream();
//           }
//         }
//       });
//     } catch (e, st) {
//       _log('_processCameraImage error: $e');
//       _log('$st');
//     } finally {
//       _isProcessing = false;
//     }
//   }
//
//   bool _isPoseMatched(double yaw) {
//     switch (widget.mode) {
//       case FaceCaptureMode.front:
//         return yaw.abs() < 14;
//       case FaceCaptureMode.left:
//         return yaw < -18;
//       case FaceCaptureMode.right:
//         return yaw > 18;
//     }
//   }
//
//   (double, double) _getFaceCenterOffsets(Face face, CameraImage image) {
//     final center = face.boundingBox.center;
//     final offsetX = (center.dx - image.width / 2).abs() / image.width;
//     final offsetY = (center.dy - image.height / 2).abs() / image.height;
//     return (offsetX, offsetY);
//   }
//
//   bool _isFaceCentered(double offsetX, double offsetY) {
//     return offsetX < 0.20 && offsetY < 0.25;
//   }
//
//   String _initialInstruction() {
//     switch (widget.mode) {
//       case FaceCaptureMode.front:
//         return 'Đưa mặt vào camera và nhìn thẳng';
//       case FaceCaptureMode.left:
//         return 'Đưa mặt vào camera và quay sang trái';
//       case FaceCaptureMode.right:
//         return 'Đưa mặt vào camera và quay sang phải';
//     }
//   }
//
//   String _getDynamicPoseInstruction({
//     required double yaw,
//     required bool isFaceLargeEnough,
//     required bool isCenterOk,
//   }) {
//     if (!isFaceLargeEnough) {
//       return 'Đưa mặt lại gần hơn một chút';
//     }
//
//     if (!isCenterOk) {
//       return 'Đưa mặt vào gần giữa màn hình hơn';
//     }
//
//     switch (widget.mode) {
//       case FaceCaptureMode.front:
//         if (yaw > 14) return 'Quay mặt về giữa từ từ sang trái';
//         if (yaw < -14) return 'Quay mặt về giữa từ từ sang phải';
//         return 'Vui lòng nhìn thẳng vào camera';
//
//       case FaceCaptureMode.left:
//         if (yaw > -10) return 'Quay sang trái thêm một chút';
//         if (yaw > -18) return 'Quay sang trái thêm';
//         return 'Vui lòng quay sang trái';
//
//       case FaceCaptureMode.right:
//         if (yaw < 10) return 'Quay sang phải thêm một chút';
//         if (yaw < 18) return 'Quay sang phải thêm';
//         return 'Vui lòng quay sang phải';
//     }
//   }
//
//   Future<void> _speak(String text) async {
//     try {
//       _log('TTS: $text');
//       await _tts.stop();
//       await _tts.speak(text);
//     } catch (e, st) {
//       _log('tts error: $e');
//       _log('$st');
//     }
//   }
//
//   void _resetCaptureState() {
//     if (_captureTimer != null || _isCountingDown) {
//       _log('RESET STATE token=$_countdownToken');
//     }
//     _countdownToken++;
//     _captureTimer?.cancel();
//     _captureTimer = null;
//     _isCountingDown = false;
//   }
//
//   double _getFaceRatio(Face face, CameraImage image) {
//     final box = face.boundingBox;
//     return (box.width * box.height) / (image.width * image.height);
//   }
//
//   InputImage? _convertCameraImageToInputImage(CameraImage image) {
//     try {
//       final controller = _controller;
//       if (controller == null) return null;
//
//       final WriteBuffer allBytes = WriteBuffer();
//       for (final plane in image.planes) {
//         allBytes.putUint8List(plane.bytes);
//       }
//
//       return InputImage.fromBytes(
//         bytes: allBytes.done().buffer.asUint8List(),
//         metadata: InputImageMetadata(
//           size: Size(image.width.toDouble(), image.height.toDouble()),
//           rotation: InputImageRotationValue.fromRawValue(
//             controller.description.sensorOrientation,
//           ) ??
//               InputImageRotation.rotation0deg,
//           format: InputImageFormat.yuv420,
//           bytesPerRow: image.planes.first.bytesPerRow,
//         ),
//       );
//     } catch (e, st) {
//       _log('_convert error: $e');
//       _log('$st');
//       return null;
//     }
//   }
//
//   Future<void> _capturePhoto() async {
//     try {
//       if (_controller == null) return;
//       if (!_controller!.value.isInitialized) return;
//       if (_controller!.value.isTakingPicture) return;
//
//       _log('CAPTURE START step=$_stepLabel');
//
//       final imageFile = await _controller!.takePicture();
//
//       _log('CAPTURE DONE step=$_stepLabel path=${imageFile.path}');
//
//       _stableFrames = 0;
//       _resetCaptureState();
//       _isTakingShot = false;
//
//       if (!mounted) return;
//
//       setState(() {
//         _statusText = 'Đã chụp thành công';
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Đã chụp ảnh thành công')),
//       );
//
//       await _speak('Đã chụp thành công');
//
//       if (!mounted) return;
//       Navigator.of(context).pop(imageFile.path);
//     } catch (e, st) {
//       _log('_capturePhoto error: $e');
//       _log('$st');
//       _isTakingShot = false;
//       _resetCaptureState();
//
//       if (_controller != null &&
//           _controller!.value.isInitialized &&
//           !_controller!.value.isStreamingImages) {
//         await _startImageStream();
//       }
//     }
//   }
//
//   void _setError(String message) {
//     _log('ERROR: $message');
//     if (!mounted) return;
//     setState(() {
//       _errorText = message;
//       _isInitializing = false;
//     });
//   }
//
//   @override
//   void dispose() {
//     _log('DISPOSE');
//     _captureTimer?.cancel();
//     _tts.stop();
//     _faceDetector.close();
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   Widget _buildDebugInfo() {
//     return Positioned(
//       top: 60,
//       left: 12,
//       right: 12,
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color: Colors.black54,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: DefaultTextStyle(
//           style: const TextStyle(color: Colors.white, fontSize: 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('step: $_stepLabel'),
//               Text('faces: $_detectedFaceCount'),
//               Text('yaw: ${_lastYaw?.toStringAsFixed(2) ?? "--"}'),
//               Text('ratio: ${_lastFaceRatio.toStringAsFixed(3)}'),
//               Text('centerX: ${_lastCenterOffsetX.toStringAsFixed(3)}'),
//               Text('centerY: ${_lastCenterOffsetY.toStringAsFixed(3)}'),
//               Text('poseMatched: $_debugPoseMatched'),
//               Text('largeEnough: $_debugLargeEnough'),
//               Text('centerOk: $_debugCenterOk'),
//               Text('stableFrames: $_stableFrames/$_requiredStableFrames'),
//               Text('countdownToken: $_countdownToken'),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomStatus() {
//     return Positioned(
//       left: 16,
//       right: 16,
//       bottom: 24,
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: Colors.black54,
//           borderRadius: BorderRadius.circular(14),
//         ),
//         child: Text(
//           _statusText,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: Colors.white, fontSize: 15),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_errorText != null) {
//       return Scaffold(
//         body: Center(child: Text(_errorText!)),
//       );
//     }
//
//     if (_isInitializing || _controller == null) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     final size = MediaQuery.of(context).size;
//
//     final previewSize = _controller!.value.previewSize;
//     final previewWidth = previewSize?.height ?? size.width;
//     final previewHeight = previewSize?.width ?? size.height;
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: ClipRect(
//               child: FittedBox(
//                 fit: BoxFit.cover,
//                 child: SizedBox(
//                   width: previewWidth,
//                   height: previewHeight,
//                   child: CameraPreview(_controller!),
//                 ),
//               ),
//             ),
//           ),
//           if (widget.showDebugInfo) _buildDebugInfo(),
//           _buildBottomStatus(),
//         ],
//       ),
//     );
//   }
// }