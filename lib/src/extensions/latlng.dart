import 'package:maplibre_flutter/maplibre_flutter.dart';
import 'package:latlong2/latlong.dart';

extension MapLibreCoordinateExt on LatLng {
  @Deprecated('Use toMapLibre instead')
  GeoLocation toGalileo() => toMapLibre();

  GeoLocation toMapLibre() {
    return GeoLocation(latitude: latitude, longitude: longitude);
  }
}
