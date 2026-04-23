import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class KycStepDriverLicense extends StatefulWidget {
  final File? initialFile;
  final VoidCallback onBack;
  final ValueChanged<File> onConfirmed;

  const KycStepDriverLicense({
    super.key,
    required this.initialFile,
    required this.onBack,
    required this.onConfirmed,
  });

  @override
  State<KycStepDriverLicense> createState() => _KycStepDriverLicenseState();
}

class _KycStepDriverLicenseState extends State<KycStepDriverLicense> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.initialFile;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _selectedFile = File(picked.path));
  }

  void _confirm() {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ảnh giấy phép lái xe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onConfirmed(_selectedFile!);
  }

  Widget _buildPicker() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Giấy phép lái xe',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_selectedFile != null) ...[
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
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFile != null
                    ? colorScheme.primary
                    : Colors.grey.shade300,
                width: _selectedFile != null ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: _selectedFile != null
                  ? Colors.transparent
                  : Colors.grey.shade50,
            ),
            child: _selectedFile == null
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
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: colorScheme.primary,
                  ),
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
                    color: Colors.white,
                  ),
                ),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedFile!,
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
    final bool selected = _selectedFile != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Bước 3/6',
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
                    value: 3 / 6,
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
            'Cung cấp giấy phép lái xe',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vui lòng chọn ảnh giấy phép lái xe rõ nét, không bị mờ hoặc lóa sáng.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 24),
          _buildPicker(),
          const SizedBox(height: 24),
          Row(
            children: [
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    _selectedFile == null ? 'Chọn ảnh' : 'Chọn lại ảnh',
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
                  onPressed: selected ? _confirm : null,
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