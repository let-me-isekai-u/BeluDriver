import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/kyc/kyc_provider.dart';
import 'kyc_step_citizen_card.dart';
import 'kyc_step_driver_license.dart';
import 'kyc_step_face_verification.dart';
import 'kyc_step_portrait.dart';
import 'kyc_step_vehicle_photo.dart';
import 'kyc_step_vehicle_registration.dart';
import 'kyc_submit_success_popup.dart';
import 'resubmit_kyc_notification.dart';

class KycPopup extends StatefulWidget {
  const KycPopup({super.key});

  @override
  State<KycPopup> createState() => _KycPopupState();
}

class _KycPopupState extends State<KycPopup> {
  int _currentStep = 0;

  File? _vehiclePhoto;
  File? _portrait;
  File? _driverLicense;
  File? _vehicleRegistration;
  File? _citizenFront;
  File? _citizenBack;
  File? _faceFront;
  File? _faceRight;
  File? _faceLeft;

  String _accessToken = "";
  bool _didShowRejectedNotice = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString("accessToken") ?? "";

    if (_accessToken.isEmpty) {
      debugPrint('[KYC_POPUP] access token missing');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy access token. Vui lòng đăng nhập lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final kycProvider = context.read<KycProvider>();

    await kycProvider.fetchKyc(_accessToken);

    if (!mounted) return;

    if (kycProvider.kycStatus == 3 && !_didShowRejectedNotice) {
      _didShowRejectedNotice = true;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ResubmitKycNotification(
          rejectReason: kycProvider.kycRejectReason,
        ),
      );
    }

    final ok = await kycProvider.initKycSession(_accessToken);

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kycProvider.errorMessage ?? 'Không thể khởi tạo phiên KYC.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _resumeToStep(kycProvider);
    }
  }

  void _resumeToStep(KycProvider provider) {
    if (!provider.isBatchCompleted('vehicle_basic')) {
      _jumpToStep(0);
    } else if (!provider.isBatchCompleted('vehicle_docs')) {
      _jumpToStep(2);
    } else if (!provider.isBatchCompleted('identity_docs')) {
      _jumpToStep(4);
    } else if (!provider.isBatchCompleted('face_verification')) {
      _jumpToStep(5);
    }
  }

  void _jumpToStep(int step) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
    });
  }

  void _goToNextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _goToPreviousStep() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep--;
    });
  }

  Future<void> _uploadVehicleBasicAndContinue() async {
    if (_vehiclePhoto == null || _portrait == null) {
      _showError('Vui lòng chọn đủ ảnh xe và ảnh chân dung.');
      return;
    }

    final kycProvider = context.read<KycProvider>();
    final success = await kycProvider.uploadBatchVehicleBasic(
      accessToken: _accessToken,
      vehiclePhoto: _vehiclePhoto!,
      portrait: _portrait!,
    );

    if (!mounted) return;

    if (success) {
      _goToNextStep();
    } else {
      _showError(
        kycProvider.errorMessage ?? 'Upload ảnh xe thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _uploadVehicleDocsAndContinue() async {
    if (_driverLicense == null || _vehicleRegistration == null) {
      _showError('Vui lòng chọn đủ giấy phép lái xe và đăng ký xe.');
      return;
    }

    final kycProvider = context.read<KycProvider>();
    final success = await kycProvider.uploadBatchVehicleDocs(
      accessToken: _accessToken,
      vehicleRegistration: _vehicleRegistration!,
      driverLicense: _driverLicense!,
    );

    if (!mounted) return;

    if (success) {
      _goToNextStep();
    } else {
      _showError(
        kycProvider.errorMessage ??
            'Upload giấy tờ xe thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _uploadIdentityDocsAndContinue() async {
    if (_citizenFront == null || _citizenBack == null) {
      _showError('Vui lòng chọn đủ mặt trước và mặt sau CCCD.');
      return;
    }

    final kycProvider = context.read<KycProvider>();
    final success = await kycProvider.uploadBatchIdentityDocs(
      accessToken: _accessToken,
      citizenFront: _citizenFront!,
      citizenBack: _citizenBack!,
    );

    if (!mounted) return;

    if (success) {
      _goToNextStep();
    } else {
      _showError(
        kycProvider.errorMessage ?? 'Upload CCCD thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _uploadFaceAndSubmit() async {
    if (_faceFront == null || _faceRight == null || _faceLeft == null) {
      _showError('Vui lòng chụp đủ 3 góc khuôn mặt.');
      return;
    }

    final kycProvider = context.read<KycProvider>();

    final uploadOk = await kycProvider.uploadBatchFaceVerification(
      accessToken: _accessToken,
      faceFront: _faceFront!,
      faceRight: _faceRight!,
      faceLeft: _faceLeft!,
    );

    if (!mounted) return;

    if (!uploadOk) {
      _showError(
        kycProvider.errorMessage ??
            'Upload ảnh khuôn mặt thất bại. Vui lòng thử lại.',
      );
      return;
    }

    final submitOk = await kycProvider.submitKycSession(_accessToken);

    if (!mounted) return;

    if (submitOk) {
      debugPrint('[KYC_POPUP] Submit success → close popup, show thanks');
      Navigator.of(context).pop();

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const KycSubmitSuccessPopup(),
      );
    } else {
      _showError(kycProvider.errorMessage ?? 'Gửi KYC thất bại. Vui lòng thử lại.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KycProvider>();
    final isBlocking = provider.isInitializingSession ||
        provider.isUploadingBatch ||
        provider.isSubmitting ||
        provider.isLoading;

    Widget content;

    switch (_currentStep) {
      case 0:
        content = KycStepVehiclePhoto(
          initialFile: _vehiclePhoto,
          onConfirmed: (file) {
            setState(() => _vehiclePhoto = file);
            _goToNextStep();
          },
        );
        break;

      case 1:
        content = KycStepPortrait(
          initialFile: _portrait,
          onBack: _goToPreviousStep,
          onConfirmed: (file) {
            setState(() => _portrait = file);
            _uploadVehicleBasicAndContinue();
          },
        );
        break;

      case 2:
        content = KycStepDriverLicense(
          initialFile: _driverLicense,
          onBack: _goToPreviousStep,
          onConfirmed: (file) {
            setState(() => _driverLicense = file);
            _goToNextStep();
          },
        );
        break;

      case 3:
        content = KycStepVehicleRegistration(
          initialFile: _vehicleRegistration,
          onBack: _goToPreviousStep,
          onConfirmed: (file) {
            setState(() => _vehicleRegistration = file);
            _uploadVehicleDocsAndContinue();
          },
        );
        break;

      case 4:
        content = KycStepCitizenCard(
          initialFrontFile: _citizenFront,
          initialBackFile: _citizenBack,
          onBack: _goToPreviousStep,
          onConfirmed: (frontFile, backFile) {
            setState(() {
              _citizenFront = frontFile;
              _citizenBack = backFile;
            });
            _uploadIdentityDocsAndContinue();
          },
        );
        break;

      case 5:
        content = KycStepFaceVerification(
          initialFaceLeft: _faceLeft,
          initialFaceFront: _faceFront,
          initialFaceRight: _faceRight,
          onBack: _goToPreviousStep,
          isSubmitting: provider.isUploadingBatch || provider.isSubmitting,
          onConfirmed: (faceLeft, faceFront, faceRight) {
            setState(() {
              _faceLeft = faceLeft;
              _faceFront = faceFront;
              _faceRight = faceRight;
            });
            _uploadFaceAndSubmit();
          },
        );
        break;

      default:
        content = const SizedBox.shrink();
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: content,
            ),
          ),
          if (isBlocking)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _loadingLabel(provider),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _loadingLabel(KycProvider provider) {
    if (provider.isLoading) return 'Đang tải thông tin KYC...';
    if (provider.isInitializingSession) return 'Đang khởi tạo phiên...';
    if (provider.isSubmitting) return 'Đang gửi KYC...';
    if (provider.isUploadingBatch) {
      switch (provider.uploadingBatchCode) {
        case 'vehicle_basic':
          return 'Đang tải ảnh xe & chân dung...';
        case 'vehicle_docs':
          return 'Đang tải giấy tờ xe...';
        case 'identity_docs':
          return 'Đang tải CCCD...';
        case 'face_verification':
          return 'Đang tải ảnh khuôn mặt...';
        default:
          return 'Đang tải ảnh...';
      }
    }
    return 'Đang xử lý...';
  }
}