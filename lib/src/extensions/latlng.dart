import 'package:latlong2/latlong.dart';

import '../rust/api/dart_types.dart';

extension MapLibreCoordinateExt on LatLng {
  GeoLocation toMapLibre() {
    return GeoLocation(latitude: latitude, longitude: longitude);
  }
}
