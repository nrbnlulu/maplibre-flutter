import 'dart:ui' as ui;

import 'package:maplibre_flutter/maplibre_flutter.dart';
import 'package:latlong2/latlong.dart';

extension MapLibreColorExt on ui.Color {
  MapLibreColor toMapLibre() {
    return MapLibreColor(r: r, g: g, b: b, a: a);
  }
}

extension MapLibreCoordinateExt on LatLng {
  GeoLocation toMapLibre() {
    return GeoLocation(latitude: latitude, longitude: longitude);
  }
}
