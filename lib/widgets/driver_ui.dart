import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Ô nhập dùng chung của app tài xế — theo theme sáng (nền trắng, viền xám, focus navy).
InputDecoration driverInputDecoration(
  ThemeData theme, {
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  String? helperText,
  bool alignLabelWithHint = false,
  bool dense = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    alignLabelWithHint: alignLabelWithHint,
    isDense: dense,
    prefixIcon: icon == null ? null : Icon(icon, color: Brand.navy),
    suffixIcon: suffixIcon,
  );
}

/// Thẻ trắng có tiêu đề + icon (khung chung các màn tài xế).
class DriverSectionCard extends StatelessWidget {
  const DriverSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: padding ?? const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[IconTile(icon!, size: 42), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 13, color: Brand.inkMuted, height: 1.4)),
                ],
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Chip nhỏ có icon. Mặc định nền brand-50 chữ navy; truyền [color] để đổi tông.
class DriverPill extends StatelessWidget {
  const DriverPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Brand.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color == null ? Brand.b50 : fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
        Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Ô số liệu (thu nhập, số chuyến...).
class DriverStatTile extends StatelessWidget {
  const DriverStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Brand.navy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Icon(icon, size: 18, color: accent), const SizedBox(height: 10)],
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.ink)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.inkMuted, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class DriverEmptyState extends StatelessWidget {
  const DriverEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(child: EmptyState(icon: icon, title: title, message: message));
}
