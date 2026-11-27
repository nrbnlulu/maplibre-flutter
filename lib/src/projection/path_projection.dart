import 'dart:math' as math;
import 'dart:ui';

import '../rust/api/dart_types.dart' show GeoLocation, MapViewport;

const mercatorRadius = 6378137.0;

Offset toMercator(GeoLocation point) => Offset(
  point.longitude * math.pi / 180 * mercatorRadius,
  math.log(math.tan(math.pi / 4 + point.latitude * math.pi / 360)) *
      mercatorRadius,
);

GeoLocation fromMercator(Offset point) => GeoLocation(
  latitude:
      (2 * math.atan(math.exp(point.dy / mercatorRadius)) - math.pi / 2) *
      180 /
      math.pi,
  longitude: point.dx / mercatorRadius * 180 / math.pi,
);

/// Projects geographic paths onto a rendered MapLibre viewport.
///
/// Paths are clipped in camera space before perspective division. Unlike
/// point-by-point projection, this never connects behind-camera placeholder
/// coordinates into visible edges. No native bridge initialization is needed.
class MapLibrePathProjection {
  MapLibrePathProjection({required MapViewport viewport, required this.size})
    : _centerX = (viewport.xMin + viewport.xMax) / 2,
      _centerY = (viewport.yMin + viewport.yMax) / 2,
      _scale = size.width / (viewport.xMax - viewport.xMin),
      _sinBearing = math.sin(viewport.bearing * math.pi / 180),
      _cosBearing = math.cos(viewport.bearing * math.pi / 180),
      _sinPitch = math.sin(viewport.pitch * math.pi / 180),
      _cosPitch = math.cos(viewport.pitch * math.pi / 180);

  final Size size;
  final double _centerX, _centerY, _scale;
  final double _sinBearing, _cosBearing, _sinPitch, _cosPitch;

  // MapLibre's default FOV places the camera 1.5 viewport heights away.
  double get _distance => 1.5 * size.height;

  // At MapLibre's maximum pitch (60 degrees), this clipping plane projects
  // well below the viewport. A clipped ring's synthetic closing edge therefore
  // stays invisible, including when the ring is stroked.
  double get _nearDepth => _distance * 0.01;

  bool get _valid =>
      !size.isEmpty &&
      size.width.isFinite &&
      size.height.isFinite &&
      _scale.isFinite &&
      _scale > 0 &&
      _centerX.isFinite &&
      _centerY.isFinite &&
      _sinBearing.isFinite &&
      _sinPitch.isFinite;

  _CameraVertex? _cameraVertex(GeoLocation point) {
    if (!_valid ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() >= 90) {
      return null;
    }
    final meters = toMercator(point);
    final east = (meters.dx - _centerX) * _scale;
    final south = -(meters.dy - _centerY) * _scale;
    final x = east * _cosBearing + south * _sinBearing;
    final y = -east * _sinBearing + south * _cosBearing;
    final depth = _distance - y * _sinPitch;
    if (!x.isFinite || !y.isFinite || !depth.isFinite) return null;
    return _CameraVertex(x, y, depth);
  }

  Offset _screen(_CameraVertex point) {
    final k = _distance / point.depth;
    return Offset(
      size.width / 2 + point.x * k,
      size.height / 2 + point.y * _cosPitch * k,
    );
  }

  _CameraVertex _intersection(_CameraVertex a, _CameraVertex b) {
    final t = (_nearDepth - a.depth) / (b.depth - a.depth);
    return _CameraVertex(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
      _nearDepth,
    );
  }

  /// Projects a point, or returns null when it is invalid or behind the near
  /// plane. A non-null result can still be outside the viewport rectangle.
  Offset? projectPoint(GeoLocation point) {
    final vertex = _cameraVertex(point);
    return vertex == null || vertex.depth < _nearDepth ? null : _screen(vertex);
  }

  /// Ground point under a viewport pixel. Points above the horizon are
  /// clamped just below it, consistently with native pointer projection.
  GeoLocation? unprojectPoint(Offset point) {
    if (!_valid || !point.isFinite) return null;
    return fromMercator(
      Offset(_centerX, _centerY) + groundOffset(point) / _scale,
    );
  }

  // The meters from camera center at unit scale (one meter per pixel).
  Offset groundOffset(Offset point) {
    final u = point.dx - size.width / 2;
    var v = point.dy - size.height / 2;
    if (_sinPitch > 1e-9) {
      v = math.max(v, -_distance * _cosPitch / _sinPitch * 0.999);
    }
    final y = v * _distance / (_distance * _cosPitch + v * _sinPitch);
    final x = u * (_distance - y * _sinPitch) / _distance;
    return Offset(
      x * _cosBearing - y * _sinBearing,
      -x * _sinBearing - y * _cosBearing,
    );
  }

  /// Returns a closed path for a polygon ring, suitable for fill, stroke and
  /// hit testing. Fully hidden, invalid and fewer-than-three-point rings are
  /// empty. An explicitly repeated closing vertex is optional.
  Path projectPolygon(List<GeoLocation> points) {
    final path = Path();
    if (points.length < 3 || !_valid) return path;
    final vertices = <_CameraVertex>[];
    for (final point in points) {
      final vertex = _cameraVertex(point);
      if (vertex == null) return path;
      vertices.add(vertex);
    }
    final clipped = <_CameraVertex>[];
    var previous = vertices.last;
    for (final current in vertices) {
      final previousInside = previous.depth >= _nearDepth;
      final currentInside = current.depth >= _nearDepth;
      if (previousInside != currentInside) {
        clipped.add(_intersection(previous, current));
      }
      if (currentInside) clipped.add(current);
      previous = current;
    }
    if (clipped.length < 3) return path;
    final first = _screen(clipped.first);
    path.moveTo(first.dx, first.dy);
    for (final vertex in clipped.skip(1)) {
      final point = _screen(vertex);
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Returns an open path with disconnected contours across hidden portions.
  /// Each crossing edge is clipped individually, so a hidden run never creates
  /// an artificial connection between two visible sections. Invalid coordinates
  /// also break the path. Line styles and dashes can be applied to the result.
  Path projectPolyline(List<GeoLocation> points) {
    final path = Path();
    _CameraVertex? previous;
    var connected = false;
    for (final point in points) {
      final current = _cameraVertex(point);
      if (previous != null && current != null) {
        final previousInside = previous.depth >= _nearDepth;
        final currentInside = current.depth >= _nearDepth;
        if (previousInside || currentInside) {
          final start = _screen(
            previousInside ? previous : _intersection(previous, current),
          );
          final end = _screen(
            currentInside ? current : _intersection(previous, current),
          );
          if (!connected) path.moveTo(start.dx, start.dy);
          path.lineTo(end.dx, end.dy);
          connected = currentInside;
        } else {
          connected = false;
        }
      } else {
        connected = false;
      }
      previous = current;
    }
    return path;
  }
}

class _CameraVertex {
  const _CameraVertex(this.x, this.y, this.depth);
  final double x, y, depth;
}
