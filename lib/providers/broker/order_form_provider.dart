import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/broker_ride_models.dart';
import '../../models/location_models.dart';
import '../../services/api_service.dart';

class OrderFormProvider extends ChangeNotifier {
  static final NumberFormat _moneyFormatter = NumberFormat('#,###');

  final phoneController = TextEditingController();
  final customerNameController = TextEditingController();
  final noteController = TextEditingController();
  final quantityController = TextEditingController(text: "1");
  final fromAddressController = TextEditingController();
  final toAddressController = TextEditingController();
  final offerPriceController = TextEditingController();
  final creatorEarnController = TextEditingController();

  bool _isFormattingOfferPrice = false;
  bool _isFormattingCreatorEarn = false;

  Timer? _fromDebounce;
  Timer? _toDebounce;
  String _latestFromQuery = '';
  String _latestToQuery = '';
  String lastPassengerQuantity = "1";

  int selectedType = BrokerRideType.passenger;

  RidePointPayload? selectedFromPoint;
  RidePointPayload? selectedToPoint;
  AddressSelectionSource? fromSelectionSource;
  AddressSelectionSource? toSelectionSource;
  String? fromSelectedAddress;
  String? toSelectedAddress;
  TrackAsiaAutocompleteSuggestion? selectedFromSuggestion;
  TrackAsiaAutocompleteSuggestion? selectedToSuggestion;

  DateTime? pickupDate;
  TimeOfDay? pickupTime;

  bool loadingFromSuggestions = false;
  bool loadingToSuggestions = false;

  List<TrackAsiaAutocompleteSuggestion> fromSuggestions =
      <TrackAsiaAutocompleteSuggestion>[];
  List<TrackAsiaAutocompleteSuggestion> toSuggestions =
      <TrackAsiaAutocompleteSuggestion>[];

  OrderFormProvider() {
    offerPriceController.addListener(_handleOfferPriceChanged);
    creatorEarnController.addListener(_handleCreatorEarnChanged);
  }

  int? tryParseInt(String raw) => int.tryParse(raw.trim());

  num? tryParseNum(String raw) => num.tryParse(_normalizeMoneyInput(raw));

  int get normalizedQuantity {
    final rawQuantity = tryParseInt(quantityController.text) ?? 1;
    return BrokerRideType.normalizeQuantity(
      type: selectedType,
      quantity: rawQuantity,
    );
  }

  bool get hasFromSelection => selectedFromPoint?.isValid == true;

  bool get hasToSelection => selectedToPoint?.isValid == true;

  bool get requiresPassengerQuantity =>
      BrokerRideType.requiresPassengerQuantity(selectedType);

  bool get isCharterRide => BrokerRideType.isCharter(selectedType);

  String get quantityLabel => BrokerRideType.quantityLabelOf(selectedType);

  String get fromSelectionTitle {
    if (selectedFromSuggestion != null) {
      return selectedFromSuggestion!.primaryText;
    }
    return fromSelectedAddress?.trim().isNotEmpty == true
        ? fromSelectedAddress!.trim()
        : fromAddressController.text.trim();
  }

  String get toSelectionTitle {
    if (selectedToSuggestion != null) {
      return selectedToSuggestion!.primaryText;
    }
    return toSelectedAddress?.trim().isNotEmpty == true
        ? toSelectedAddress!.trim()
        : toAddressController.text.trim();
  }

  String get fromSelectionSubtitle {
    if (selectedFromSuggestion != null) {
      return selectedFromSuggestion!.secondaryText;
    }
    return fromSelectionSource == AddressSelectionSource.map
        ? 'Đã chọn trên bản đồ'
        : '';
  }

  String get toSelectionSubtitle {
    if (selectedToSuggestion != null) {
      return selectedToSuggestion!.secondaryText;
    }
    return toSelectionSource == AddressSelectionSource.map
        ? 'Đã chọn trên bản đồ'
        : '';
  }

  String formatDate(DateTime? date) =>
      date == null ? "" : DateFormat('dd/MM/yyyy').format(date);

  String formatTime(TimeOfDay? t) => t == null
      ? ""
      : "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  String? buildPickupIso() {
    if (pickupDate == null || pickupTime == null) return null;
    final dt = DateTime(
      pickupDate!.year,
      pickupDate!.month,
      pickupDate!.day,
      pickupTime!.hour,
      pickupTime!.minute,
    );
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String _normalizeMoneyInput(String raw) {
    return raw.replaceAll(',', '').trim();
  }

  String _formatMoneyInput(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    return _moneyFormatter.format(int.parse(digitsOnly));
  }

  void _formatMoneyController({
    required TextEditingController controller,
    required bool isFormatting,
    required ValueSetter<bool> setFormattingFlag,
  }) {
    if (isFormatting) return;

    final formatted = _formatMoneyInput(controller.text);
    if (formatted == controller.text) {
      notifyListeners();
      return;
    }

    setFormattingFlag(true);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setFormattingFlag(false);
    notifyListeners();
  }

  void _handleOfferPriceChanged() {
    _formatMoneyController(
      controller: offerPriceController,
      isFormatting: _isFormattingOfferPrice,
      setFormattingFlag: (value) => _isFormattingOfferPrice = value,
    );
  }

  void _handleCreatorEarnChanged() {
    _formatMoneyController(
      controller: creatorEarnController,
      isFormatting: _isFormattingCreatorEarn,
      setFormattingFlag: (value) => _isFormattingCreatorEarn = value,
    );
  }

  void onAddressTextChanged({required bool isFrom, required String query}) {
    final trimmed = query.trim();
    final hasSelection = isFrom ? hasFromSelection : hasToSelection;

    if (isFrom) {
      _latestFromQuery = trimmed;
      if (hasSelection) {
        selectedFromPoint = null;
        fromSelectionSource = null;
        fromSelectedAddress = null;
        selectedFromSuggestion = null;
      }
      fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingFromSuggestions = trimmed.length >= 2;
    } else {
      _latestToQuery = trimmed;
      if (hasSelection) {
        selectedToPoint = null;
        toSelectionSource = null;
        toSelectedAddress = null;
        selectedToSuggestion = null;
      }
      toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingToSuggestions = trimmed.length >= 2;
    }

    final debounce = isFrom ? _fromDebounce : _toDebounce;
    debounce?.cancel();

    if (trimmed.length < 2) {
      if (isFrom) {
        loadingFromSuggestions = false;
      } else {
        loadingToSuggestions = false;
      }
      notifyListeners();
      return;
    }

    notifyListeners();

    final timer = Timer(
      const Duration(milliseconds: 350),
      () => _fetchAutocomplete(isFrom: isFrom, query: trimmed),
    );

    if (isFrom) {
      _fromDebounce = timer;
    } else {
      _toDebounce = timer;
    }
  }

  void closeAutocompleteSuggestions() {
    _fromDebounce?.cancel();
    _toDebounce?.cancel();
    fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingFromSuggestions = false;
    loadingToSuggestions = false;
    notifyListeners();
  }

  Future<void> _fetchAutocomplete({
    required bool isFrom,
    required String query,
  }) async {
    try {
      final response = await ApiService.autocompleteTrackAsia(input: query);
      final latestQuery = isFrom ? _latestFromQuery : _latestToQuery;
      if (latestQuery != query) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = TrackAsiaAutocompleteResponse.fromRawJson(response.body);
        final suggestions = parsed.success
            ? parsed.data
            : <TrackAsiaAutocompleteSuggestion>[];

        if (isFrom) {
          fromSuggestions = suggestions;
          loadingFromSuggestions = false;
        } else {
          toSuggestions = suggestions;
          loadingToSuggestions = false;
        }
      } else {
        if (isFrom) {
          fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
          loadingFromSuggestions = false;
        } else {
          toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
          loadingToSuggestions = false;
        }
      }
    } catch (_) {
      if (isFrom) {
        fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
        loadingFromSuggestions = false;
      } else {
        toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
        loadingToSuggestions = false;
      }
    }

    notifyListeners();
  }

  void selectFromSuggestion(TrackAsiaAutocompleteSuggestion suggestion) {
    fromAddressController.value = TextEditingValue(
      text: suggestion.displayText,
      selection: TextSelection.collapsed(offset: suggestion.displayText.length),
    );

    selectedFromPoint = RidePointPayload.placeId(suggestion.placeId);
    fromSelectionSource = AddressSelectionSource.search;
    fromSelectedAddress = suggestion.displayText;
    selectedFromSuggestion = suggestion;
    fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingFromSuggestions = false;
    _latestFromQuery = suggestion.displayText.trim();
    notifyListeners();
  }

  void selectToSuggestion(TrackAsiaAutocompleteSuggestion suggestion) {
    toAddressController.value = TextEditingValue(
      text: suggestion.displayText,
      selection: TextSelection.collapsed(offset: suggestion.displayText.length),
    );

    selectedToPoint = RidePointPayload.placeId(suggestion.placeId);
    toSelectionSource = AddressSelectionSource.search;
    toSelectedAddress = suggestion.displayText;
    selectedToSuggestion = suggestion;
    toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingToSuggestions = false;
    _latestToQuery = suggestion.displayText.trim();
    notifyListeners();
  }

  void selectFromMapLocation(AddressResolvedLocation location) {
    final address = location.formattedAddress.trim();
    fromAddressController.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );

    selectedFromPoint = RidePointPayload.coordinates(
      lat: location.lat,
      lng: location.lng,
    );
    fromSelectionSource = AddressSelectionSource.map;
    fromSelectedAddress = address;
    selectedFromSuggestion = null;
    fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingFromSuggestions = false;
    _latestFromQuery = address;
    notifyListeners();
  }

  void selectToMapLocation(AddressResolvedLocation location) {
    final address = location.formattedAddress.trim();
    toAddressController.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );

    selectedToPoint = RidePointPayload.coordinates(
      lat: location.lat,
      lng: location.lng,
    );
    toSelectionSource = AddressSelectionSource.map;
    toSelectedAddress = address;
    selectedToSuggestion = null;
    toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingToSuggestions = false;
    _latestToQuery = address;
    notifyListeners();
  }

  void clearFromSelection() {
    fromAddressController.clear();
    selectedFromPoint = null;
    fromSelectionSource = null;
    fromSelectedAddress = null;
    selectedFromSuggestion = null;
    fromSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingFromSuggestions = false;
    _latestFromQuery = '';
    notifyListeners();
  }

  void clearToSelection() {
    toAddressController.clear();
    selectedToPoint = null;
    toSelectionSource = null;
    toSelectedAddress = null;
    selectedToSuggestion = null;
    toSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingToSuggestions = false;
    _latestToQuery = '';
    notifyListeners();
  }

  void updateRideType(int? nextType) {
    if (nextType == null || nextType == selectedType) return;

    if (requiresPassengerQuantity) {
      lastPassengerQuantity = quantityController.text.trim().isEmpty
          ? "1"
          : quantityController.text.trim();
    }

    selectedType = nextType;

    if (isCharterRide) {
      quantityController.text = "1";
    } else {
      quantityController.text = lastPassengerQuantity;
    }

    notifyListeners();
  }

  void setPickupDate(DateTime? value) {
    pickupDate = value;
    notifyListeners();
  }

  void setPickupTime(TimeOfDay? value) {
    pickupTime = value;
    notifyListeners();
  }

  String? validate() {
    if (customerNameController.text.trim().isEmpty) {
      return "Vui lòng nhập tên khách";
    }

    if (phoneController.text.trim().isEmpty) {
      return "Vui lòng nhập số điện thoại khách";
    }

    if (requiresPassengerQuantity) {
      final quantity = tryParseInt(quantityController.text);
      if (quantity == null || quantity < 1) {
        return "Số lượng phải là số nguyên ≥ 1";
      }
    }

    if (!hasFromSelection) {
      return "Vui lòng chọn điểm đón bằng gợi ý hoặc trên bản đồ";
    }

    if (!hasToSelection) {
      return "Vui lòng chọn điểm đến bằng gợi ý hoặc trên bản đồ";
    }

    if (selectedFromPoint!.identityKey == selectedToPoint!.identityKey) {
      return "Điểm đón và điểm trả không được trùng nhau";
    }

    final pickupIso = buildPickupIso();
    if (pickupIso == null) {
      return "Vui lòng chọn ngày & giờ đón";
    }

    final offer = tryParseNum(offerPriceController.text);
    if (offer == null || offer <= 0) {
      return "Vui lòng nhập giá chào hợp lệ";
    }

    final earn = tryParseNum(creatorEarnController.text);
    if (earn == null || earn <= 0) {
      return "Vui lòng nhập tiền nhận hợp lệ";
    }

    if (earn > offer) {
      return "Tiền nhận không được lớn hơn giá chào";
    }

    return null;
  }

  CreateBrokerRideRequest buildRequest({int? groupId}) {
    return CreateBrokerRideRequest(
      from: selectedFromPoint!,
      to: selectedToPoint!,
      fromDisplayAddress: (fromSelectedAddress ?? fromAddressController.text)
          .trim(),
      toDisplayAddress: (toSelectedAddress ?? toAddressController.text).trim(),
      type: selectedType,
      customerName: customerNameController.text.trim(),
      customerPhone: phoneController.text.trim(),
      quantity: normalizedQuantity,
      pickupTime: buildPickupIso()!,
      offerPrice: num.parse(_normalizeMoneyInput(offerPriceController.text)),
      creatorEarn: num.parse(_normalizeMoneyInput(creatorEarnController.text)),
      note: noteController.text.trim(),
      groupId: groupId,
    );
  }

  @override
  void dispose() {
    _fromDebounce?.cancel();
    _toDebounce?.cancel();
    offerPriceController.removeListener(_handleOfferPriceChanged);
    creatorEarnController.removeListener(_handleCreatorEarnChanged);
    phoneController.dispose();
    customerNameController.dispose();
    noteController.dispose();
    quantityController.dispose();
    fromAddressController.dispose();
    toAddressController.dispose();
    offerPriceController.dispose();
    creatorEarnController.dispose();
    super.dispose();
  }
}
