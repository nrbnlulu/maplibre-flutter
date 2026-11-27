import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_flutter/maplibre_flutter.dart';

const _size = Size(900, 600);
const _worldWidth = 2 * math.pi * 6378137;
const _bounds = MapLibreBounds(south: 30, west: 33, north: 33, east: 36);

MapLibreCamera _camera({
  GeoLocation center = const GeoLocation(latitude: 0, longitude: 0),
  double zoom = 8,
  double bearing = 0,
  double pitch = 0,
}) {
  final x = center.longitude / 360 * _worldWidth;
  final y =
      _worldWidth /
      (2 * math.pi) *
      math.log(math.tan(math.pi / 4 + center.latitude * math.pi / 360));
  final metersPerPixel = _worldWidth / (256 * math.pow(2, zoom));
  return MapLibreCamera(
    size: _size,
    viewport: MapViewport(
      xMin: x - metersPerPixel * _size.width / 2,
      xMax: x + metersPerPixel * _size.width / 2,
      yMin: y - metersPerPixel * _size.height / 2,
      yMax: y + metersPerPixel * _size.height / 2,
      bearing: bearing,
      pitch: pitch,
    ),
  );
}

void main() {
  test('rendered geometry pairs projection and zoom with frame size', () {
    final camera = _camera(bearing: 35, pitch: 55);
    expect(camera.zoom, closeTo(8, 1e-10));
    expect(camera.zoomForViewportWidth(_size.width / 2), closeTo(7, 1e-10));
    expect(camera.project(camera.center), _size.center(Offset.zero));
    const pixel = Offset(120, 140);
    final projected = camera.project(camera.unproject(pixel)!)!;
    expect((projected - pixel).distance, lessThan(1e-8));
    expect(
      camera.visibleBounds.north,
      greaterThan(_camera().visibleBounds.north),
    );
  });

  test('fits all corners in asymmetric padding with bearing and pitch', () {
    const padding = EdgeInsets.fromLTRB(120, 30, 40, 100);
    final rect = padding.deflateRect(Offset.zero & _size);
    const center = GeoLocation(latitude: 32, longitude: 34);
    for (final (bearing, pitch) in [(0.0, 0.0), (37.0, 60.0)]) {
      final target = _camera(bearing: bearing, pitch: pitch).cameraForBounds(
        _bounds,
        padding: padding,
        center: center,
        minZoom: 2,
        maxZoom: 20,
      )!;
      final fitted = _camera(
        center: target.center,
        zoom: target.zoom,
        bearing: bearing,
        pitch: pitch,
      );
      expect((fitted.project(center)! - rect.center).distance, lessThan(1e-8));
      final corners = [
        for (final latitude in [_bounds.south, _bounds.north])
          for (final longitude in [_bounds.west, _bounds.east])
            GeoLocation(latitude: latitude, longitude: longitude),
      ];
      for (final point in corners) {
        expect(rect.inflate(1e-8).contains(fitted.project(point)!), isTrue);
      }
      final tooClose = _camera(
        center: target.center,
        zoom: target.zoom + 0.1,
        bearing: bearing,
        pitch: pitch,
      );
      expect(
        corners.any((point) => !rect.contains(tooClose.project(point)!)),
        isTrue,
      );
    }
  });

  test(
    'point bounds honor max zoom and an empty padded viewport is rejected',
    () {
      const point = MapLibreBounds(south: 0, west: 0, north: 0, east: 0);
      final camera = _camera();
      expect(camera.cameraForBounds(point, minZoom: 2, maxZoom: 16)?.zoom, 16);
      expect(
        camera.cameraForBounds(
          point,
          padding: const EdgeInsets.all(300),
          minZoom: 2,
          maxZoom: 16,
        ),
        isNull,
      );
    },
  );
}
