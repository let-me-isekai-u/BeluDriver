import 'package:flutter/material.dart';
import 'token_storage.dart';

const carrierRouteName = '/carrier-vehicle';

/// Driver expiry must not dismiss an independent vehicle route (or its dialog).
class DriverSessionNavigation extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  bool _driverExpired = false;
  bool _scheduled = false;

  void driverExpired() {
    _driverExpired = true;
    _check();
  }

  void _check() {
    if (!_driverExpired || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final token = await TokenStorage.instance.readAccessToken();
        if (token != null) {
          _driverExpired = false;
          return;
        }
        // Startup owns fallback selection until it replaces its route.
        if (_routes.any(
          (r) =>
              r.settings.name == carrierRouteName ||
              r.settings.name == '/splash',
        ))
          return;
        _driverExpired = false;
        if (_routes.lastOrNull?.settings.name != '/login') {
          navigator?.pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } on TokenStorageException {
        // A storage outage is not a reason to dismiss either mode.
      } finally {
        _scheduled = false;
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _check();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _check();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _check();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _check();
  }
}
