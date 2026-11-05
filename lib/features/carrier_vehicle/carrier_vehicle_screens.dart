// Màn hình chế độ "Xe nhà xe": quét QR xe → chuyến được gán hôm nay → vận hành chuyến (điểm dừng,
// danh sách khách, bắt đầu/hoàn thành) và gửi GPS cho khách có vé theo dõi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrier_vehicle_service.dart';

const _navy = Color(0xFF041565);

String _time(dynamic iso) => iso == null ? '—' : DateFormat('HH:mm').format(DateTime.parse('$iso').toLocal());

const _runStatus = {'SCHEDULED': 'Chưa chạy', 'BOARDING': 'Đang đón khách', 'RUNNING': 'Đang chạy', 'COMPLETED': 'Hoàn thành'};
const _bookingStatus = {'CONFIRMED': 'Chưa lên xe', 'BOARDED': 'Đã lên xe', 'NO_SHOW': 'Vắng mặt', 'COMPLETED': 'Hoàn thành'};

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Mở chế độ xe nhà xe: còn phiên thì vào thẳng danh sách chuyến, không thì mở màn quét QR.
Future<void> openCarrierVehicleMode(BuildContext context) async {
  final session = await CarrierVehicleService.load();
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => session != null ? const CarrierVehicleHomeScreen() : const CarrierQrScanScreen(),
  ));
}

void _backToScan(BuildContext context, String message) {
  _toast(context, message);
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const CarrierQrScanScreen()), (route) => route.isFirst);
}

// ------------------------------------------------------------------------- scan
class CarrierQrScanScreen extends StatefulWidget {
  const CarrierQrScanScreen({super.key});
  @override
  State<CarrierQrScanScreen> createState() => _CarrierQrScanScreenState();
}

class _CarrierQrScanScreenState extends State<CarrierQrScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login(String raw) async {
    if (_busy) return;
    if (!raw.contains('c=') || !raw.contains('k=')) {
      _toast(context, 'Đây không phải mã QR đăng nhập xe.');
      return;
    }
    setState(() => _busy = true);
    try {
      await CarrierVehicleService.exchange(raw, deviceLabel: 'App tài xế');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CarrierVehicleHomeScreen()));
    } on CarrierVehicleException catch (e) {
      if (mounted) _toast(context, e.message);
    } catch (_) {
      if (mounted) _toast(context, 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manual() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập nội dung mã QR'),
        content: TextField(controller: text, maxLines: 3, decoration: const InputDecoration(hintText: 'https://.../xe/qr#c=...&k=...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, text.text), child: const Text('Đăng nhập')),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) await _login(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Quét mã QR trên xe'), backgroundColor: _navy, foregroundColor: Colors.white),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
            if (raw != null) _login(raw);
          },
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(20)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Column(children: [
            if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: CircularProgressIndicator(color: Colors.white)),
            const Text(
              'Quét mã QR dán trên xe để vào chuyến. Không cần mật khẩu.\nKhông chụp/chia sẻ ảnh mã QR của xe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _manual,
              icon: const Icon(Icons.keyboard, color: Colors.white),
              label: const Text('Nhập mã thủ công', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------- runs today
class CarrierVehicleHomeScreen extends StatefulWidget {
  const CarrierVehicleHomeScreen({super.key});
  @override
  State<CarrierVehicleHomeScreen> createState() => _CarrierVehicleHomeScreenState();
}

class _CarrierVehicleHomeScreenState extends State<CarrierVehicleHomeScreen> {
  List<dynamic>? _runs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await CarrierVehicleService.runsToday();
      if (mounted) setState(() { _runs = runs; _error = null; });
    } on CarrierVehicleException catch (e) {
      if (!mounted) return;
      if (e.sessionEnded) return _backToScan(context, e.message);
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không kết nối được máy chủ.');
    }
  }

  Future<void> _logout() async {
    await CarrierVehicleService.logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = CarrierVehicleService.session;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xe ${s?.plate ?? ''}'),
          Text('${s?.carrierName ?? ''} · ${s?.category ?? ''}', style: const TextStyle(fontSize: 12)),
        ]),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Thoát xe')],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _runs == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_runs != null && _runs!.isEmpty)
                  const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: Text('Xe chưa được gán chuyến nào trong hôm nay.'))),
                ...?_runs?.map((r) => Card(
                      child: ListTile(
                        title: Text('${_time(r['plannedDepartureAt'])} · ${r['routeName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${_runStatus[r['status']] ?? r['status']} · ${r['passengers']} khách · ${(r['stops'] as List).length} điểm'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => CarrierRunScreen(run: Map<String, dynamic>.from(r as Map))))
                            .then((_) => _load()),
                      ),
                    )),
              ]),
      ),
    );
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

  int get _runId => _run['id'] as int;
  String get _status => '${_run['status']}';

  @override
  void initState() {
    super.initState();
    _gps.addListener(_onGps);
    _reload();
    if (_status == 'BOARDING' || _status == 'RUNNING') _startGps();
  }

  @override
  void dispose() {
    _gps.removeListener(_onGps);
    super.dispose();
  }

  void _onGps() {
    if (mounted) setState(() {});
  }

  Future<void> _startGps() async {
    final error = await _gps.start(_runId);
    if (error != null && mounted) _toast(context, error);
  }

  Future<void> _reload() async {
    try {
      final runs = await CarrierVehicleService.runsToday();
      final fresh = runs.cast<Map>().where((r) => r['id'] == _runId).toList();
      final manifest = await CarrierVehicleService.passengers(_runId);
      if (!mounted) return;
      setState(() {
        if (fresh.isNotEmpty) _run = Map<String, dynamic>.from(fresh.first);
        _manifest = manifest;
      });
    } on CarrierVehicleException catch (e) {
      if (!mounted) return;
      if (e.sessionEnded) return _backToScan(context, e.message);
      _toast(context, e.message);
    } catch (_) {
      if (mounted) _toast(context, 'Không kết nối được máy chủ.');
    }
  }

  Future<void> _do(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) _toast(context, done);
      await _reload();
    } on CarrierVehicleException catch (e) {
      if (!mounted) return;
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
        await _startGps();
      }, done: 'Đã bắt đầu chuyến. Vị trí xe đang được chia sẻ cho khách.');

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc chuyến?'),
        content: const Text('Xác nhận đã trả hết khách. Vị trí xe sẽ ngừng chia sẻ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Chưa')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kết thúc')),
        ],
      ),
    );
    if (ok != true) return;
    await _do(() async {
      await CarrierVehicleService.complete(_runId);
      await _gps.stop();
    }, done: 'Đã kết thúc chuyến.');
  }

  Widget _gpsBanner() {
    final active = _gps.active && _gps.runId == _runId;
    final sent = _gps.lastSentAt;
    final text = !active
        ? 'Chưa chia sẻ vị trí'
        : _gps.lastError ?? (sent == null ? 'Đang lấy vị trí...' : 'Đã gửi vị trí lúc ${DateFormat('HH:mm:ss').format(sent)}${_gps.pending > 0 ? ' · chờ gửi ${_gps.pending}' : ''}');
    return Container(
      padding: const EdgeInsets.all(12),
      color: active ? (_gps.lastError == null ? Colors.green.shade50 : Colors.orange.shade50) : Colors.grey.shade200,
      child: Row(children: [
        Icon(active ? Icons.gps_fixed : Icons.gps_off, color: active ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        if (!active && (_status == 'BOARDING' || _status == 'RUNNING')) TextButton(onPressed: _startGps, child: const Text('Bật lại')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = (_run['stops'] as List).cast<Map>();
    final bookings = ((_manifest?['bookings'] as List?) ?? []).cast<Map>();
    final open = _status == 'SCHEDULED' || _status == 'BOARDING' || _status == 'RUNNING';
    return Scaffold(
      appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white, title: Text('${_time(_run['plannedDepartureAt'])} · ${_run['routeName']}')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(children: [
          _gpsBanner(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Chip(label: Text(_runStatus[_status] ?? _status)),
              const SizedBox(width: 8),
              Text('${_manifest?['totalPassengers'] ?? _run['passengers']} khách'),
              const Spacer(),
              if (_status == 'SCHEDULED' || _status == 'BOARDING') FilledButton(onPressed: _busy ? null : _start, child: const Text('Bắt đầu chạy')),
              if (_status == 'RUNNING')
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: _busy ? null : _complete, child: const Text('Kết thúc')),
            ]),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Điểm dừng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ...stops.map((s) {
            final arrived = s['actualArrivalAt'] != null;
            final departed = s['actualDepartureAt'] != null;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: departed ? Colors.green : arrived ? Colors.orange : Colors.grey.shade300,
                child: Text('${s['sequence']}', style: const TextStyle(color: Colors.black)),
              ),
              title: Text('${_time(s['plannedArrivalAt'])} · ${s['name']}'),
              subtitle: Text('Đón ${s['pickupPassengers']} · Trả ${s['dropoffPassengers']}${arrived ? ' · đến ${_time(s['actualArrivalAt'])}' : ''}'),
              trailing: !open || departed
                  ? null
                  : TextButton(
                      onPressed: _busy ? null : () => _do(() => CarrierVehicleService.stopEvent(_runId, s['id'] as int, arrive: !arrived)),
                      child: Text(arrived ? 'Rời điểm' : 'Đã đến'),
                    ),
              onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s['latitude']},${s['longitude']}'),
                  mode: LaunchMode.externalApplication),
            );
          }),
          const Divider(),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Hành khách', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          if (_manifest == null) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_manifest != null && bookings.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có khách đặt vé.')),
          ...bookings.map((b) {
            final pickup = b['pickup'] as Map;
            final dropoff = b['dropoff'] as Map;
            final status = '${b['status']}';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${b['contactName']} · ${b['passengerCount']} người', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(_bookingStatus[status] ?? status, style: TextStyle(color: status == 'BOARDED' ? Colors.green : Colors.black54)),
                  ]),
                  Text('${pickup['name']} → ${dropoff['name']} · Vé ${b['code']}'),
                  if (b['note'] != null) Text('Ghi chú: ${b['note']}', style: const TextStyle(color: Colors.black54)),
                  Row(children: [
                    TextButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${b['contactPhone']}')), icon: const Icon(Icons.phone), label: Text('${b['contactPhone']}')),
                    const Spacer(),
                    if (open && status != 'BOARDED')
                      TextButton(onPressed: _busy ? null : () => _do(() => CarrierVehicleService.markBooking(_runId, '${b['code']}', boarded: true)), child: const Text('Đã lên xe')),
                    if (open && status == 'CONFIRMED')
                      TextButton(onPressed: _busy ? null : () => _do(() => CarrierVehicleService.markBooking(_runId, '${b['code']}', boarded: false)), child: const Text('Vắng')),
                  ]),
                ]),
              ),
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
