import 'dart:ui' as ui;

import 'package:galileo_flutter/galileo_flutter.dart';
import 'package:latlong2/latlong.dart';

extension MapLibreColorExt on ui.Color {
  MapLibreColor toGalileo() {
    return MapLibreColor(r: r, g: g, b: b, a: a);
  }
}

extension GalileoCoordinateExt on LatLng {
  GeoLocation toGalileo() {
    return GeoLocation(latitude: latitude, longitude: longitude);
  }
}
