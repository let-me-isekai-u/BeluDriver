import 'package:flutter/material.dart';

import 'face_capture_mode.dart';
import 'single_face_capture_screen.dart';

class LeftFaceCaptureScreen extends StatelessWidget {
  const LeftFaceCaptureScreen({
    super.key,
    this.showDebugInfo = true,
  });

  final bool showDebugInfo;

  @override
  Widget build(BuildContext context) {
    return SingleFaceCaptureScreen(
      mode: FaceCaptureMode.left,
      showDebugInfo: showDebugInfo,
    );
  }
}