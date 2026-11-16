import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../ui/brand.dart';

// Match the raster source already used by the customer app.
const String driverMapKey = String.fromEnvironment(
  'TRACKASIA_KEY',
  defaultValue: 'public',
);
const String driverMapTileUrl =
    'https://tiles.track-asia.com/raster-tiles/v2/{z}/{x}/{y}.png?key=$driverMapKey';

/// Basemap only: retrying tiles must not reset the selected point or GPS state.
class DriverMapLayer extends StatefulWidget {
  const DriverMapLayer({super.key, this.tileProviderFactory});

  final TileProvider Function()? tileProviderFactory;

  @override
  State<DriverMapLayer> createState() => _DriverMapLayerState();
}

class _DriverMapLayerState extends State<DriverMapLayer> {
  int _attempt = 0;
  bool _loadFailed = false;
  bool _errorScheduled = false;
  late TileProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.tileProviderFactory?.call() ?? NetworkTileProvider();
  }

  void _onTileError(int attempt, Object error) {
    if (!mounted || attempt != _attempt || _loadFailed || _errorScheduled) {
      return;
    }
    _errorScheduled = true;
    if (kDebugMode) {
      // Error strings may contain the URL/API key; log only the error type.
      debugPrint(
        '[DRIVER_MAP] tile load failed: ${error.runtimeType}; '
        'host=tiles.track-asia.com attempt=$attempt',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _errorScheduled = false;
        _loadFailed = true;
      });
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _loadFailed = false;
      _errorScheduled = false;
      // The old TileLayer disposes its provider when replaced by the new key.
      _provider = widget.tileProviderFactory?.call() ?? NetworkTileProvider();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    return Stack(
      fit: StackFit.expand,
      children: [
        TileLayer(
          key: ValueKey(attempt),
          urlTemplate: driverMapTileUrl,
          tileProvider: _provider,
          tileDimension: 512,
          zoomOffset: -1,
          maxNativeZoom: 16,
          maxZoom: 19,
          userAgentPackageName: 'com.belu.driver',
          evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
          errorTileCallback: (_, error, _) => _onTileError(attempt, error),
        ),
        const SimpleAttributionWidget(
          alignment: Alignment.topLeft,
          backgroundColor: Color(0xDDFFFFFF),
          source: Text(
            'TrackAsia · OpenStreetMap',
            style: TextStyle(fontSize: 10, color: Brand.ink),
          ),
        ),
        if (_loadFailed)
          Positioned(
            top: 64,
            left: 12,
            right: 12,
            child: Material(
              color: Brand.warning50,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Không tải được bản đồ. Kiểm tra kết nối rồi thử lại.',
                          style: TextStyle(color: Brand.ink, fontSize: 13),
                        ),
                      ),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
