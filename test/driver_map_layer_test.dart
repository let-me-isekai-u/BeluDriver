import 'dart:typed_data';

import 'package:beludriver_app/ui/brand.dart';
import 'package:beludriver_app/widgets/driver_map_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _Tiles extends TileProvider {
  _Tiles({this.fail = false});
  final bool fail;
  final urls = <String>[];
  bool disposed = false;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    urls.add(getTileUrl(coordinates, options));
    return MemoryImage(fail ? Uint8List(0) : TileProvider.transparentImage);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  Future<void> showMap(
    WidgetTester tester,
    MapController controller,
    TileProvider Function() factory,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme(),
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: const MapOptions(
              initialCenter: LatLng(21.235890, 105.773486),
              initialZoom: 16,
            ),
            children: [DriverMapLayer(tileProviderFactory: factory)],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('uses TrackAsia 512px raster tiles at the correct zoom', (
    tester,
  ) async {
    final controller = MapController();
    final tiles = _Tiles();
    await showMap(tester, controller, () => tiles);
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.tileDimension, 512);
    expect(layer.zoomOffset, -1);
    expect(layer.maxNativeZoom, 16);
    expect(tiles.urls, isNotEmpty);
    final url = Uri.parse(tiles.urls.first);
    expect(url.host, 'tiles.track-asia.com');
    expect(url.path, startsWith('/raster-tiles/v2/15/'));
    expect(url.queryParameters['key'], driverMapKey);
    expect(find.text('TrackAsia · OpenStreetMap'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed tiles show retry; retry keeps camera and recreates only tiles',
    (tester) async {
      final controller = MapController();
      final providers = <_Tiles>[];
      var fail = true;
      await showMap(tester, controller, () {
        final tiles = _Tiles(fail: fail);
        providers.add(tiles);
        return tiles;
      });
      expect(
        find.text('Không tải được bản đồ. Kiểm tra kết nối rồi thử lại.'),
        findsOneWidget,
      );
      controller.move(const LatLng(21.24, 105.78), 17);
      await tester.pump();
      final selectedCenter = controller.camera.center;
      final selectedZoom = controller.camera.zoom;
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(providers.length, 2);
      expect(providers.first.disposed, isTrue);
      expect(providers.last.urls, isNotEmpty);
      expect(find.text('Thử lại'), findsNothing);
      expect(controller.camera.center, selectedCenter);
      expect(controller.camera.zoom, selectedZoom);
      expect(tester.takeException(), isNull);
    },
  );
}
