import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/broker_ride_models.dart';
import '../../providers/broker/order_form_provider.dart';
import '../../widgets/driver_ui.dart';
import 'driver_booking_confirm.dart';

class DriverBookingScreen extends StatefulWidget {
  final VoidCallback? onGoToPushedOrdersTab;
  final int? groupId;
  final bool closeOnSuccess;

  const DriverBookingScreen({
    super.key,
    this.onGoToPushedOrdersTab,
    this.groupId,
    this.closeOnSuccess = false,
  });

  @override
  State<DriverBookingScreen> createState() => _DriverBookingScreenState();
}

class _DriverBookingScreenState extends State<DriverBookingScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderFormProvider()..loadProvinces(),
      child: _DriverBookingView(
        onGoToPushedOrdersTab: widget.onGoToPushedOrdersTab,
        groupId: widget.groupId,
        closeOnSuccess: widget.closeOnSuccess,
      ),
    );
  }
}

class _DriverBookingView extends StatelessWidget {
  final VoidCallback? onGoToPushedOrdersTab;
  final int? groupId;
  final bool closeOnSuccess;

  const _DriverBookingView({
    required this.onGoToPushedOrdersTab,
    required this.groupId,
    required this.closeOnSuccess,
  });

  Future<int?> _showPicker({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    required int? selectedId,
    required int? disabledId,
    required IconData icon,
    bool Function(int?)? canSelectDisabledId,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: BoxDecoration(
            color: AppColors.darkGreenBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(
                        "Đóng",
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final it = items[index];
                          final id = it['id'] is int
                              ? it['id'] as int
                              : int.tryParse(it['id'].toString());
                          final name = it['name']?.toString() ?? '';
                          final bool isDisabled =
                              (id != null &&
                              disabledId != null &&
                              id.toString() == disabledId.toString() &&
                              !(canSelectDisabledId?.call(id) ?? false));
                          final bool isSelected =
                              (id != null &&
                              selectedId != null &&
                              id.toString() == selectedId.toString());

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            leading: Icon(
                              icon,
                              color: isDisabled
                                  ? Colors.grey[600]
                                  : theme.colorScheme.secondary,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: isDisabled ? Colors.grey : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            onTap: (id == null || isDisabled)
                                ? null
                                : () => Navigator.pop(ctx, id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTimeDialog(
    BuildContext context,
    OrderFormProvider provider,
  ) async {
    final theme = Theme.of(context);
    int selectedHour = provider.pickupTime?.hour ?? TimeOfDay.now().hour;
    int selectedMinute = provider.pickupTime?.minute ?? TimeOfDay.now().minute;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                height: 320,
                decoration: BoxDecoration(
                  color: AppColors.darkGreenBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              "Hủy",
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            "Chọn giờ đón",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              provider.setPickupTime(
                                TimeOfDay(
                                  hour: selectedHour,
                                  minute: selectedMinute,
                                ),
                              );
                              Navigator.pop(dialogCtx);
                            },
                            child: Text(
                              "Xong",
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedHour,
                              ),
                              itemExtent: 40,
                              selectionOverlay: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: theme.colorScheme.secondary,
                                      width: 1.5,
                                    ),
                                    bottom: BorderSide(
                                      color: theme.colorScheme.secondary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (index) =>
                                  setDialogState(() => selectedHour = index),
                              children: List.generate(
                                24,
                                (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            ":",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedMinute,
                              ),
                              itemExtent: 40,
                              selectionOverlay: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: theme.colorScheme.secondary,
                                      width: 1.5,
                                    ),
                                    bottom: BorderSide(
                                      color: theme.colorScheme.secondary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (index) =>
                                  setDialogState(() => selectedMinute = index),
                              children: List.generate(
                                60,
                                (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return DriverSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(children: children),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    String? helperText,
    bool alignLabelWithHint = false,
    bool dense = false,
  }) {
    return driverInputDecoration(
      Theme.of(context),
      label: label,
      hint: hint,
      icon: icon,
      suffixIcon: suffixIcon,
      helperText: helperText,
      alignLabelWithHint: alignLabelWithHint,
      dense: dense,
    );
  }

  void _goNext(BuildContext context, OrderFormProvider provider) {
    final err = provider.validate();
    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }

    final req = provider.buildRequest(groupId: groupId);

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverBookingConfirmScreen(
          request: req,
          fromProvinceId: provider.fromProvinceId!,
          toProvinceId: provider.toProvinceId!,
          onGoToPushedOrdersTab: onGoToPushedOrdersTab,
        ),
      ),
    ).then((created) {
      if (created == true && closeOnSuccess && context.mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Consumer<OrderFormProvider>(
      builder: (context, provider, _) {
        final fromProvinceName = provider.getNameById(
          provider.provinces,
          provider.fromProvinceId,
        );
        final toProvinceName = provider.getNameById(
          provider.provinces,
          provider.toProvinceId,
        );
        final fromDistrictName = provider.getNameById(
          provider.fromDistricts,
          provider.fromDistrictId,
        );
        final toDistrictName = provider.getNameById(
          provider.toDistricts,
          provider.toDistrictId,
        );

        return Theme(
          data: theme.copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: gold,
              selectionColor: gold.withValues(alpha: 0.25),
              selectionHandleColor: gold,
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Tài xế - Đẩy đơn',
                style: TextStyle(color: theme.colorScheme.secondary),
              ),
              centerTitle: true,
              iconTheme: IconThemeData(color: theme.colorScheme.secondary),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DriverSectionCard(
                    title: "Tạo chuyến cộng đồng",
                    subtitle:
                        "Biểu mẫu được gom lại theo từng nhóm để nhập nhanh hơn nhưng vẫn giữ nguyên quy trình hiện tại.",
                    icon: Icons.auto_awesome_rounded,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        DriverPill(
                          label:
                              provider.selectedType == BrokerRideType.passenger
                              ? "Chuyến ghép"
                              : "Bao xe",
                          icon: Icons.directions_car_filled_rounded,
                        ),
                        DriverPill(
                          label: provider.pickupDate == null
                              ? "Chưa chọn ngày"
                              : provider.formatDate(provider.pickupDate),
                          icon: Icons.event_rounded,
                        ),
                        DriverPill(
                          label: provider.pickupTime == null
                              ? "Chưa chọn giờ"
                              : provider.formatTime(provider.pickupTime),
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Thông tin khách & ghi chú",
                    icon: Icons.person_pin,
                    subtitle: "Thông tin liên hệ của khách và ghi chú bổ sung.",
                    children: [
                      TextField(
                        controller: provider.customerNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          context,
                          label: "Tên khách hàng",
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: provider.phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          context,
                          label: "SĐT khách",
                          icon: Icons.phone,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: provider.noteController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          context,
                          label: "Ghi chú",
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Loại chuyến",
                    icon: Icons.directions_car,
                    subtitle:
                        "Chọn loại chuyến và số lượng người nếu là chuyến ghép.",
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: provider.selectedType,
                        dropdownColor: theme.colorScheme.primary,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          context,
                          label: "Loại chuyến",
                          icon: Icons.category_outlined,
                        ),
                        items: BrokerRideType.options
                            .map(
                              (option) => DropdownMenuItem<int>(
                                value: option.value,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: provider.updateRideType,
                      ),
                      const SizedBox(height: 12),
                      if (provider.requiresPassengerQuantity)
                        TextField(
                          controller: provider.quantityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration(
                            context,
                            label: "Số lượng người",
                            icon: Icons.people,
                            helperText: "Nhập số nguyên ≥ 1",
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Điểm đón",
                    icon: Icons.my_location,
                    subtitle:
                        "Chọn địa điểm đón theo tỉnh, huyện và địa chỉ chi tiết.",
                    children: [
                      GestureDetector(
                        onTap:
                            provider.loadingProvinces ||
                                provider.provinces.isEmpty
                            ? null
                            : () async {
                                final chosen = await _showPicker(
                                  context: context,
                                  title: "Chọn tỉnh/TP đón",
                                  items: provider.provinces,
                                  selectedId: provider.fromProvinceId,
                                  disabledId: provider.toProvinceId,
                                  icon: Icons.location_city,
                                  canSelectDisabledId:
                                      provider.canSelectSameProvince,
                                );
                                if (!context.mounted || chosen == null) return;
                                provider.setFromProvince(chosen);
                                await provider.loadDistrictsForFromProvince(
                                  chosen,
                                );
                              },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: fromProvinceName,
                            ),
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Tỉnh/TP đón",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: fromProvinceName.isEmpty
                                  ? "Chọn tỉnh/TP"
                                  : null,
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.location_city,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              suffixIcon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white70,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap:
                            (provider.loadingFromDistricts ||
                                provider.fromDistricts.isEmpty)
                            ? null
                            : () async {
                                final chosen = await _showPicker(
                                  context: context,
                                  title: "Chọn quận/huyện đón",
                                  items: provider.availableFromDistricts,
                                  selectedId: provider.fromDistrictId,
                                  disabledId: null,
                                  icon: Icons.map,
                                );
                                if (!context.mounted || chosen == null) return;
                                provider.setFromDistrict(chosen);
                                provider.syncAddressWithDistrict(
                                  isFrom: true,
                                  districtId: chosen,
                                );
                              },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: fromDistrictName,
                            ),
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Quận/Huyện đón",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: fromDistrictName.isEmpty
                                  ? "Chọn quận/huyện"
                                  : null,
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.map,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              suffixIcon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white70,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: provider.fromAddressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Địa chỉ đón (fromAddress)",
                          labelStyle: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          isDense: true,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Ngày & giờ đón",
                    icon: Icons.calendar_today,
                    subtitle: "Ấn vào từng ô để chọn ngày giờ đón khách.",
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDate: provider.pickupDate ?? DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: theme.colorScheme.secondary,
                                    onPrimary: Colors.black87,
                                    onSurface: Colors.black87,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.secondary,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            provider.setPickupDate(picked);
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: TextEditingController(
                              text: provider.formatDate(provider.pickupDate),
                            ),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Ngày đón",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              prefixIcon: Icon(
                                Icons.event,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickTimeDialog(context, provider),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: TextEditingController(
                              text: provider.formatTime(provider.pickupTime),
                            ),
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: "Giờ đón",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: "HH:MM",
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              prefixIcon: Icon(
                                Icons.access_time,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              suffixIcon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white70,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Điểm đến",
                    icon: Icons.location_on,
                    subtitle: "Điền đủ tỉnh, huyện và địa chỉ đến.",
                    children: [
                      GestureDetector(
                        onTap:
                            provider.loadingProvinces ||
                                provider.provinces.isEmpty
                            ? null
                            : () async {
                                final chosen = await _showPicker(
                                  context: context,
                                  title: "Chọn tỉnh/TP đến",
                                  items: provider.provinces,
                                  selectedId: provider.toProvinceId,
                                  disabledId: provider.fromProvinceId,
                                  icon: Icons.location_city,
                                  canSelectDisabledId:
                                      provider.canSelectSameProvince,
                                );
                                if (!context.mounted || chosen == null) return;
                                provider.setToProvince(chosen);
                                await provider.loadDistrictsForToProvince(
                                  chosen,
                                );
                              },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: toProvinceName,
                            ),
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Tỉnh/TP đến",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: toProvinceName.isEmpty
                                  ? "Chọn tỉnh/TP"
                                  : null,
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.location_city,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              suffixIcon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white70,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap:
                            (provider.loadingToDistricts ||
                                provider.toDistricts.isEmpty)
                            ? null
                            : () async {
                                final chosen = await _showPicker(
                                  context: context,
                                  title: "Chọn quận/huyện đến",
                                  items: provider.availableToDistricts,
                                  selectedId: provider.toDistrictId,
                                  disabledId: null,
                                  icon: Icons.map,
                                );
                                if (!context.mounted || chosen == null) return;
                                provider.setToDistrict(chosen);
                                provider.syncAddressWithDistrict(
                                  isFrom: false,
                                  districtId: chosen,
                                );
                              },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: toDistrictName,
                            ),
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Quận/Huyện đến",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: toDistrictName.isEmpty
                                  ? "Chọn quận/huyện"
                                  : null,
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.map,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              suffixIcon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white70,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: provider.toAddressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Địa chỉ đến (toAddress)",
                          labelStyle: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          isDense: true,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    context: context,
                    title: "Giá",
                    icon: Icons.payments,
                    subtitle:
                        "Kiểm tra lại giá chào và khoản tiền tài xế nhận.",
                    children: [
                      TextField(
                        controller: provider.offerPriceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Giá chào (offerPrice)",
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.price_change,
                            color: theme.colorScheme.secondary,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          suffixText: "đ",
                          helperText: "VD: 400,000",
                          helperStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: provider.creatorEarnController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Tiền nhận (creatorEarn)",
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: theme.colorScheme.secondary,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          suffixText: "đ",
                          helperText: "VD: 350,000",
                          helperStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.pickupDate == null ||
                                    provider.pickupTime == null
                                ? "Chưa chọn thời gian đón"
                                : "Đón lúc ${provider.formatTime(provider.pickupTime)} ${provider.formatDate(provider.pickupDate)}",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          provider.offerPriceController.text.trim().isEmpty
                              ? "--"
                              : "${provider.offerPriceController.text.trim()} đ",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _goNext(context, provider),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text(
                          "TIẾP THEO",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
