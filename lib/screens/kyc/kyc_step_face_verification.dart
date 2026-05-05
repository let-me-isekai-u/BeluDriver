import 'dart:io';

import 'package:beludriver_app/screens/face_detection/front_face_capture_screen.dart';
import 'package:beludriver_app/screens/face_detection/left_face_capture_screen.dart';
import 'package:beludriver_app/screens/face_detection/right_face_capture_screen.dart';
import 'package:beludriver_app/services/permission_service.dart';
import 'package:flutter/material.dart';

class KycStepFaceVerification extends StatefulWidget {
  final File? initialFaceLeft;
  final File? initialFaceFront;
  final File? initialFaceRight;
  final VoidCallback onBack;
  final bool isSubmitting;
  final void Function(
      File faceLeft,
      File faceFront,
      File faceRight,
      ) onConfirmed;

  const KycStepFaceVerification({
    super.key,
    required this.initialFaceLeft,
    required this.initialFaceFront,
    required this.initialFaceRight,
    required this.onBack,
    required this.onConfirmed,
    this.isSubmitting = false,
  });

  @override
  State<KycStepFaceVerification> createState() =>
      _KycStepFaceVerificationState();
}

class _KycStepFaceVerificationState extends State<KycStepFaceVerification> {
  File? _faceLeft;
  File? _faceFront;
  File? _faceRight;

  @override
  void initState() {
    super.initState();
    _faceLeft = widget.initialFaceLeft;
    _faceFront = widget.initialFaceFront;
    _faceRight = widget.initialFaceRight;
  }

  Future<bool> _ensureCameraPermission() async {
    final granted = await PermissionService.ensureCamera();

    if (!mounted) return false;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần cấp quyền camera để chụp ảnh khuôn mặt'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return granted;
  }

  Future<void> _captureFaceFront() async {
    if (widget.isSubmitting) return;

    final granted = await _ensureCameraPermission();
    if (!granted) return;

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const FrontFaceCaptureScreen(
          showDebugInfo: false,
        ),
      ),
    );

    if (!mounted || imagePath == null || imagePath.isEmpty) return;

    setState(() {
      _faceFront = File(imagePath);
    });
  }

  Future<void> _captureFaceLeft() async {
    if (widget.isSubmitting) return;

    final granted = await _ensureCameraPermission();
    if (!granted) return;

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const LeftFaceCaptureScreen(
          showDebugInfo: false,
        ),
      ),
    );

    if (!mounted || imagePath == null || imagePath.isEmpty) return;

    setState(() {
      _faceLeft = File(imagePath);
    });
  }

  Future<void> _captureFaceRight() async {
    if (widget.isSubmitting) return;

    final granted = await _ensureCameraPermission();
    if (!granted) return;

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const RightFaceCaptureScreen(
          showDebugInfo: false,
        ),
      ),
    );

    if (!mounted || imagePath == null || imagePath.isEmpty) return;

    setState(() {
      _faceRight = File(imagePath);
    });
  }

  void _confirm() {
    if (widget.isSubmitting) return;

    if (_faceLeft == null || _faceFront == null || _faceRight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chụp đủ 3 ảnh khuôn mặt: trái, chính diện, phải.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onConfirmed(_faceLeft!, _faceFront!, _faceRight!);
  }

  Widget _buildPicker({
    required String title,
    required String hint,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (file != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 13,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Đã chụp ảnh',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: widget.isSubmitting ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: file != null ? colorScheme.primary : Colors.grey.shade300,
                width: file != null ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: file != null ? Colors.transparent : Colors.grey.shade50,
            ),
            child: file == null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nhấn để mở camera',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chụp đúng góc khuôn mặt yêu cầu',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool allSelected =
        _faceLeft != null && _faceFront != null && _faceRight != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Bước 6/6',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 6 / 6,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Xác nhận khuôn mặt',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chụp 3 góc khuôn mặt: nhìn thẳng, quay trái và quay phải.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 24),

          _buildPicker(
            title: 'Khuôn mặt chính diện',
            hint: 'Nhìn thẳng vào camera, không nghiêng đầu',
            icon: Icons.face,
            file: _faceFront,
            onTap: _captureFaceFront,
          ),
          const SizedBox(height: 16),

          _buildPicker(
            title: 'Khuôn mặt bên trái',
            hint: 'Quay đầu sang trái khoảng 45°',
            icon: Icons.arrow_back,
            file: _faceLeft,
            onTap: _captureFaceLeft,
          ),
          const SizedBox(height: 16),

          _buildPicker(
            title: 'Khuôn mặt bên phải',
            hint: 'Quay đầu sang phải khoảng 45°',
            icon: Icons.arrow_forward,
            file: _faceRight,
            onTap: _captureFaceRight,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.isSubmitting ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.isSubmitting
                      ? null
                      : _faceFront == null
                      ? _captureFaceFront
                      : _faceLeft == null
                      ? _captureFaceLeft
                      : _faceRight == null
                      ? _captureFaceRight
                      : _captureFaceFront,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    _faceFront == null
                        ? 'Chụp ảnh chính diện'
                        : _faceLeft == null
                        ? 'Chụp ảnh bên trái'
                        : _faceRight == null
                        ? 'Chụp ảnh bên phải'
                        : 'Chụp lại ảnh',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                  (allSelected && !widget.isSubmitting) ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: widget.isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}