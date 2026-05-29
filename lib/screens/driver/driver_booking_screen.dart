import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/broker_ride_models.dart';
import '../../models/location_models.dart';
import '../../providers/broker/order_form_provider.dart';
import '../../widgets/driver_ui.dart';
import 'driver_address_map_picker_screen.dart';
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
      create: (_) => OrderFormProvider(),
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

  Future<void> _showFormError(BuildContext context, String message) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickPointOnMap(
    BuildContext context,
    OrderFormProvider provider, {
    required bool isFrom,
  }) async {
    final initialPoint = isFrom
        ? provider.selectedFromPoint
        : provider.selectedToPoint;

    final resolved = await Navigator.push<AddressResolvedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverAddressMapPickerScreen(
          title: isFrom
              ? "Chọn điểm đón trên bản đồ"
              : "Chọn điểm đến trên bản đồ",
          initialPoint: initialPoint,
        ),
      ),
    );

    if (resolved == null) return;

    if (isFrom) {
      provider.selectFromMapLocation(resolved);
    } else {
      provider.selectToMapLocation(resolved);
    }
  }

  void _goNext(BuildContext context, OrderFormProvider provider) {
    final err = provider.validate();
    if (err != null) {
      _showFormError(context, err);
      return;
    }

    final req = provider.buildRequest(groupId: groupId);

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverBookingConfirmScreen(
          request: req,
          onGoToPushedOrdersTab: onGoToPushedOrdersTab,
        ),
      ),
    ).then((created) {
      if (created == true && closeOnSuccess && context.mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  Widget _buildSelectedAddressHint(
    BuildContext context,
    String title,
    String subtitle,
    AddressSelectionSource? source,
  ) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sourceLabel = source == AddressSelectionSource.map
        ? "Đã chọn trên bản đồ"
        : "Đã chọn từ gợi ý";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF123B33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 18,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  sourceLabel,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    required bool isFrom,
    required TextEditingController controller,
    required bool isLoading,
    required bool hasSelection,
    required String selectedTitle,
    required String selectedSubtitle,
    required AddressSelectionSource? selectionSource,
    required List<TrackAsiaAutocompleteSuggestion> suggestions,
    required ValueChanged<TrackAsiaAutocompleteSuggestion> onSelected,
    required VoidCallback onClearSelection,
    required VoidCallback onPickOnMap,
  }) {
    final theme = Theme.of(context);
    final showSuggestions = suggestions.isNotEmpty;

    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: (value) => context
                .read<OrderFormProvider>()
                .onAddressTextChanged(isFrom: isFrom, query: value),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              context.read<OrderFormProvider>().closeAutocompleteSuggestions();
            },
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              context,
              label: label,
              hint: hint,
              icon: icon,
              helperText:
                  "Nhập tối thiểu 2 ký tự. Nếu sửa text sau khi chọn, cần chọn lại gợi ý.",
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasSelection
                  ? IconButton(
                      onPressed: onClearSelection,
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    )
                  : const Icon(Icons.search_rounded, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPickOnMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text("Chọn trên bản đồ"),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          _buildSelectedAddressHint(
            context,
            selectedTitle,
            selectedSubtitle,
            selectionSource,
          ),
          if (showSuggestions) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 340),
              decoration: BoxDecoration(
                color: AppColors.darkGreenBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.18),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      onSelected(suggestion);
                    },
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    title: Text(
                      suggestion.primaryText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: suggestion.secondaryText.isEmpty
                        ? null
                        : Text(
                            suggestion.secondaryText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Consumer<OrderFormProvider>(
      builder: (context, provider, _) {
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
              actions: [
                TextButton(
                  onPressed: () => _goNext(context, provider),
                  child: Text(
                    "TIẾP THEO",
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            body: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 +
                    MediaQuery.of(context).padding.bottom +
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                DriverSectionCard(
                  title: "Tạo chuyến cộng đồng",
                  subtitle:
                      "Luồng tài xế dùng TrackAsia autocomplete, chọn `placeId` và tự nhập giá bán.",
                  icon: Icons.auto_awesome_rounded,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      DriverPill(
                        label:
                            provider.hasFromSelection && provider.hasToSelection
                            ? "Đã chọn 2 địa chỉ"
                            : "Chưa chọn đủ địa chỉ",
                        icon:
                            provider.hasFromSelection && provider.hasToSelection
                            ? Icons.verified_rounded
                            : Icons.route_outlined,
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
                      "Chọn loại chuyến. Bao xe sẽ không yêu cầu nhập số lượng người.",
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
                    if (provider.requiresPassengerQuantity) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: provider.quantityController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          context,
                          label: provider.quantityLabel,
                          icon: Icons.people_outline_rounded,
                          helperText: "Nhập số nguyên ≥ 1",
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionCard(
                  context: context,
                  title: "Điểm đón",
                  icon: Icons.my_location,
                  children: [
                    _buildAutocompleteField(
                      context: context,
                      label: "Địa chỉ đón",
                      hint: "Ví dụ: Nội Bài, Hoàn Kiếm...",
                      icon: Icons.location_searching_rounded,
                      isFrom: true,
                      controller: provider.fromAddressController,
                      isLoading: provider.loadingFromSuggestions,
                      hasSelection: provider.hasFromSelection,
                      selectedTitle: provider.fromSelectionTitle,
                      selectedSubtitle: provider.fromSelectionSubtitle,
                      selectionSource: provider.fromSelectionSource,
                      suggestions: provider.fromSuggestions,
                      onSelected: provider.selectFromSuggestion,
                      onClearSelection: provider.clearFromSelection,
                      onPickOnMap: () =>
                          _pickPointOnMap(context, provider, isFrom: true),
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
                          decoration: _fieldDecoration(
                            context,
                            label: "Ngày đón",
                            icon: Icons.event,
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
                          decoration: _fieldDecoration(
                            context,
                            label: "Giờ đón",
                            hint: "HH:MM",
                            icon: Icons.access_time,
                            suffixIcon: const Icon(
                              Icons.unfold_more_rounded,
                              color: Colors.white70,
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
                  children: [
                    _buildAutocompleteField(
                      context: context,
                      label: "Địa chỉ đến",
                      hint: "Ví dụ: Mỹ Đình, Hai Bà Trưng...",
                      icon: Icons.location_on_outlined,
                      isFrom: false,
                      controller: provider.toAddressController,
                      isLoading: provider.loadingToSuggestions,
                      hasSelection: provider.hasToSelection,
                      selectedTitle: provider.toSelectionTitle,
                      selectedSubtitle: provider.toSelectionSubtitle,
                      selectionSource: provider.toSelectionSource,
                      suggestions: provider.toSuggestions,
                      onSelected: provider.selectToSuggestion,
                      onClearSelection: provider.clearToSelection,
                      onPickOnMap: () =>
                          _pickPointOnMap(context, provider, isFrom: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionCard(
                  context: context,
                  title: "Giá bán & tiền nhận",
                  icon: Icons.payments,
                  subtitle:
                      "Tài xế tự nhập giá bán; app khách hàng mới theo giá hệ thống.",
                  children: [
                    TextField(
                      controller: provider.offerPriceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _fieldDecoration(
                        context,
                        label: "Giá chào (offerPrice)",
                        icon: Icons.price_change,
                        helperText: "Ví dụ: 400,000",
                      ).copyWith(suffixText: "đ"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: provider.creatorEarnController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _fieldDecoration(
                        context,
                        label: "Tiền nhận (creatorEarn)",
                        icon: Icons.attach_money,
                        helperText: "Ví dụ: 350,000",
                      ).copyWith(suffixText: "đ"),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
