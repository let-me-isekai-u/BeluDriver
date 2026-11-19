import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../ui/ui.dart';
import 'driver_gps_tracker.dart';

class DriverLocationTile extends StatefulWidget {
  const DriverLocationTile({super.key, this.tracker});
  final DriverGpsTracker? tracker;

  @override
  State<DriverLocationTile> createState() => _DriverLocationTileState();
}

class _DriverLocationTileState extends State<DriverLocationTile>
    with WidgetsBindingObserver {
  static const _locationSettings = MethodChannel(
    'beludriver/location_settings',
  );
  DriverGpsTracker get _tracker => widget.tracker ?? DriverGpsTracker.instance;
  bool _starting = false;
  Completer<void>? _settingsReturn;
  bool _leftForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settingsReturn = _settingsReturn;
    if (settingsReturn == null || settingsReturn.isCompleted) return;
    if (state == AppLifecycleState.resumed) {
      if (_leftForSettings) settingsReturn.complete();
    } else {
      _leftForSettings = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final settingsReturn = _settingsReturn;
    if (settingsReturn != null && !settingsReturn.isCompleted) {
      settingsReturn.complete();
    }
    super.dispose();
  }

  Future<bool> _openSettings(DriverGpsSetupAction action) async {
    final settingsReturn = Completer<void>();
    _settingsReturn = settingsReturn;
    _leftForSettings = false;
    try {
      final opened = await (action == DriverGpsSetupAction.locationSettings
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings());
      if (!opened) throw StateError('Settings unavailable');
      await settingsReturn.future;
      return mounted;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa mở được Cài đặt. Hãy mở Cài đặt trên điện thoại rồi thử lại.',
            ),
          ),
        );
      }
      return false;
    } finally {
      _settingsReturn = null;
    }
  }

  Future<void> _startSharing() async {
    if (_starting || _tracker.busy) return;
    setState(() => _starting = true);
    final attempted = <DriverGpsSetupAction>{};
    try {
      while (mounted) {
        await _tracker.start();
        if (!mounted) return;
        final action = _tracker.setupAction;
        if (action == null || !attempted.add(action)) return;
        if (!await _resolveSetup(action) || !mounted) return;
        // Logout/stop can cancel this intent while a system screen is open.
        if (_tracker.setupAction != action ||
            _tracker.enabled ||
            _tracker.busy) {
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<bool> _resolveSetup(DriverGpsSetupAction action) async {
    final needsGps = action == DriverGpsSetupAction.locationSettings;
    if (needsGps &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        final outcome = await _locationSettings.invokeMethod<String>(
          'requestEnableLocation',
        );
        if (outcome == 'enabled' || outcome == 'closed') {
          return _waitForDeviceLocation();
        }
        if (outcome == 'cancelled') return false;
      } on PlatformException catch (_) {
        // Use the system settings page if the one-tap resolution is unavailable.
      } on MissingPluginException catch (_) {}
    }
    if (!mounted || _tracker.setupAction != action) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          needsGps ? 'Bật vị trí trên điện thoại?' : 'Cho phép truy cập vị trí',
        ),
        content: Text(
          needsGps
              ? 'Vị trí (GPS) đang tắt. Mở Cài đặt để bật vị trí; ứng dụng sẽ tiếp tục bật chia sẻ khi bạn quay lại.'
              : 'Quyền vị trí đã bị từ chối. Mở Cài đặt ứng dụng, chọn Quyền → Vị trí và cho phép truy cập để chia sẻ khi làm việc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _tracker.setupAction != action) {
      return false;
    }
    return _openSettings(action);
  }

  Future<bool> _waitForDeviceLocation() async {
    // Some devices update their location setting just after closing the dialog.
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!mounted ||
          _tracker.setupAction != DriverGpsSetupAction.locationSettings) {
        return false;
      }
      try {
        if (await _tracker.device.isServiceEnabled()) return true;
      } catch (_) {
        // Retry the status read without opening another dialog.
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) => Material(
        color: Brand.b50,
        child: SwitchListTile.adaptive(
          title: const Text(
            'Chia sẻ vị trí khi làm việc',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: tracker.lastError == null
              ? null
              : Text(tracker.lastError!, style: const TextStyle(fontSize: 12)),
          secondary: Icon(
            tracker.enabled ? Icons.location_on : Icons.location_off,
            color: Brand.navy,
          ),
          value: tracker.enabled,
          onChanged: tracker.busy || _starting
              ? null
              : (enabled) {
                  if (enabled) {
                    _startSharing();
                  } else {
                    tracker.stop();
                  }
                },
        ),
      ),
    );
  }
}
