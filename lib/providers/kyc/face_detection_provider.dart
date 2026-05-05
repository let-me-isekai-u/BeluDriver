import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum CaptureStep {
  front,
  left,
  right,
  done,
}

class FaceDetectionProvider extends ChangeNotifier {
  bool isInitializing = true;
  bool isStreaming = false;
  bool isProcessing = false;
  bool isCountingDown = false;
  bool isTakingShot = false;

  String statusText = 'Đang khởi tạo camera...';
  String? errorText;

  double? lastYaw;
  int detectedFaceCount = 0;
  double lastFaceRatio = 0;
  double lastCenterOffsetX = 0;
  double lastCenterOffsetY = 0;

  bool debugPoseMatched = false;
  bool debugLargeEnough = false;
  bool debugCenterOk = false;

  int stableFrames = 0;
  static const int requiredStableFrames = 5;
  int countdownToken = 0;

  CaptureStep currentStep = CaptureStep.front;

  String? frontImagePath;
  String? leftImagePath;
  String? rightImagePath;

  String get stepLabel {
    switch (currentStep) {
      case CaptureStep.front:
        return 'front';
      case CaptureStep.left:
        return 'left';
      case CaptureStep.right:
        return 'right';
      case CaptureStep.done:
        return 'done';
    }
  }

  bool get isDone => currentStep == CaptureStep.done;

  void setInitializing(bool value) {
    isInitializing = value;
    notifyListeners();
  }

  void setStreaming(bool value) {
    isStreaming = value;
    notifyListeners();
  }

  void setProcessing(bool value) {
    isProcessing = value;
    notifyListeners();
  }

  void setCountingDown(bool value) {
    isCountingDown = value;
    notifyListeners();
  }

  void setTakingShot(bool value) {
    isTakingShot = value;
    notifyListeners();
  }

  void setStatusText(String value) {
    if (statusText == value) return;
    statusText = value;
    notifyListeners();
  }

  void setError(String message) {
    errorText = message;
    isInitializing = false;
    notifyListeners();
  }

  void clearError() {
    errorText = null;
    notifyListeners();
  }

  void markCameraReady() {
    isInitializing = false;
    statusText = initialInstruction();
    notifyListeners();
  }

  void resetDetectionDebug() {
    lastYaw = null;
    lastFaceRatio = 0;
    lastCenterOffsetX = 0;
    lastCenterOffsetY = 0;
    debugPoseMatched = false;
    debugLargeEnough = false;
    debugCenterOk = false;
    notifyListeners();
  }

  void updateFaceCount(int count) {
    detectedFaceCount = count;
    notifyListeners();
  }

  void updateDetectionState({
    required double yaw,
    required double ratio,
    required double centerOffsetX,
    required double centerOffsetY,
    required bool isPoseMatched,
    required bool isFaceLargeEnough,
    required bool isCenterOk,
    required int faceCount,
  }) {
    lastYaw = yaw;
    lastFaceRatio = ratio;
    lastCenterOffsetX = centerOffsetX;
    lastCenterOffsetY = centerOffsetY;
    debugPoseMatched = isPoseMatched;
    debugLargeEnough = isFaceLargeEnough;
    debugCenterOk = isCenterOk;
    detectedFaceCount = faceCount;
    notifyListeners();
  }

  void resetCaptureState() {
    countdownToken++;
    isCountingDown = false;
    stableFrames = 0;
    notifyListeners();
  }

  int startCountdown() {
    isCountingDown = true;
    stableFrames = 0;
    countdownToken++;
    notifyListeners();
    return countdownToken;
  }

  void increaseStableFrames() {
    stableFrames++;
    notifyListeners();
  }

  void resetStableFrames() {
    if (stableFrames == 0) return;
    stableFrames = 0;
    notifyListeners();
  }

  bool hasEnoughStableFrames() {
    return stableFrames >= requiredStableFrames;
  }

  bool isPoseMatched(double yaw) {
    switch (currentStep) {
      case CaptureStep.front:
        return yaw.abs() < 14;
      case CaptureStep.left:
        return yaw < -18;
      case CaptureStep.right:
        return yaw > 18;
      case CaptureStep.done:
        return false;
    }
  }

  (double, double) getFaceCenterOffsets(Face face, int imageWidth, int imageHeight) {
    final center = face.boundingBox.center;
    final offsetX = (center.dx - imageWidth / 2).abs() / imageWidth;
    final offsetY = (center.dy - imageHeight / 2).abs() / imageHeight;
    return (offsetX, offsetY);
  }

  bool isFaceCentered(double offsetX, double offsetY) {
    return offsetX < 0.20 && offsetY < 0.25;
  }

  double getFaceRatio(Face face, int imageWidth, int imageHeight) {
    final box = face.boundingBox;
    return (box.width * box.height) / (imageWidth * imageHeight);
  }

  bool isFaceLargeEnough(double ratio) {
    return ratio > 0.06;
  }

  bool isStillValid({
    required double yaw,
    required double ratio,
    required double centerOffsetX,
    required double centerOffsetY,
  }) {
    final pose = isPoseMatched(yaw);
    final large = isFaceLargeEnough(ratio);
    final center = isFaceCentered(centerOffsetX, centerOffsetY);
    return pose && large && center;
  }

  String initialInstruction() {
    switch (currentStep) {
      case CaptureStep.front:
        return 'Đưa mặt vào camera và nhìn thẳng';
      case CaptureStep.left:
        return 'Đưa mặt vào camera và quay sang trái';
      case CaptureStep.right:
        return 'Đưa mặt vào camera và quay sang phải';
      case CaptureStep.done:
        return 'Đã hoàn tất';
    }
  }

  String getDynamicPoseInstruction({
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

    switch (currentStep) {
      case CaptureStep.front:
        if (yaw > 14) return 'Quay mặt về giữa từ từ sang trái';
        if (yaw < -14) return 'Quay mặt về giữa từ từ sang phải';
        return 'Vui lòng nhìn thẳng vào camera';

      case CaptureStep.left:
        if (yaw > -10) return 'Quay sang trái thêm một chút';
        if (yaw > -18) return 'Quay sang trái thêm';
        return 'Vui lòng quay sang trái';

      case CaptureStep.right:
        if (yaw < 10) return 'Quay sang phải thêm một chút';
        if (yaw < 18) return 'Quay sang phải thêm';
        return 'Vui lòng quay sang phải';

      case CaptureStep.done:
        return 'Đã hoàn tất';
    }
  }

  void saveCapturedImagePath(String path) {
    switch (currentStep) {
      case CaptureStep.front:
        frontImagePath = path;
        break;
      case CaptureStep.left:
        leftImagePath = path;
        break;
      case CaptureStep.right:
        rightImagePath = path;
        break;
      case CaptureStep.done:
        break;
    }
    notifyListeners();
  }

  void moveToNextStep() {
    switch (currentStep) {
      case CaptureStep.front:
        currentStep = CaptureStep.left;
        statusText = 'Đã chụp chính diện. Vui lòng quay sang trái';
        break;
      case CaptureStep.left:
        currentStep = CaptureStep.right;
        statusText = 'Đã chụp bên trái. Vui lòng quay sang phải';
        break;
      case CaptureStep.right:
        currentStep = CaptureStep.done;
        statusText = 'Đã chụp đủ 3 ảnh';
        break;
      case CaptureStep.done:
        break;
    }
    notifyListeners();
  }

  void resetAll() {
    isInitializing = true;
    isStreaming = false;
    isProcessing = false;
    isCountingDown = false;
    isTakingShot = false;

    statusText = 'Đang khởi tạo camera...';
    errorText = null;

    lastYaw = null;
    detectedFaceCount = 0;
    lastFaceRatio = 0;
    lastCenterOffsetX = 0;
    lastCenterOffsetY = 0;

    debugPoseMatched = false;
    debugLargeEnough = false;
    debugCenterOk = false;

    stableFrames = 0;
    countdownToken = 0;

    currentStep = CaptureStep.front;

    frontImagePath = null;
    leftImagePath = null;
    rightImagePath = null;

    notifyListeners();
  }

  Map<String, String?> get capturedImages => {
    'front': frontImagePath,
    'left': leftImagePath,
    'right': rightImagePath,
  };
}