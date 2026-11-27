import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:polylabel/polylabel.dart' as poly;

/// Area centroid in local longitude/latitude coordinates. Degenerate rings
/// fall back to the vertex average; a closing vertex does not count twice.
LatLng? polygonCentroid(List<LatLng> points) {
  if (points.isEmpty) return null;
  final count = points.length > 1 && points.first == points.last
      ? points.length - 1
      : points.length;
  final origin = points.first;
  var twiceArea = 0.0;
  var xMoment = 0.0;
  var yMoment = 0.0;
  var sumLat = 0.0;
  var sumLng = 0.0;
  for (var i = 0; i < count; i++) {
    final a = points[i];
    final b = points[(i + 1) % count];
    final ax = a.longitude - origin.longitude;
    final ay = a.latitude - origin.latitude;
    final bx = b.longitude - origin.longitude;
    final by = b.latitude - origin.latitude;
    final cross = ax * by - bx * ay;
    twiceArea += cross;
    xMoment += (ax + bx) * cross;
    yMoment += (ay + by) * cross;
    sumLat += a.latitude;
    sumLng += a.longitude;
  }
  if (twiceArea.abs() < 1e-15) return LatLng(sumLat / count, sumLng / count);
  return LatLng(
    origin.latitude + yMoment / (3 * twiceArea),
    origin.longitude + xMoment / (3 * twiceArea),
  );
}

/// Use the centroid when it lies inside the sector, otherwise use the point
/// with the most clearance from its outline. Don't label a zero-area ring.
LatLng? polygonLabelAnchor(List<LatLng> points) {
  if (points.length < 3 ||
      points.any(
        (point) => !point.latitude.isFinite || !point.longitude.isFinite,
      )) {
    return null;
  }
  final center = polygonCentroid(points)!;
  var inside = false;
  for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    final a = points[i];
    final b = points[j];
    if ((a.latitude > center.latitude) != (b.latitude > center.latitude) &&
        center.longitude <
            (b.longitude - a.longitude) *
                    (center.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude) {
      inside = !inside;
    }
  }
  if (inside) return center;

  final result = poly.polylabel([
    [for (final point in points) math.Point(point.longitude, point.latitude)],
  ], precision: 0.000001);
  if (result.distance <= 0) return null;
  return LatLng(result.point.y.toDouble(), result.point.x.toDouble());
}
