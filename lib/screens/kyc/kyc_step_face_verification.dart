import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();

  // face_left  = nghiêng sang trái (người dùng nhìn sang trái)
  // face_front = chính diện
  // face_right = nghiêng sang phải (người dùng nhìn sang phải)
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

  Future<void> _pickFaceLeft() async {
    if (widget.isSubmitting) return;
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _faceLeft = File(picked.path));
  }

  Future<void> _pickFaceFront() async {
    if (widget.isSubmitting) return;
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _faceFront = File(picked.path));
  }

  Future<void> _pickFaceRight() async {
    if (widget.isSubmitting) return;
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _faceRight = File(picked.path));
  }

  void _confirm() {
    if (widget.isSubmitting) return;

    if (_faceLeft == null || _faceFront == null || _faceRight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn đủ 3 ảnh khuôn mặt: trái, chính diện, phải.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Thứ tự callback: faceLeft, faceFront, faceRight
    // khớp với kyc_popup.dart: onConfirmed: (faceLeft, faceFront, faceRight)
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
              style: TextStyle(
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
                    Icon(Icons.check_circle_outline,
                        size: 13, color: Colors.green.shade600),
                    const SizedBox(width: 3),
                    Text(
                      'Đã chọn ảnh',
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
        // Hint mô tả cách chụp
        Text(
          hint,
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: widget.isSubmitting ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color:
                file != null ? colorScheme.primary : Colors.grey.shade300,
                width: file != null ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color:
              file != null ? Colors.transparent : Colors.grey.shade50,
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
                  child: Icon(icon, size: 28, color: colorScheme.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nhấn để chọn ảnh',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPG, PNG · Tối đa 10MB',
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
          // ── Progress ─────────────────────────────────────────────────
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

          // ── Title ────────────────────────────────────────────────────
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

          // ── face_front: chính diện ───────────────────────────────────
          _buildPicker(
            title: 'Khuôn mặt chính diện',
            hint: 'Nhìn thẳng vào camera, không nghiêng đầu',
            icon: Icons.face,
            file: _faceFront,
            onTap: _pickFaceFront,
          ),
          const SizedBox(height: 16),

          // ── face_left: người dùng quay sang trái ────────────────────
          _buildPicker(
            title: 'Khuôn mặt bên trái',
            hint: 'Quay đầu sang trái khoảng 45°',
            icon: Icons.arrow_back,
            file: _faceLeft,
            onTap: _pickFaceLeft,
          ),
          const SizedBox(height: 16),

          // ── face_right: người dùng quay sang phải ───────────────────
          _buildPicker(
            title: 'Khuôn mặt bên phải',
            hint: 'Quay đầu sang phải khoảng 45°',
            icon: Icons.arrow_forward,
            file: _faceRight,
            onTap: _pickFaceRight,
          ),

          const SizedBox(height: 24),

          // ── Bottom action row ────────────────────────────────────────
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
                      ? _pickFaceFront
                      : _faceLeft == null
                      ? _pickFaceLeft
                      : _faceRight == null
                      ? _pickFaceRight
                      : _pickFaceFront,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    _faceFront == null
                        ? 'Chọn ảnh chính diện'
                        : _faceLeft == null
                        ? 'Chọn ảnh bên trái'
                        : _faceRight == null
                        ? 'Chọn ảnh bên phải'
                        : 'Chọn lại ảnh',
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