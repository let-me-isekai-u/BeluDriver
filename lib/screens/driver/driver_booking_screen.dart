import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../models/broker_ride_models.dart';
import 'driver_booking_confirm.dart';

class DriverBookingScreen extends StatefulWidget {
  final VoidCallback? onGoToPushedOrdersTab;

  const DriverBookingScreen({
    super.key,
    this.onGoToPushedOrdersTab,
  });

  @override
  State<DriverBookingScreen> createState() => _DriverBookingScreenState();
}

class _DriverBookingScreenState extends State<DriverBookingScreen> {
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController(text: "1");
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _offerPriceController = TextEditingController();
  final _creatorEarnController = TextEditingController();

  static const int _type = 2;

  int? _fromProvinceId;
  int? _fromDistrictId;
  int? _toProvinceId;
  int? _toDistrictId;

  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  bool _loadingProvinces = false;
  bool _loadingFromDistricts = false;
  bool _loadingToDistricts = false;

  List<dynamic> _provinces = [];
  List<dynamic> _fromDistricts = [];
  List<dynamic> _toDistricts = [];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _offerPriceController.dispose();
    _creatorEarnController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await ApiService.getProvinces();
      if (!mounted) return;
      setState(() => _provinces = list);
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _loadDistrictsForFromProvince(int provinceId) async {
    setState(() {
      _loadingFromDistricts = true;
      _fromDistricts = [];
      _fromDistrictId = null;
    });
    try {
      final list = await ApiService.getDistricts(provinceId: provinceId);
      if (!mounted) return;
      setState(() => _fromDistricts = list);
    } finally {
      if (mounted) setState(() => _loadingFromDistricts = false);
    }
  }

  Future<void> _loadDistrictsForToProvince(int provinceId) async {
    setState(() {
      _loadingToDistricts = true;
      _toDistricts = [];
      _toDistrictId = null;
    });
    try {
      final list = await ApiService.getDistricts(provinceId: provinceId);
      if (!mounted) return;
      setState(() => _toDistricts = list);
    } finally {
      if (mounted) setState(() => _loadingToDistricts = false);
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  int? _tryParseInt(String raw) => int.tryParse(raw.trim());
  num? _tryParseNum(String raw) => num.tryParse(raw.trim());

  String _formatDate(DateTime? date) => date == null ? "" : DateFormat('dd/MM/yyyy').format(date);

  String _formatTime(TimeOfDay? t) =>
      t == null ? "" : "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  String? _buildPickupIso() {
    if (_pickupDate == null || _pickupTime == null) return null;
    final dt = DateTime(
      _pickupDate!.year,
      _pickupDate!.month,
      _pickupDate!.day,
      _pickupTime!.hour,
      _pickupTime!.minute,
    );
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String _getNameById(List<dynamic> items, int? id) {
    if (id == null) return '';
    final found = items.cast<dynamic?>().firstWhere(
          (e) => e != null && e['id'].toString() == id.toString(),
      orElse: () => null,
    );
    return found?['name']?.toString() ?? '';
  }

  Future<int?> _showPicker({
    required String title,
    required List<dynamic> items,
    required int? selectedId,
    required int? disabledId,
    required IconData icon,
  }) {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(
                        "Đóng",
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    )
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
                    final id =
                    it['id'] is int ? it['id'] as int : int.tryParse(it['id'].toString());
                    final name = it['name']?.toString() ?? '';
                    final bool isDisabled =
                    (id != null && disabledId != null && id.toString() == disabledId.toString());
                    final bool isSelected =
                    (id != null && selectedId != null && id.toString() == selectedId.toString());

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Icon(
                        icon,
                        color: isDisabled ? Colors.grey[300] : Theme.of(context).colorScheme.secondary,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isDisabled ? Colors.grey : Colors.black,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      onTap: (id == null || isDisabled) ? null : () => Navigator.pop(ctx, id),
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

  Future<void> _pickTimeDialog() async {
    final theme = Theme.of(context);
    int selectedHour = _pickupTime?.hour ?? TimeOfDay.now().hour;
    int selectedMinute = _pickupTime?.minute ?? TimeOfDay.now().minute;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                              setState(() {
                                _pickupTime = TimeOfDay(
                                  hour: selectedHour,
                                  minute: selectedMinute,
                                );
                              });
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
                              scrollController: FixedExtentScrollController(initialItem: selectedHour),
                              itemExtent: 40,
                              selectionOverlay: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
                                    bottom: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (index) => setDialogState(() => selectedHour = index),
                              children: List.generate(
                                24,
                                    (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
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
                              scrollController: FixedExtentScrollController(initialItem: selectedMinute),
                              itemExtent: 40,
                              selectionOverlay: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
                                    bottom: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (index) => setDialogState(() => selectedMinute = index),
                              children: List.generate(
                                60,
                                    (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
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

  bool _validateAndShowErrors() {
    void showErr(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }

    if (_phoneController.text.trim().isEmpty) {
      showErr("Vui lòng nhập số điện thoại khách");
      return false;
    }

    final q = _tryParseInt(_quantityController.text);
    if (q == null || q < 1) {
      showErr("Số lượng phải là số nguyên ≥ 1");
      return false;
    }

    if (_fromProvinceId == null || _fromDistrictId == null || _fromAddressController.text.trim().isEmpty) {
      showErr("Vui lòng nhập đầy đủ điểm đón");
      return false;
    }

    if (_toProvinceId == null || _toDistrictId == null || _toAddressController.text.trim().isEmpty) {
      showErr("Vui lòng nhập đầy đủ điểm đến");
      return false;
    }

    final pickupIso = _buildPickupIso();
    if (pickupIso == null) {
      showErr("Vui lòng chọn ngày & giờ đón");
      return false;
    }

    final offer = _tryParseNum(_offerPriceController.text);
    if (offer == null || offer <= 0) {
      showErr("Vui lòng nhập giá chào hợp lệ");
      return false;
    }

    final earn = _tryParseNum(_creatorEarnController.text);
    if (earn == null || earn <= 0) {
      showErr("Vui lòng nhập tiền nhận hợp lệ");
      return false;
    }

    if (earn > offer) {
      showErr("Tiền nhận không được lớn hơn giá chào");
      return false;
    }

    return true;
  }

  void _goNext() {
    if (!_validateAndShowErrors()) return;

    final req = CreateBrokerRideRequest(
      fromDistrictId: _fromDistrictId!,
      toDistrictId: _toDistrictId!,
      fromAddress: _fromAddressController.text.trim(),
      toAddress: _toAddressController.text.trim(),
      type: _type,
      customerPhone: _phoneController.text.trim(),
      quantity: int.parse(_quantityController.text.trim()),
      pickupTime: _buildPickupIso()!,
      offerPrice: num.parse(_offerPriceController.text.trim()),
      creatorEarn: num.parse(_creatorEarnController.text.trim()),
      note: _noteController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverBookingConfirmScreen(
          request: req,
          fromProvinceId: _fromProvinceId!,
          toProvinceId: _toProvinceId!,
          onGoToPushedOrdersTab: widget.onGoToPushedOrdersTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    final fromProvinceName = _getNameById(_provinces, _fromProvinceId);
    final toProvinceName = _getNameById(_provinces, _toProvinceId);
    final fromDistrictName = _getNameById(_fromDistricts, _fromDistrictId);
    final toDistrictName = _getNameById(_toDistricts, _toDistrictId);

    return Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: gold, // màu con trỏ
          selectionColor: gold.withOpacity(0.25), // (tuỳ chọn) màu highlight
          selectionHandleColor: gold, // (tuỳ chọn) màu handle kéo
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
              _buildSectionCard(
                title: "Thông tin khách & ghi chú",
                icon: Icons.person_pin,
                children: [
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "SĐT khách (customerPhone)",
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone, color: theme.colorScheme.secondary),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Ghi chú (note)",
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                title: "Số lượng",
                icon: Icons.confirmation_number,
                children: [
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Số lượng (quantity)",
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people, color: theme.colorScheme.secondary),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      helperText: "Nhập số nguyên ≥ 1",
                      helperStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                title: "Điểm đón",
                icon: Icons.my_location,
                children: [
                  GestureDetector(
                    onTap: _loadingProvinces || _provinces.isEmpty
                        ? null
                        : () async {
                      final chosen = await _showPicker(
                        title: "Chọn tỉnh/TP đón",
                        items: _provinces,
                        selectedId: _fromProvinceId,
                        disabledId: _toProvinceId,
                        icon: Icons.location_city,
                      );
                      if (!mounted || chosen == null) return;
                      setState(() => _fromProvinceId = chosen);
                      await _loadDistrictsForFromProvince(chosen);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: fromProvinceName),
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Tỉnh/TP đón",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          hintText: fromProvinceName.isEmpty ? "Chọn tỉnh/TP" : null,
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          isDense: true,
                          prefixIcon: Icon(Icons.location_city, size: 20, color: theme.colorScheme.secondary),
                          suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: (_loadingFromDistricts || _fromDistricts.isEmpty)
                        ? null
                        : () async {
                      final chosen = await _showPicker(
                        title: "Chọn quận/huyện đón",
                        items: _fromDistricts,
                        selectedId: _fromDistrictId,
                        disabledId: null,
                        icon: Icons.map,
                      );
                      if (!mounted || chosen == null) return;
                      setState(() => _fromDistrictId = chosen);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: fromDistrictName),
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Quận/Huyện đón",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          hintText: fromDistrictName.isEmpty ? "Chọn quận/huyện" : null,
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          isDense: true,
                          prefixIcon: Icon(Icons.map, size: 20, color: theme.colorScheme.secondary),
                          suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fromAddressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Địa chỉ đón (fromAddress)",
                      labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      isDense: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                title: "Ngày & giờ đón",
                icon: Icons.calendar_today,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _pickupDate ?? DateTime.now(),
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
                                  foregroundColor: theme.colorScheme.secondary,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _pickupDate = picked);
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: TextEditingController(text: _formatDate(_pickupDate)),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Ngày đón",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          prefixIcon: Icon(Icons.event, size: 20, color: theme.colorScheme.secondary),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickTimeDialog,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: TextEditingController(text: _formatTime(_pickupTime)),
                        readOnly: true,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: "Giờ đón",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          hintText: "HH:MM",
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          prefixIcon: Icon(Icons.access_time, size: 20, color: theme.colorScheme.secondary),
                          suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                title: "Điểm đến",
                icon: Icons.location_on,
                children: [
                  GestureDetector(
                    onTap: _loadingProvinces || _provinces.isEmpty
                        ? null
                        : () async {
                      final chosen = await _showPicker(
                        title: "Chọn tỉnh/TP đến",
                        items: _provinces,
                        selectedId: _toProvinceId,
                        disabledId: _fromProvinceId,
                        icon: Icons.location_city,
                      );
                      if (!mounted || chosen == null) return;
                      setState(() => _toProvinceId = chosen);
                      await _loadDistrictsForToProvince(chosen);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: toProvinceName),
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Tỉnh/TP đến",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          hintText: toProvinceName.isEmpty ? "Chọn tỉnh/TP" : null,
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          isDense: true,
                          prefixIcon: Icon(Icons.location_city, size: 20, color: theme.colorScheme.secondary),
                          suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: (_loadingToDistricts || _toDistricts.isEmpty)
                        ? null
                        : () async {
                      final chosen = await _showPicker(
                        title: "Chọn quận/huyện đến",
                        items: _toDistricts,
                        selectedId: _toDistrictId,
                        disabledId: null,
                        icon: Icons.map,
                      );
                      if (!mounted || chosen == null) return;
                      setState(() => _toDistrictId = chosen);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: toDistrictName),
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Quận/Huyện đến",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                          hintText: toDistrictName.isEmpty ? "Chọn quận/huyện" : null,
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          isDense: true,
                          prefixIcon: Icon(Icons.map, size: 20, color: theme.colorScheme.secondary),
                          suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _toAddressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Địa chỉ đến (toAddress)",
                      labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      isDense: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                title: "Giá",
                icon: Icons.payments,
                children: [
                  TextField(
                    controller: _offerPriceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Giá chào (offerPrice)",
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.price_change, color: theme.colorScheme.secondary),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      helperText: "VD: 400000",
                      helperStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _creatorEarnController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Tiền nhận (creatorEarn)",
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money, color: theme.colorScheme.secondary),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      helperText: "VD: 350000",
                      helperStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text(
                    "TIẾP THEO",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.black87,
              ),
              child: const Text(
                "TIẾP THEO",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}