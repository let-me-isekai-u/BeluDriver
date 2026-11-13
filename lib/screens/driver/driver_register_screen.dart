import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import 'driver_login_screen.dart';
import '../terms_screen.dart';
import '../../providers/driver/register_provider.dart';
import '../../widgets/driver_ui.dart';
import '../../ui/ui.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterProvider(),
      child: const _RegisterView(),
    );
  }
}

/// Mô tả 3 bước của luồng đăng ký.
class _StepInfo {
  final String label;
  final IconData icon;
  const _StepInfo(this.label, this.icon);
}

const List<_StepInfo> _steps = [
  _StepInfo("Cá nhân", Icons.badge_outlined),
  _StepInfo("Tài khoản", Icons.lock_outline_rounded),
  _StepInfo("Xác nhận", Icons.verified_user_outlined),
  _StepInfo("OTP email", Icons.mark_email_read_outlined),
];

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView>
    with WidgetsBindingObserver {
  int _step = 0;
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _apiErrorKey = GlobalKey();
  final _fieldKeys = {
    for (final field in RegistrationField.values) field: GlobalKey(),
  };
  final _focusNodes = {
    for (final field in RegistrationField.values.where(
      (field) => ![
        RegistrationField.region,
        RegistrationField.terms,
        RegistrationField.camera,
      ].contains(field),
    ))
      field: FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final entry in _focusNodes.entries) {
      entry.value.addListener(() {
        if (entry.value.hasFocus) _ensureVisible(entry.key);
      });
    }
  }

  void _ensureVisible(RegistrationField field) {
    _ensureKeyVisible(_fieldKeys[field]!);
  }

  void _ensureKeyVisible(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 180),
        alignment: 0.2,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeMetrics() {
    for (final entry in _focusNodes.entries) {
      if (entry.value.hasFocus) _ensureVisible(entry.key);
    }
  }

  void _focusNext(RegistrationField field) {
    final fields = RegisterProvider
        .stepFields[RegisterProvider.stepForField(field)]
        .where(_focusNodes.containsKey)
        .toList();
    final index = fields.indexOf(field);
    if (index >= 0 && index + 1 < fields.length) {
      _focusNodes[fields[index + 1]]!.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _revealErrors(RegisterProvider provider) {
    final field = provider.firstInvalidField;
    if (field == null) return;
    setState(() => _step = RegisterProvider.stepForField(field));
    _ensureVisible(field);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isFirst => _step == 0;
  bool get _isLast => _step == _steps.length - 1;

  void _showSnack(BuildContext context, String msg, {Color? color}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: color ?? theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final provider = context.read<RegisterProvider>();
    FocusScope.of(context).unfocus();
    if (!provider.validateAllFields()) {
      _revealErrors(provider);
      return;
    }
    final success = await provider.register(
      onSnack: (msg, {color}) {
        // Field/API errors are already inline; a floating snack can hide CTA.
        if (mounted &&
            provider.firstInvalidField == null &&
            provider.apiError == null) {
          _showSnack(context, msg, color: color);
        }
      },
    );
    if (!mounted) return;
    if (success) {
      _showSnack(context, 'Đăng ký thành công!', color: Brand.navy);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
      );
    } else if (provider.firstInvalidField != null) {
      _revealErrors(provider);
    } else {
      _ensureKeyVisible(_apiErrorKey);
    }
  }

  void _goBack() {
    if (context.read<RegisterProvider>().loading) return;
    FocusScope.of(context).unfocus();
    if (_isFirst) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _goNext() async {
    final provider = context.read<RegisterProvider>();
    if (!provider.canSubmit) return;
    if (!provider.validateStep(_step)) {
      _revealErrors(provider);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step == 2) {
      if (!provider.validateAllFields()) {
        _revealErrors(provider);
        return;
      }
      final sent = await provider.requestRegistrationChallenge();
      if (!mounted) return;
      if (!sent) {
        _ensureKeyVisible(_apiErrorKey);
        return;
      }
      setState(() => _step = 3);
    } else if (!_isLast) {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();
    final loading = provider.loading;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: _isFirst && !loading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Brand.canvas,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (!keyboardOpen) ...[
                    _buildHeader(theme),
                    _StepHeader(current: _step),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: loading ? null : _goBack,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Brand.navy,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _steps[_step].label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          _buildStepContent(context, theme),
                          if (provider.apiError != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              key: _apiErrorKey,
                              liveRegion: true,
                              child: Text(
                                provider.apiError!,
                                style: const TextStyle(color: Brand.danger),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(context, theme, loading),
                ],
              ),
              if (loading)
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(color: Brand.navy),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            style: IconButton.styleFrom(backgroundColor: Brand.b50),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Brand.navy,
            tooltip: _isFirst ? "Quay lại đăng nhập" : "Quay lại bước trước",
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Đăng ký tài khoản",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Brand.ink,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tạo hồ sơ, sau đó làm KYC để nhận đơn.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Brand.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Nội dung từng bước ─────────────────────────

  Widget _buildStepContent(BuildContext context, ThemeData theme) {
    switch (_step) {
      case 0:
        return _buildStepPersonal(context, theme);
      case 1:
        return _buildStepAccount(context, theme);
      case 2:
        return _buildStepConfirm(context, theme);
      default:
        return _buildStepOtp(context, theme);
    }
  }

  Widget _buildStepPersonal(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DriverSectionCard(
          title: "Thông tin cá nhân",
          subtitle: "Tên hiển thị, email và biển số xe.",
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              _ProviderTextField(
                key: _fieldKeys[RegistrationField.fullName],
                field: RegistrationField.fullName,
                focusNode: _focusNodes[RegistrationField.fullName]!,
                onSubmitted: () => _focusNext(RegistrationField.fullName),
                onTap: () => _ensureVisible(RegistrationField.fullName),
                getController: (p) => p.fullNameController,
                hint: "Họ và tên",
                icon: Icons.badge,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              _ProviderTextField(
                key: _fieldKeys[RegistrationField.email],
                field: RegistrationField.email,
                focusNode: _focusNodes[RegistrationField.email]!,
                onSubmitted: () => _focusNext(RegistrationField.email),
                onTap: () => _ensureVisible(RegistrationField.email),
                getController: (p) => p.emailController,
                hint: "Email",
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _ProviderTextField(
                key: _fieldKeys[RegistrationField.licenseNumber],
                field: RegistrationField.licenseNumber,
                focusNode: _focusNodes[RegistrationField.licenseNumber]!,
                onSubmitted: () => _focusNext(RegistrationField.licenseNumber),
                onTap: () => _ensureVisible(RegistrationField.licenseNumber),
                getController: (p) => p.licenseNumberController,
                hint: "Biển số xe",
                icon: Icons.directions_car,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          key: _fieldKeys[RegistrationField.region],
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DriverSectionCard(
              title: "Miền hoạt động",
              subtitle:
                  "Lưu ý: Chỉ được chọn khu vực hoạt động duy nhất một lần.",
              icon: Icons.map_outlined,
              child: _RegionDropdownField(),
            ),
            _fieldError(RegistrationField.region),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
              );
            },
            child: Text(
              "Bạn đã có tài khoản? Quay về đăng nhập",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Brand.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepAccount(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        DriverSectionCard(
          title: "Thông tin liên hệ",
          subtitle: "Dùng để đăng nhập.",
          icon: Icons.call_outlined,
          child: Column(
            children: [
              _ProviderTextField(
                key: _fieldKeys[RegistrationField.phone],
                field: RegistrationField.phone,
                focusNode: _focusNodes[RegistrationField.phone]!,
                onSubmitted: () => _focusNext(RegistrationField.phone),
                onTap: () => _ensureVisible(RegistrationField.phone),
                getController: (p) => p.phoneController,
                hint: "Số điện thoại",
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _ProviderTextField(
                key: _fieldKeys[RegistrationField.confirmPhone],
                field: RegistrationField.confirmPhone,
                focusNode: _focusNodes[RegistrationField.confirmPhone]!,
                onSubmitted: () => _focusNext(RegistrationField.confirmPhone),
                onTap: () => _ensureVisible(RegistrationField.confirmPhone),
                getController: (p) => p.confirmPhoneController,
                hint: "Nhập lại số điện thoại",
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DriverSectionCard(
          title: "Bảo mật tài khoản",
          subtitle: "Đặt mật khẩu mạnh.",
          icon: Icons.lock_outline_rounded,
          child: Column(
            children: [
              _PasswordTextField(
                key: _fieldKeys[RegistrationField.password],
                isConfirm: false,
                focusNode: _focusNodes[RegistrationField.password]!,
                onSubmitted: () => _focusNext(RegistrationField.password),
                onTap: () => _ensureVisible(RegistrationField.password),
              ),
              SizedBox(height: 14),
              _PasswordTextField(
                key: _fieldKeys[RegistrationField.confirmPassword],
                isConfirm: true,
                focusNode: _focusNodes[RegistrationField.confirmPassword]!,
                onSubmitted: () =>
                    _focusNext(RegistrationField.confirmPassword),
                onTap: () => _ensureVisible(RegistrationField.confirmPassword),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConfirm(BuildContext context, ThemeData theme) {
    final p = context.read<RegisterProvider>();
    final regionLabel = RegisterProvider.regionOptions[p.selectedRegion];

    return Column(
      children: [
        DriverSectionCard(
          title: "Kiểm tra lại thông tin",
          subtitle: "Đảm bảo thông tin chính xác trước khi đăng ký.",
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _SummaryRow(
                icon: Icons.badge,
                label: "Họ và tên",
                value: p.fullNameController.text,
              ),
              _SummaryRow(
                icon: Icons.email,
                label: "Email",
                value: p.emailController.text,
              ),
              _SummaryRow(
                icon: Icons.directions_car,
                label: "Biển số xe",
                value: p.licenseNumberController.text,
              ),
              _SummaryRow(
                icon: Icons.map_outlined,
                label: "Miền hoạt động",
                value: regionLabel ?? "",
              ),
              _SummaryRow(
                icon: Icons.phone,
                label: "Số điện thoại",
                value: p.phoneController.text,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DriverSectionCard(
          title: "Xác nhận điều kiện",
          icon: Icons.verified_user_outlined,
          child: Column(
            children: [
              const _TermsSection(),
              KeyedSubtree(
                key: _fieldKeys[RegistrationField.terms],
                child: _fieldError(RegistrationField.terms),
              ),
              KeyedSubtree(
                key: _fieldKeys[RegistrationField.camera],
                child: _fieldError(RegistrationField.camera),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldError(RegistrationField field) {
    final error = context.watch<RegisterProvider>().fieldErrors[field];
    return error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: const TextStyle(color: Brand.danger, fontSize: 12),
            ),
          );
  }

  Widget _buildStepOtp(BuildContext context, ThemeData theme) {
    final provider = context.watch<RegisterProvider>();
    return DriverSectionCard(
      title: 'Xác minh email',
      icon: Icons.mark_email_read_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nhập mã OTP gửi tới ${provider.maskedChallengeEmail}.',
            style: const TextStyle(color: Brand.inkMuted),
          ),
          const SizedBox(height: 16),
          _ProviderTextField(
            key: _fieldKeys[RegistrationField.otp],
            field: RegistrationField.otp,
            focusNode: _focusNodes[RegistrationField.otp]!,
            onSubmitted: () => _focusNext(RegistrationField.otp),
            onTap: () => _ensureVisible(RegistrationField.otp),
            getController: (p) => p.otpController,
            hint: 'Mã OTP email',
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          TextButton(
            onPressed: provider.canSubmit
                ? () async {
                    await provider.requestRegistrationChallenge();
                    if (mounted) _ensureKeyVisible(_apiErrorKey);
                  }
                : null,
            child: const Text('Gửi lại mã'),
          ),
          if (provider.registrationOutcomeUnknown)
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
              ),
              child: const Text('Về đăng nhập để kiểm tra tài khoản'),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── Thanh điều hướng đáy ─────────────────────────

  Widget _buildBottomBar(BuildContext context, ThemeData theme, bool loading) {
    final provider = context.read<RegisterProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Brand.canvas,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListenableBuilder(
        // Rebuild khi người dùng gõ để bật/tắt nút theo từng bước.
        listenable: Listenable.merge([
          provider,
          provider.fullNameController,
          provider.emailController,
          provider.licenseNumberController,
          provider.phoneController,
          provider.confirmPhoneController,
          provider.passwordController,
          provider.confirmPasswordController,
        ]),
        builder: (context, _) {
          final enabled = provider.canSubmit;

          return Row(
            children: [
              if (!_isFirst) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : _goBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Brand.navy,
                      side: const BorderSide(color: Brand.navy),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text("Quay lại"),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: enabled
                        ? (_isLast ? _handleRegister : _goNext)
                        : null,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLast
                                ? "Đăng ký"
                                : _step == 2
                                ? "Gửi mã xác minh"
                                : "Tiếp tục",
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════ Thanh tiến trình ═════════════════════════

class _StepHeader extends StatelessWidget {
  final int current;

  const _StepHeader({required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isDone = i < current;
          final isCurrent = i == current;
          final active = isDone || isCurrent;
          final step = _steps[i];

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StepLine(visible: i != 0, filled: i <= current),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Brand.navy : Brand.b50,
                        border: Border.all(
                          color: active
                              ? Brand.navy
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.15,
                                ),
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : step.icon,
                        size: 18,
                        color: active
                            ? Colors.white
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                    Expanded(
                      child: _StepLine(
                        visible: i != _steps.length - 1,
                        filled: i < current,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${i + 1}. ${step.label}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: active ? Brand.navy : Brand.inkMuted,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool visible;
  final bool filled;

  const _StepLine({required this.visible, required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: !visible
            ? Colors.transparent
            : (filled
                  ? Brand.navy
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
    );
  }
}

// ═════════════════════════ Ô nhập liệu ═════════════════════════

class _ProviderTextField extends StatelessWidget {
  final RegistrationField field;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onTap;
  final TextEditingController Function(RegisterProvider) getController;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;

  const _ProviderTextField({
    super.key,
    required this.field,
    required this.focusNode,
    required this.onSubmitted,
    required this.onTap,
    required this.getController,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();
    final controller = getController(provider);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !provider.loading,
      onTap: onTap,
      onSubmitted: (_) => onSubmitted(),
      onChanged: (_) => provider.fieldChanged(field),
      autofillHints: field == RegistrationField.otp
          ? const [AutofillHints.oneTimeCode]
          : null,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: _inputDecoration(
        theme,
        hint,
        icon,
      ).copyWith(errorText: provider.fieldErrors[field], errorMaxLines: 3),
    );
  }
}

class _PasswordTextField extends StatelessWidget {
  final bool isConfirm;

  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onTap;

  const _PasswordTextField({
    super.key,
    required this.isConfirm,
    required this.focusNode,
    required this.onSubmitted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();

    final isObscure = isConfirm
        ? provider.obscureConfirmPassword
        : provider.obscurePassword;
    final toggle = isConfirm
        ? provider.toggleObscureConfirmPassword
        : provider.toggleObscurePassword;
    final controller = isConfirm
        ? provider.confirmPasswordController
        : provider.passwordController;
    final hint = isConfirm ? "Nhập lại mật khẩu" : "Mật khẩu";

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !provider.loading,
      onTap: onTap,
      onSubmitted: (_) => onSubmitted(),
      onChanged: (_) => provider.fieldChanged(
        isConfirm
            ? RegistrationField.confirmPassword
            : RegistrationField.password,
      ),
      obscureText: isObscure,
      textInputAction: isConfirm ? TextInputAction.done : TextInputAction.next,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: _inputDecoration(theme, hint, Icons.lock).copyWith(
        errorText:
            provider.fieldErrors[isConfirm
                ? RegistrationField.confirmPassword
                : RegistrationField.password],
        errorMaxLines: 3,
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}

// ═════════════════════════ Chọn miền ═════════════════════════

class _RegionDropdownField extends StatelessWidget {
  const _RegionDropdownField();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();
    final entries = RegisterProvider.regionOptions.entries.toList();

    return Row(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _RegionOption(
              label: entries[i].value,
              selected: provider.selectedRegion == entries[i].key,
              onTap: () => provider.setRegion(entries[i].key),
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }
}

class _RegionOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RegionOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Brand.b50 : Brand.b50.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Brand.navy
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? Brand.navy
                  : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Tóm tắt & điều khoản ═════════════════════════

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Brand.navy),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Brand.inkMuted),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? "—" : value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Brand.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: provider.agreeTerms,
              activeColor: Brand.navy,
              checkColor: theme.colorScheme.onSecondary,
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onChanged: (v) => provider.setAgreeTerms(v ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
                child: Text(
                  "Tôi đồng ý với Chính sách & Điều khoản sử dụng",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                    color: Brand.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: provider.agreeCamera,
              activeColor: Brand.navy,
              checkColor: theme.colorScheme.onSecondary,
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onChanged: (v) => provider.setAgreeCamera(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  "Tôi cam kết xe có gắn camera hành trình và đang hoạt động bình thường",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Brand.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(ThemeData theme, String hint, IconData icon) {
  return driverInputDecoration(theme, label: hint, hint: hint, icon: icon);
}
