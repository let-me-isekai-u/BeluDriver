import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class KycStepCitizenCard extends StatefulWidget {
  final File? initialFrontFile;
  final File? initialBackFile;
  final VoidCallback onBack;
  final void Function(File frontFile, File backFile) onConfirmed;

  const KycStepCitizenCard({
    super.key,
    required this.initialFrontFile,
    required this.initialBackFile,
    required this.onBack,
    required this.onConfirmed,
  });

  @override
  State<KycStepCitizenCard> createState() => _KycStepCitizenCardState();
}

class _KycStepCitizenCardState extends State<KycStepCitizenCard> {
  final ImagePicker _picker = ImagePicker();

  File? _frontFile;
  File? _backFile;

  @override
  void initState() {
    super.initState();
    _frontFile = widget.initialFrontFile;
    _backFile = widget.initialBackFile;
  }

  Future<void> _pickFront() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _frontFile = File(picked.path));
  }

  Future<void> _pickBack() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _backFile = File(picked.path));
  }

  void _confirm() {
    if (_frontFile == null || _backFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đủ ảnh mặt trước và mặt sau CCCD.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onConfirmed(_frontFile!, _backFile!);
  }

  Widget _buildPicker({
    required String title,
    required String subtitle,
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
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 160,
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
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhấn để chọn ảnh',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
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
    final bool allSelected = _frontFile != null && _backFile != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Progress indicator ──────────────────────────────────────
          Row(
            children: [
              Text(
                'Bước 5/6',
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
                    value: 5 / 6,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Title & subtitle ────────────────────────────────────────
          const Text(
            'Cung cấp ảnh CCCD',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Vui lòng chọn ảnh mặt trước và mặt sau căn cước công dân.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),

          const SizedBox(height: 24),

          // ── Pickers ─────────────────────────────────────────────────
          _buildPicker(
            title: 'Mặt trước CCCD',
            subtitle: 'Mặt có ảnh chân dung & số CCCD',
            icon: Icons.person_outline,
            file: _frontFile,
            onTap: _pickFront,
          ),
          const SizedBox(height: 16),
          _buildPicker(
            title: 'Mặt sau CCCD',
            subtitle: 'Mặt có mã QR & vân tay',
            icon: Icons.qr_code_outlined,
            file: _backFile,
            onTap: _pickBack,
          ),

          const SizedBox(height: 24),

          // ── Bottom action row ───────────────────────────────────────
          Row(
            children: [
              // Quay lại
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ),

              const SizedBox(width: 12),

              // Chọn ảnh
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _frontFile == null ? _pickFront : _pickBack,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    _frontFile == null
                        ? 'Chọn mặt trước'
                        : _backFile == null
                        ? 'Chọn mặt sau'
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

              // Xác nhận — nút mũi tên tròn
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: allSelected ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_forward, size: 22),
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