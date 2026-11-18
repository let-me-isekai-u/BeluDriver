// Màn hình chế độ "Xe nhà xe": quét QR xe → chuyến được gán hôm nay → vận hành chuyến (điểm dừng,
// danh sách khách, bắt đầu/hoàn thành) và gửi GPS cho khách có vé theo dõi.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/ui.dart';
import '../../services/token_storage.dart';
import '../../services/active_session_mode.dart';
import '../../services/driver_session_navigation.dart';
import '../../services/vehicle_qr_payload.dart';
import 'carrier_vehicle_service.dart';

String _time(dynamic iso) => iso == null
    ? '—'
    : DateFormat('HH:mm').format(DateTime.parse('$iso').toLocal());

const _runStatus = {
  'SCHEDULED': 'Chưa chạy',
  'BOARDING': 'Đang đón khách',
  'RUNNING': 'Đang chạy',
  'COMPLETED': 'Hoàn thành',
};
Tone _runTone(String s) => switch (s) {
  'RUNNING' || 'BOARDING' => Tone.info,
  'COMPLETED' => Tone.success,
  _ => Tone.neutral,
};

void _toast(BuildContext context, String message) {
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Mở chế độ xe nhà xe: còn phiên thì vào thẳng danh sách chuyến, không thì mở màn quét QR.
bool _openingCarrierMode = false;
Future<void> openCarrierVehicleMode(BuildContext context) async {
  if (_openingCarrierMode) return;
  _openingCarrierMode = true;
  try {
    await ActiveSessionMode.remember(SessionMode.carrier);
    var session = await CarrierVehicleService.load();
    List<dynamic>? runs;
    if (session != null) {
      try {
        runs = await CarrierVehicleService.runsToday();
      } on CarrierVehicleException catch (error) {
        if (!error.sessionEnded) rethrow;
        session = null;
      }
      if (session != null) await ActiveSessionMode.remember(SessionMode.carrier);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: carrierRouteName),
        builder: (_) => session != null
            ? CarrierVehicleHomeScreen(initialRuns: runs)
            : CarrierQrScanScreen(initialMessage: CarrierVehicleService.sessionEndMessage),
      ),
    );
  } on TokenStorageException catch (e) {
    if (context.mounted) _toast(context, e.toString());
  } on CarrierVehicleException catch (error) {
    if (context.mounted) _toast(context, error.message);
  } catch (_) {
    if (context.mounted) _toast(context, 'Chưa thể khôi phục phiên xe. Kiểm tra kết nối và thử lại.');
  } finally {
    _openingCarrierMode = false;
  }
}

void _backToScan(BuildContext context, String message) {
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      settings: const RouteSettings(name: carrierRouteName),
      builder: (_) => CarrierQrScanScreen(initialMessage: message),
    ),
    (route) => route.isFirst && route.settings.name != carrierRouteName,
  );
}

Future<void> _exitCarrierMode(BuildContext context) async {
  await ActiveSessionMode.remember(SessionMode.driver);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  }
}

/// Header navy dùng chung cho các màn chế độ xe.
class _NavyHeader extends StatelessWidget {
  const _NavyHeader({required this.overline, required this.title, this.actions = const [], this.bottom, this.onBack});
  final String overline;
  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          color: Brand.navy,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 6, 8, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                tooltip: 'Quay lại',
                onPressed: onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(overline, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.b200, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
              ...actions,
            ]),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 0), child: bottom),
          ]),
        ),
      );
}

// ------------------------------------------------------------------------- scan
class CarrierQrScanScreen extends StatefulWidget {
  const CarrierQrScanScreen({super.key, this.initialMessage});
  final String? initialMessage;
  @override
  State<CarrierQrScanScreen> createState() => _CarrierQrScanScreenState();
}

class _CarrierQrScanScreenState extends State<CarrierQrScanScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _busy = false;
  bool _leaving = false;
  bool _paused = false;
  bool _manualOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_busy &&
          !_paused &&
          !_manualOpen && !_leaving &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        unawaited(_resumeScanner());
      }
    } else {
      unawaited(_pauseScanner());
    }
  }

  Future<void> _pauseScanner() async {
    try { await _controller.stop(); } catch (_) {
      // Manual QR input remains available without a working camera.
    }
  }

  Future<void> _resumeScanner() async {
    if (!mounted || _leaving) return;
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa mở được camera. Bạn có thể nhập mã thủ công.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _retryScan() async {
    if (_busy || _leaving || !mounted) return;
    if (CarrierVehicleService.coolingDown) {
      setState(() => _error = CarrierVehicleService.cooldownMessage);
      return;
    }
    setState(() {
      _paused = false;
      _error = null;
    });
    await _resumeScanner();
  }

  Future<void> _login(String raw) async {
    if (_busy || _leaving || !mounted) return;
    // Lock synchronously before camera/storage/network awaits.
    setState(() {
      _busy = true;
      _paused = true;
      _error = null;
    });
    var succeeded = false;
    try {
      await _pauseScanner();
      if (!isVehicleQrPayload(raw)) {
        throw CarrierVehicleException('Đây không phải mã QR đăng nhập xe.');
      }
      await CarrierVehicleService.exchange(
        raw,
        deviceLabel: 'App tài xế',
        canAccept: () =>
            mounted && !_leaving && (ModalRoute.of(context)?.isCurrent ?? false),
      );
      if (!mounted || _leaving || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      succeeded = true;
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: carrierRouteName),
          builder: (_) => const CarrierVehicleHomeScreen(),
        ),
      );
    } on CarrierVehicleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TokenStorageException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa đăng nhập được xe. Kiểm tra mã QR và kết nối rồi thử lại.',
        );
      }
    } finally {
      // Keep the detector locked throughout the outgoing route transition.
      if (mounted && !succeeded) setState(() => _busy = false);
    }
  }

  Future<void> _manual() async {
    if (_busy || _leaving || _manualOpen) return;
    _manualOpen = true;
    await _pauseScanner();
    if (!mounted) return;
    var entered = '';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã QR'),
        content: TextField(
          onChanged: (value) => entered = value,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'https://.../xe/qr#c=...&k=...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, entered),
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
    _manualOpen = false;
    if (!mounted) return;
    if (value != null && value.trim().isNotEmpty) {
      await _login(value.trim());
    } else if (!_paused) {
      await _resumeScanner();
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _pauseScanner();
    if (mounted) await _exitCarrierMode(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) unawaited(_leave()); },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              useAppLifecycleState: false,
              onDetect: (capture) {
                final raw = capture.barcodes.isEmpty
                    ? null
                    : capture.barcodes.first.rawValue;
                if (raw != null &&
                    !_busy && !_leaving &&
                    !_paused &&
                    !_manualOpen &&
                    (ModalRoute.of(context)?.isCurrent ?? false)) {
                  _login(raw);
                }
              },
            ),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Brand.lane, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: MediaQuery.of(context).padding.top + 6,
              child: IconButton(
                tooltip: 'Quay lại',
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                onPressed: _leave,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (_paused && !_busy)
                    TextButton(
                      onPressed: _retryScan,
                      child: const Text(
                        'Quét lại',
                        style: TextStyle(color: Brand.lane),
                      ),
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  const Text(
                    'Quét mã QR dán trên xe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Không chia sẻ ảnh mã QR của xe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _manual,
                    icon: const Icon(
                      Icons.keyboard_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Nhập mã',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ------------------------------------------------------------------------- runs today
class CarrierVehicleHomeScreen extends StatefulWidget {
  const CarrierVehicleHomeScreen({super.key, this.initialRuns});
  final List<dynamic>? initialRuns;
  @override
  State<CarrierVehicleHomeScreen> createState() =>
      _CarrierVehicleHomeScreenState();
}

class _CarrierVehicleHomeScreenState extends State<CarrierVehicleHomeScreen> {
  List<dynamic>? _runs;
  String? _error;
  Future<void>? _loadFlight;
  bool _loggingOut = false;
  bool _leaving = false;
  late final CarrierVehicleSession? _owner;

  @override
  void initState() {
    super.initState();
    _owner = CarrierVehicleService.session;
    _runs = widget.initialRuns;
    CarrierGpsTracker.instance.addListener(_onVehicleGps);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _runs == null) _load();
    });
  }

  @override
  void dispose() {
    CarrierGpsTracker.instance.removeListener(_onVehicleGps);
    super.dispose();
  }

  void _onVehicleGps() {
    if (_loggingOut || _leaving || CarrierVehicleService.session != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loggingOut && !_leaving && CarrierVehicleService.session == null) {
        _backToScan(context, 'Phiên xe đã kết thúc. Vui lòng quét lại mã QR.');
      }
    });
  }

  Future<void> _load() async {
    if (!mounted ||
        _loggingOut || _leaving ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    final pending = _loadFlight;
    if (pending != null) return pending;
    final flight = _loadRuns();
    _loadFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_loadFlight, flight)) _loadFlight = null;
    }
  }

  Future<void> _loadRuns() async {
    try {
      final runs = await CarrierVehicleService.runsToday();
      if (mounted &&
          !_loggingOut && !_leaving &&
          identical(_owner, CarrierVehicleService.session)) {
        setState(() {
          _runs = runs;
          _error = null;
        });
      }
    } on CarrierVehicleException catch (e) {
      if (!mounted ||
          _loggingOut || _leaving ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      if (CarrierVehicleService.session != null &&
          !identical(_owner, CarrierVehicleService.session)) {
        return;
      }
      if (e.sessionEnded) return _backToScan(context, e.message);
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted &&
          !_loggingOut && !_leaving &&
          identical(_owner, CarrierVehicleService.session)) {
        setState(() => _error = 'Không kết nối được máy chủ.');
      }
    }
  }

  Future<void> _logout() async {
    if (_loggingOut || _leaving) return;
    setState(() => _loggingOut = true);
    try {
      await CarrierVehicleService.logout();
      if (mounted) await _exitCarrierMode(context);
    } on TokenStorageException catch (e) {
      if (mounted) _toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving || _loggingOut) return;
    _leaving = true;
    await _exitCarrierMode(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = CarrierVehicleService.session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) unawaited(_leave()); },
      child: Scaffold(
      backgroundColor: Brand.canvas,
      body: Column(children: [
        _NavyHeader(
          onBack: _leave,
          overline: '${s?.carrierName ?? ''} · ${s?.category ?? ''}',
          title: 'Xe ${s?.plate ?? ''}',
          actions: [
            IconButton(tooltip: 'Thoát xe', onPressed: _loggingOut ? null : _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white)),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _runs == null && _error == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    if (_error != null) InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline_rounded),
                    if (_runs != null && _runs!.isEmpty)
                      const EmptyState(icon: Icons.event_busy_rounded, title: 'Hôm nay chưa có chuyến', message: 'Kéo xuống để tải lại.'),
                    if (_runs != null && _runs!.isNotEmpty) const SectionHeader('Chuyến hôm nay'),
                    ...?_runs?.map((r) {
                      final status = '${r['status']}';
                      return BrandCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        onTap: _loggingOut ? null : () => Navigator.of(context)
                            .push(MaterialPageRoute(settings: const RouteSettings(name: carrierRouteName), builder: (_) => CarrierRunScreen(run: Map<String, dynamic>.from(r as Map))))
                            .then((_) => _load()),
                        child: Row(children: [
                          Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(14)),
                            child: Text(_time(r['plannedDepartureAt']),
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.navy)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['routeName']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Chuyến #${r['id']} · ${r['plannedDepartureAt'] == null ? '—' : DateFormat('dd/MM').format(DateTime.parse('${r['plannedDepartureAt']}').toLocal())}',
                                  style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
                              const SizedBox(height: 4),
                              Text('${r['passengers']} khách · ${(r['stops'] as List).length} điểm',
                                  style: const TextStyle(fontSize: 13, color: Brand.inkMuted)),
                            ]),
                          ),
                          StatusChip(_runStatus[status] ?? status, tone: _runTone(status), dense: true),
                        ]),
                      );
                    }),
                  ]),
          ),
        ),
      ]),
    ));
  }
}

// ------------------------------------------------------------------------- run
class CarrierRunScreen extends StatefulWidget {
  const CarrierRunScreen({super.key, required this.run});
  final Map<String, dynamic> run;
  @override
  State<CarrierRunScreen> createState() => _CarrierRunScreenState();
}

class _CarrierRunScreenState extends State<CarrierRunScreen> {
  late Map<String, dynamic> _run = widget.run;
  Map<String, dynamic>? _manifest;
  bool _busy = false;
  final _gps = CarrierGpsTracker.instance;
  late final CarrierVehicleSession? _owner;
  Future<void>? _reloadFlight;
  String? _loadError;

  int get _runId => _run['id'] as int;
  String get _status => '${_run['status']}';
  bool get _open =>
      _status == 'SCHEDULED' || _status == 'BOARDING' || _status == 'RUNNING';

  @override
  void initState() {
    super.initState();
    _gps.addListener(_onGps);
    _owner = CarrierVehicleService.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _gps.removeListener(_onGps);
    super.dispose();
  }

  void _onGps() {
    if (!mounted) return;
    setState(() {});
    if (CarrierVehicleService.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && CarrierVehicleService.session == null) {
          _backToScan(context, 'Phiên xe đã kết thúc. Vui lòng quét lại mã QR.');
        }
      });
    }
  }

  Future<void> _startGps() async {
    if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
    try {
      final error = await _gps.start(_runId);
      if (error != null && mounted) _toast(context, error);
    } catch (_) {
      if (mounted) _toast(context, 'Chưa bật được GPS. Kiểm tra quyền vị trí và thử lại.');
    }
  }

  Future<void> _reload() async {
    if (!mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        !identical(_owner, CarrierVehicleService.session)) {
      return;
    }
    final pending = _reloadFlight;
    if (pending != null) return pending;
    final flight = _reloadRun();
    _reloadFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_reloadFlight, flight)) _reloadFlight = null;
    }
  }

  Future<void> _reloadRun() async {
    try {
      final runs = await CarrierVehicleService.runsToday();
      final fresh = runs.cast<Map>().where((r) => r['id'] == _runId).toList();
      if (fresh.isEmpty) {
        if (_gps.runId == _runId) await _gps.stop(sendPending: false);
        throw CarrierVehicleException('Chuyến không còn trong danh sách được giao cho xe.', statusCode: 404);
      }
      if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
      final manifest = await CarrierVehicleService.passengers(_runId);
      if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
      setState(() {
        if (fresh.isNotEmpty) _run = Map<String, dynamic>.from(fresh.first);
        _manifest = manifest;
        _loadError = null;
      });
      if (_status == 'BOARDING' || _status == 'RUNNING') {
        await _startGps();
      } else if (_gps.runId == _runId) {
        await _gps.stop(sendPending: false);
      }
    } on CarrierVehicleException catch (e) {
      if (!mounted) return;
      if (CarrierVehicleService.session != null &&
          !identical(_owner, CarrierVehicleService.session)) {
        return;
      }
      if (e.sessionEnded) return _backToScan(context, e.message);
      setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Không kết nối được máy chủ.');
    }
  }

  Future<void> _do(Future<void> Function() action, {String? done}) async {
    if (_busy || !mounted || !identical(_owner, CarrierVehicleService.session)) {
      return;
    }
    if (CarrierVehicleService.coolingDown) {
      _toast(context, CarrierVehicleService.cooldownMessage);
      return;
    }
    setState(() => _busy = true);
    try {
      final pending = _reloadFlight;
      if (pending != null) await pending;
      if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
      await action();
      if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
      if (done != null && mounted) _toast(context, done);
      await _reload();
    } on CarrierVehicleException catch (e) {
      if (!mounted) return;
      if (CarrierVehicleService.session != null &&
          !identical(_owner, CarrierVehicleService.session)) {
        return;
      }
      if (e.sessionEnded) return _backToScan(context, e.message);
      _toast(context, e.message);
    } catch (_) {
      if (mounted) _toast(context, 'Không kết nối được máy chủ. Thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _do(() async {
    await CarrierVehicleService.start(_runId);
    if (!mounted || !identical(_owner, CarrierVehicleService.session)) return;
    setState(() => _run = {..._run, 'status': 'RUNNING'});
    await _startGps();
  }, done: 'Đã bắt đầu chuyến.');

  Future<void> _complete({bool confirm = true}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kết thúc chuyến?'),
          content: const Text('Vị trí xe sẽ ngừng chia sẻ.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Chưa'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kết thúc'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _do(() async {
      await CarrierVehicleService.complete(_runId);
      if (identical(_owner, CarrierVehicleService.session) && _gps.runId == _runId) {
        await _gps.stop();
      }
    }, done: 'Đã kết thúc chuyến.');
  }

  void _openMap(Map s) => launchUrl(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${s['latitude']},${s['longitude']}',
    ),
    mode: LaunchMode.externalApplication,
  );

  /// Giống Grab/Be: app phải được phép chạy nền, không bị tối ưu pin, và Vị trí của máy phải bật.
  Future<void> _gpsHelp() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Giữ GPS chạy khi tắt màn hình'),
      content: const SingleChildScrollView(
        child: Text(
          '1. Bật Vị trí (GPS) của điện thoại.\n'
          '2. Quyền vị trí cho app: "Cho phép khi dùng ứng dụng".\n'
          '3. Pin: đặt "Không giới hạn" cho app.\n'
          '   • Xiaomi: Tiết kiệm pin → Không hạn chế, bật Tự khởi chạy.\n'
          '   • Oppo/Realme: Pin → Cho phép hoạt động nền.\n'
          '   • Vivo: Pin → Tiêu thụ điện nền cao.\n'
          '   • Samsung: Ứng dụng → Pin → Không hạn chế.\n'
          '4. Không vuốt tắt app khi đang chạy chuyến.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Geolocator.openLocationSettings(),
          child: const Text('Cài đặt vị trí'),
        ),
        TextButton(
          onPressed: () => Geolocator.openAppSettings(),
          child: const Text('Cài đặt app'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  Widget _gpsPill() {
    final active = _gps.active && _gps.runId == _runId;
    final sent = _gps.lastSentAt;
    final ok = active && _gps.lastError == null;
    final label = !active
        ? 'GPS đang tắt'
        : _gps.lastError != null
        ? 'GPS lỗi'
        : sent == null
        ? 'Đang lấy vị trí...'
        : 'GPS · gửi lúc ${DateFormat('HH:mm').format(sent)}';
    return Material(
      color: ok ? const Color(0x3D0F8A4A) : const Color(0x33FCC419),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: !active && (_status == 'BOARDING' || _status == 'RUNNING')
            ? _startGps
            : _gpsHelp,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFF4ADE80) : Brand.lane,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: ok ? const Color(0xFFB8F5D0) : Brand.lane300,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = CarrierVehicleService.session;
    final stops = (_run['stops'] as List).cast<Map>();
    final bookings = ((_manifest?['bookings'] as List?) ?? []).cast<Map>();
    final total = (_manifest?['totalPassengers'] as num?)?.toInt() ?? (_run['passengers'] as num?)?.toInt() ?? 0;
    final boarded = bookings
        .where((b) => b['status'] == 'BOARDED' || b['status'] == 'COMPLETED')
        .fold<int>(0, (sum, b) => sum + ((b['passengerCount'] as num?)?.toInt() ?? 0));
    final currentIndex = stops.indexWhere((st) => st['actualDepartureAt'] == null);
    final current = currentIndex < 0 ? null : stops[currentIndex];

    return Scaffold(
      backgroundColor: Brand.canvas,
      body: Column(children: [
        _NavyHeader(
          overline: '${s?.plate ?? ''} · ${s?.category ?? ''}',
          title: '${_run['routeName']} · ${_time(_run['plannedDepartureAt'])}',
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Thêm',
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (v) {
                if (v == 'gps') _gpsHelp();
                if (v == 'end') _complete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'gps', child: Text('Hướng dẫn giữ GPS')),
                if (_status == 'RUNNING') const PopupMenuItem(value: 'end', child: Text('Kết thúc chuyến')),
              ],
            ),
          ],
          bottom: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _gpsPill(),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(_runStatus[_status] ?? _status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : boarded / total,
                    minHeight: 8,
                    color: Brand.lane,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$boarded/$total khách đã lên', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              if (_loadError != null) InfoBanner(_loadError!, tone: Tone.danger, icon: Icons.error_outline_rounded),
              for (var i = 0; i < stops.length; i++)
                _StopTile(
                  stop: stops[i],
                  last: i == stops.length - 1,
                  current: i == currentIndex,
                  busy: _busy,
                  open: _open,
                  bookings: bookings.where((b) => (b['pickup'] as Map)['id'] == stops[i]['id']).toList(),
                  onMap: () => _openMap(stops[i]),
                  onBoard: (code, boarded) => _do(() => CarrierVehicleService.markBooking(_runId, code, boarded: boarded)),
                ),
              if (_manifest == null && _loadError == null) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ]),
          ),
        ),
        if (_open) _bottomBar(current),
      ]),
    );
  }

  Widget _bottomBar(Map? current) {
    Widget child;
    if (_status == 'SCHEDULED' || _status == 'BOARDING') {
      child = SwipeToConfirm(label: 'Trượt để bắt đầu chuyến', enabled: !_busy, onConfirmed: _start);
    } else if (current == null) {
      child = SwipeToConfirm(label: 'Trượt để kết thúc chuyến', enabled: !_busy, onConfirmed: () => _complete(confirm: false));
    } else {
      final arrived = current['actualArrivalAt'] != null;
      child = Row(children: [
        Tooltip(
          message: 'Chỉ đường',
          child: Material(
            color: Brand.b50,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openMap(current),
              child: const SizedBox(width: 56, height: 56, child: Icon(Icons.map_outlined, color: Brand.navy)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryCta(
            label: arrived ? 'Rời ${current['name']}' : 'Đã đến ${current['name']}',
            loading: _busy,
            onPressed: () => _do(() => CarrierVehicleService.stopEvent(_runId, current['id'] as int, arrive: !arrived)),
          ),
        ),
      ]);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x14041565), blurRadius: 20, offset: Offset(0, -4))]),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child)),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.last,
    required this.current,
    required this.busy,
    required this.open,
    required this.bookings,
    required this.onMap,
    required this.onBoard,
  });
  final Map stop;
  final bool last, current, busy, open;
  final List<Map> bookings;
  final VoidCallback onMap;
  final void Function(String code, bool boarded) onBoard;

  @override
  Widget build(BuildContext context) {
    final departed = stop['actualDepartureAt'] != null;
    final arrived = stop['actualArrivalAt'] != null;
    final pick = (stop['pickupPassengers'] as num?)?.toInt() ?? 0;
    final drop = (stop['dropoffPassengers'] as num?)?.toInt() ?? 0;
    final detail = [
      departed ? 'Đã rời ${_time(stop['actualDepartureAt'])}' : arrived ? 'Đã đến ${_time(stop['actualArrivalAt'])}' : _time(stop['plannedArrivalAt']),
      if (pick > 0) 'đón $pick',
      if (drop > 0) 'trả $drop',
    ].join(' · ');

    final dot = departed
        ? Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Brand.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          )
        : Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: current ? Brand.navy : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: current ? Brand.b100 : Brand.b200, width: current ? 5 : 3),
            ),
          );

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          dot,
          if (!last)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: departed ? Container(width: 2, color: Brand.success) : const DashedLine(color: Brand.b200),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: onMap,
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${stop['name']}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: departed || current ? Brand.ink : Brand.inkMuted)),
                      Text(detail, style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
                    ]),
                  ),
                  if (current && arrived) StatusChip(pick > 0 ? 'Đang đón' : 'Đã đến', tone: Tone.info, dense: true),
                ]),
              ),
              if (bookings.isNotEmpty) ...[
                const SizedBox(height: 10),
                BrandCard(
                  padding: EdgeInsets.zero,
                  radius: 16,
                  child: Column(children: [
                    for (var i = 0; i < bookings.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _PassengerRow(booking: bookings[i], busy: busy, open: open, onBoard: onBoard),
                    ],
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.booking, required this.busy, required this.open, required this.onBoard});
  final Map booking;
  final bool busy, open;
  final void Function(String code, bool boarded) onBoard;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = '${b['status']}';
    final note = '${b['note'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${b['contactName']} · ${b['passengerCount']} khách',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(
              note.isEmpty ? 'Trả: ${(b['dropoff'] as Map)['name']}' : 'Trả: ${(b['dropoff'] as Map)['name']} · $note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Brand.inkMuted),
            ),
          ]),
        ),
        IconButton(
          tooltip: 'Gọi ${b['contactName']}',
          onPressed: () => launchUrl(Uri.parse('tel:${b['contactPhone']}')),
          style: IconButton.styleFrom(backgroundColor: Brand.b50),
          icon: const Icon(Icons.phone_rounded, color: Brand.navy, size: 20),
        ),
        const SizedBox(width: 4),
        if (status == 'CONFIRMED' && open) ...[
          OutlinedButton(
            onPressed: busy ? null : () => onBoard('${b['code']}', false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.danger,
              side: const BorderSide(color: Color(0xFFF3C2C2), width: 1.5),
              minimumSize: const Size(52, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Vắng'),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: busy ? null : () => onBoard('${b['code']}', true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(64, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Lên xe', style: TextStyle(fontSize: 14)),
          ),
        ] else
          StatusChip(
            switch (status) { 'BOARDED' => 'Đã lên xe', 'NO_SHOW' => 'Vắng', 'COMPLETED' => 'Đã trả', _ => 'Chưa lên' },
            tone: switch (status) { 'BOARDED' || 'COMPLETED' => Tone.success, 'NO_SHOW' => Tone.danger, _ => Tone.neutral },
            dense: true,
          ),
      ]),
    );
  }
}
