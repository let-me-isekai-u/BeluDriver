import 'package:flutter/material.dart';

import 'face_capture_mode.dart';
import 'single_face_capture_screen.dart';

class RightFaceCaptureScreen extends StatelessWidget {
  const RightFaceCaptureScreen({
    super.key,
    this.showDebugInfo = true,
  });

  final bool showDebugInfo;

  @override
  Widget build(BuildContext context) {
    return SingleFaceCaptureScreen(
      mode: FaceCaptureMode.right,
      showDebugInfo: showDebugInfo,
    );
  }
}