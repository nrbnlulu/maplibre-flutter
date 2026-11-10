import 'package:flutter/material.dart';
import 'package:galileo_flutter/galileo_flutter.dart';

const _mapSize = MapSize(width: 800, height: 600);

final _mapConfig = MapInitConfig(
  backgroundColor: const Color(0x1A1A0080).toMapLibre(),
  enableMultisampling: true,
  latlon: const GeoLocation(latitude: 40.71, longitude: -74.01),
  mapSize: _mapSize,
  zoomLevel: 5,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initMapLibre();
  runApp(const SimpleMapLibreApp());
}

class SimpleMapLibreApp extends StatelessWidget {
  const SimpleMapLibreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple MapLibre Rust Shell',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Simple MapLibre Map')),
        body: MapLibreMapWidget.fromConfig(
          size: _mapSize,
          config: _mapConfig,
          layers: const [LayerConfig.osm()],
        ),
      ),
    );
  }
}
