import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/broker_rides_model.dart';
import '../../models/driver/ride_model.dart';
import '../../services/api_service.dart';

class ActivityHistoryProvider extends ChangeNotifier {
  List<RideModel> ongoingRides = [];
  List<RideModel> historyRides = [];
  List<BrokerRideItem> brokerRides = [];

  bool isLoadingBroker = false;
  bool isBrokerLoaded = false;
  bool isLoadingOngoing = false;
  bool isOngoingLoaded = false;
  bool isLoadingHistory = false;
  bool isHistoryLoaded = false;

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  void preloadTabData(int initialTabIndex) {
    switch (initialTabIndex) {
      case 1:
        fetchHistoryRides();
        fetchOngoingRides();
        fetchBrokerRides();
        break;
      case 2:
        fetchBrokerRides();
        fetchOngoingRides();
        fetchHistoryRides();
        break;
      default:
        fetchOngoingRides();
        fetchHistoryRides();
        fetchBrokerRides();
    }
  }

  Future<void> fetchOngoingRides() async {
    isLoadingOngoing = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token.isEmpty) {
        ongoingRides = [];
        isOngoingLoaded = true;
        return;
      }

      final responses = await Future.wait([
        ApiService.getAcceptedRides(accessToken: token),
        ApiService.getProcessingRides(accessToken: token),
      ]);

      final acceptedRes = responses[0];
      final processingRes = responses[1];

      final List<RideModel> mergedRides = [];

      if (acceptedRes.statusCode == 200) {
        final body = jsonDecode(acceptedRes.body);
        if (body['success'] == true) {
          final acceptedData = (body['data'] as List? ?? const []);
          mergedRides.addAll(
            acceptedData
                .map((e) => RideModel.fromJson(e))
                .where((ride) => ride.status == 2),
          );
        }
      }

      if (processingRes.statusCode == 200) {
        final body = jsonDecode(processingRes.body);
        if (body['success'] == true) {
          final processingData = (body['data'] as List? ?? const []);
          mergedRides.addAll(
            processingData
                .map((e) => RideModel.fromJson(e))
                .where((ride) => ride.status == 3),
          );
        }
      }

      ongoingRides = _dedupeAndSortOngoingRides(mergedRides);
      isOngoingLoaded = true;
    } catch (e) {
      debugPrint("🔥 Fetch ongoing error: $e");
    } finally {
      isLoadingOngoing = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistoryRides() async {
    isLoadingHistory = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final res = await ApiService.getRideHistory(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          historyRides = (body['data'] as List)
              .map((e) => RideModel.fromJson(e))
              .toList();
          isHistoryLoaded = true;
        }
      }
    } catch (e) {
      debugPrint("🔥 Fetch history error: $e");
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> fetchBrokerRides() async {
    isLoadingBroker = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token.isEmpty) {
        brokerRides = [];
        isBrokerLoaded = true;
        return;
      }

      final res = await ApiService.getBrokerRides(accessToken: token);

      if (res.statusCode == 200) {
        final parsed = BrokerRidesResponse.fromRawJson(res.body);
        if (parsed.success) {
          brokerRides = parsed.data;
          isBrokerLoaded = true;
        }
      } else if (res.statusCode == 404) {
        brokerRides = [];
        isBrokerLoaded = true;
      }
    } catch (e) {
      debugPrint("🔥 Fetch broker rides error: $e");
    } finally {
      isLoadingBroker = false;
      notifyListeners();
    }
  }

  Future<bool> cancelBrokerRide(BrokerRideItem ride) async {
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.cancelBrokerRide(
      accessToken: token,
      rideId: ride.rideId,
    );

    if (res.statusCode == 200) {
      await fetchBrokerRides();
      return true;
    }

    return false;
  }

  Future<bool> startRide(RideModel ride) async {
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: ride.id,
      rideSource: ride.rideSource,
    );

    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> completeRide(RideModel ride) async {
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.completeRide(
      accessToken: token,
      rideId: ride.id,
      rideSource: ride.rideSource,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      await fetchOngoingRides();
      await fetchHistoryRides();
      return true;
    }

    return false;
  }

  String summaryCountText({
    required bool isLoaded,
    required bool isLoading,
    required int count,
  }) {
    if (isLoaded) return count.toString();
    if (isLoading) return '...';
    return '--';
  }

  List<RideModel> _dedupeAndSortOngoingRides(List<RideModel> rides) {
    final Map<String, RideModel> uniqueRides = {};

    for (final ride in rides) {
      if (ride.status != 2 && ride.status != 3) continue;
      final key = '${ride.id}_${ride.rideSource}';
      uniqueRides[key] = ride;
    }

    final result = uniqueRides.values.toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(
            b.createdAt,
          ).compareTo(DateTime.parse(a.createdAt));
        } catch (_) {
          return 0;
        }
      });

    return result;
  }
}
