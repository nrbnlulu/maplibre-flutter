import 'package:maplibre_flutter/maplibre_flutter.dart';
import 'package:latlong2/latlong.dart';

extension MapLibreCoordinateExt on LatLng {
  GeoLocation toMapLibre() {
    return GeoLocation(latitude: latitude, longitude: longitude);
  }
}
