import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../projection/path_projection.dart';
import '../rust/api/dart_types.dart';

const _worldWidth = 2 * math.pi * mercatorRadius;
const _tileSize = 256.0;
const _latitudeLimit = 85.0511;

/// A geographic envelope with longitudes in west-to-east order.
class MapLibreBounds {
  const MapLibreBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south, west, north, east;
}

/// Camera geometry for one completed texture frame, in physical pixels.
class MapLibreCamera {
  MapLibreCamera({required this.viewport, required this.size})
    : _projection = MapLibrePathProjection(viewport: viewport, size: size);

  final MapViewport viewport;
  final Size size;
  final MapLibrePathProjection _projection;

  double get bearing => viewport.bearing;
  double get pitch => viewport.pitch;

  GeoLocation get center => fromMercator(
    Offset(
      (viewport.xMin + viewport.xMax) / 2,
      (viewport.yMin + viewport.yMax) / 2,
    ),
  );

  /// Uses the same 256px-tile convention as `moveCamera` and `MapInitConfig`.
  double get zoom => zoomForViewportWidth(size.width);

  /// The zoom for the specified width in the caller's coordinate space.
  /// Pass the logical width to preserve logical-pixel zoom thresholds.
  double zoomForViewportWidth(double width) =>
      math.log(
        _worldWidth * width / (_tileSize * (viewport.xMax - viewport.xMin)),
      ) /
      math.ln2;

  /// The geographic envelope of the visible ground, accounting for rotation
  /// and pitch. Longitudes remain unwrapped around the current map center.
  MapLibreBounds get visibleBounds {
    final corners = [
      for (final corner in _corners(Offset.zero & size)) unproject(corner)!,
    ];
    return MapLibreBounds(
      south: corners.map((p) => p.latitude).reduce(math.min),
      west: corners.map((p) => p.longitude).reduce(math.min),
      north: corners.map((p) => p.latitude).reduce(math.max),
      east: corners.map((p) => p.longitude).reduce(math.max),
    );
  }

  /// Projects a location to a physical pixel, or null behind the camera.
  Offset? project(GeoLocation point) => _projection.projectPoint(point);

  /// Returns the ground point at a physical pixel.
  GeoLocation? unproject(Offset point) => _projection.unprojectPoint(point);

  /// Calculates a target that fits [bounds] at this frame's bearing and pitch.
  /// [padding] is in physical pixels. [center], when supplied, is placed at
  /// the center of the padded rectangle; otherwise the Mercator midpoint of
  /// the bounds is used. Bounds must not wrap across the antimeridian.
  /// Zoom limits and the limits of the Mercator world can prevent a full fit.
  ({GeoLocation center, double zoom})? cameraForBounds(
    MapLibreBounds bounds, {
    EdgeInsets padding = EdgeInsets.zero,
    GeoLocation? center,
    required double minZoom,
    required double maxZoom,
  }) {
    final rect = padding.deflateRect(Offset.zero & size);
    if (!rect.isFinite ||
        rect.isEmpty ||
        !padding.isNonNegative ||
        !minZoom.isFinite ||
        !maxZoom.isFinite ||
        maxZoom < minZoom ||
        !bounds.south.isFinite ||
        !bounds.west.isFinite ||
        !bounds.north.isFinite ||
        !bounds.east.isFinite ||
        bounds.south > bounds.north ||
        bounds.west > bounds.east ||
        bounds.west < -180 ||
        bounds.east > 180 ||
        (center != null &&
            (!center.latitude.isFinite ||
                !center.longitude.isFinite ||
                center.longitude.abs() > 180))) {
      return null;
    }
    final southwest = _groundPoint(bounds.south, bounds.west);
    final northeast = _groundPoint(bounds.north, bounds.east);
    final target = center == null
        ? (southwest + northeast) / 2
        : _groundPoint(center.latitude, center.longitude);
    final anchor = _projection.groundOffset(rect.center);
    final footprint = _corners(rect).map(_projection.groundOffset).toList();
    final extent = _corners(Rect.fromPoints(southwest, northeast));
    var scale = double.infinity;
    for (var i = 0; i < footprint.length; i++) {
      final start = footprint[i];
      final edge = footprint[(i + 1) % footprint.length] - start;
      // Stay inside each edge of the padded ground footprint. Projecting
      // that rectangle back to the ground handles pitch as well as bearing.
      final available = _cross(edge, anchor - start);
      for (final point in extent) {
        final required = _cross(edge, point - target);
        if (available * required < 0) {
          scale = math.min(scale, -available / required);
        }
      }
    }
    final zoom = (math.log(_worldWidth * scale / _tileSize) / math.ln2).clamp(
      minZoom,
      maxZoom,
    );
    final metersPerPixel = _worldWidth / (_tileSize * math.pow(2, zoom));
    return (center: fromMercator(target - anchor * metersPerPixel), zoom: zoom);
  }
}

List<Offset> _corners(Rect rect) => [
  rect.topLeft,
  rect.topRight,
  rect.bottomRight,
  rect.bottomLeft,
];

Offset _groundPoint(double latitude, double longitude) => toMercator(
  GeoLocation(
    latitude: latitude.clamp(-_latitudeLimit, _latitudeLimit),
    longitude: longitude,
  ),
);

double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
