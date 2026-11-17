import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_flutter/maplibre_flutter.dart';

const _size = Size(1280, 800);
const _radius = 6378137.0;

// At this viewport scale, camera-ground pixels equal Mercator meters.
GeoLocation _location(double east, double south) => GeoLocation(
  latitude:
      (2 * math.atan(math.exp(-south / _radius)) - math.pi / 2) * 180 / math.pi,
  longitude: east / _radius * 180 / math.pi,
);

MapViewport _viewport({double bearing = 0, double pitch = 0}) => MapViewport(
  xMin: -640,
  xMax: 640,
  yMin: -400,
  yMax: 400,
  bearing: bearing,
  pitch: pitch,
);

MapLibrePathProjection _projection({double bearing = 0, double pitch = 0}) =>
    MapLibrePathProjection(
      viewport: _viewport(bearing: bearing, pitch: pitch),
      size: _size,
    );

List<GeoLocation> _rectangle(
  double left,
  double top,
  double right,
  double bottom,
) => [
  _location(left, top),
  _location(right, top),
  _location(right, bottom),
  _location(left, bottom),
];

void main() {
  test('flat polygon preserves geometry and closed hit-test area', () {
    final path = _projection().projectPolygon(_rectangle(-100, -100, 100, 100));
    expect(path.getBounds().left, closeTo(540, 1e-5));
    expect(path.getBounds().right, closeTo(740, 1e-5));
    expect(path.getBounds().top, closeTo(300, 1e-5));
    expect(path.getBounds().bottom, closeTo(500, 1e-5));
    expect(path.computeMetrics().single.isClosed, isTrue);
    expect(path.contains(const Offset(640, 400)), isTrue);
    expect(path.contains(const Offset(500, 400)), isFalse);
  });

  test('point projection matches bearing and perspective', () {
    for (final bearing in [0.0, 45.0, 90.0, 180.0, -45.0]) {
      for (final pitch in [0.0, 30.0, 60.0]) {
        final b = bearing * math.pi / 180;
        final p = pitch * math.pi / 180;
        final x = 80 * math.cos(b) + 60 * math.sin(b);
        final y = -80 * math.sin(b) + 60 * math.cos(b);
        final k = 1200 / (1200 - y * math.sin(p));
        final point = _projection(
          bearing: bearing,
          pitch: pitch,
        ).projectPoint(_location(80, 60));
        expect(point, isNotNull);
        expect(point!.dx, closeTo(640 + x * k, 1e-5));
        expect(point.dy, closeTo(400 + y * math.cos(p) * k, 1e-5));
      }
    }
  });

  test('cross-camera polygon retains visible area; old sentinel path fails', () {
    final projection = _projection(pitch: 60);
    final ring = _rectangle(-200, -2000, 200, 2000);
    final fixed = projection.projectPolygon(ring);
    expect(fixed.contains(const Offset(640, 400)), isTrue);
    expect(fixed.contains(const Offset(430, 400)), isFalse);
    expect(fixed.contains(const Offset(850, 400)), isFalse);
    // Negative control: the previous painter joined hidden-point placeholders.
    final old = Path();
    for (var i = 0; i < ring.length; i++) {
      final point =
          projection.projectPoint(ring[i]) ?? const Offset(-1e7, -1e7);
      if (i == 0) {
        old.moveTo(point.dx, point.dy);
      } else {
        old.lineTo(point.dx, point.dy);
      }
    }
    old.close();
    expect(old.contains(const Offset(640, 400)), isFalse);
    expect(fixed.getBounds().left, greaterThan(-1e7));
    expect(fixed.getBounds().bottom, lessThan(1e7));
  });

  test('large polygon covers viewport at multiple oblique angles', () {
    for (final bearing in [0.0, 45.0, 90.0, 180.0, -45.0]) {
      for (final pitch in [0.0, 30.0, 60.0]) {
        final path = _projection(
          bearing: bearing,
          pitch: pitch,
        ).projectPolygon(_rectangle(-5000, -5000, 5000, 5000));
        for (final point in [
          const Offset(10, 10),
          const Offset(1270, 10),
          const Offset(1270, 790),
          const Offset(10, 790),
        ]) {
          expect(
            path.contains(point),
            isTrue,
            reason: '$bearing/$pitch: $point',
          );
        }
      }
    }
  });

  test('fully hidden and invalid rings are empty', () {
    final projection = _projection(pitch: 60);
    expect(
      projection
          .projectPolygon(_rectangle(-100, 2000, 100, 3000))
          .computeMetrics(),
      isEmpty,
    );
    expect(projection.projectPoint(_location(0, 2000)), isNull);
    expect(
      projection.projectPolygon([
        _location(0, 0),
        _location(100, 0),
      ]).computeMetrics(),
      isEmpty,
    );
    expect(
      projection.projectPolygon([
        _location(0, 0),
        const GeoLocation(latitude: double.nan, longitude: 0),
        _location(100, 100),
      ]).computeMetrics(),
      isEmpty,
    );
    expect(
      projection.projectPoint(const GeoLocation(latitude: 90, longitude: 0)),
      isNull,
    );
  });

  test('polyline separates visible sections across a hidden run', () {
    final projection = _projection(pitch: 60);
    final path = projection.projectPolyline([
      _location(-200, -100),
      _location(-200, 2000),
      _location(200, 2000),
      _location(200, -100),
    ]);
    final metrics = path.computeMetrics().toList();
    expect(metrics, hasLength(2));
    expect(metrics.every((m) => !m.isClosed), isTrue);
    for (final metric in metrics) {
      for (var i = 0; i <= 100; i++) {
        final position = metric
            .getTangentForOffset(metric.length * i / 100)!
            .position;
        expect(position.dx.isFinite && position.dy.isFinite, isTrue);
        expect((position.dx - 640).abs(), greaterThan(100));
      }
    }
    expect(
      projection.projectPolyline([
        _location(0, 2000),
        _location(0, 3000),
      ]).computeMetrics(),
      isEmpty,
    );
  });

  test('invalid coordinates break lines without bridging the gap', () {
    final path = _projection().projectPolyline([
      _location(-200, 0),
      _location(-100, 0),
      const GeoLocation(latitude: double.nan, longitude: 0),
      _location(100, 0),
      _location(200, 0),
    ]);
    expect(path.computeMetrics().length, 2);
  });

  test(
    'polygon painters fill visible ground across a camera-plane crossing',
    () async {
      final vertices = _rectangle(-200, -2000, 200, 2000);
      for (final painter in [
        PolygonEditOverlayPainter(
          vertices: vertices,
          viewport: _viewport(pitch: 60),
        ),
        PendingPolygonPainter(
          vertices: vertices,
          viewport: _viewport(pitch: 60),
        ),
      ]) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, _size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(1280, 800);
        final pixels = await image.toByteData(format: ImageByteFormat.rawRgba);
        // The old sentinel-connected fill misses this visible ground point.
        expect(pixels!.getUint8((400 * 1280 + 640) * 4 + 3), greaterThan(0));
        image.dispose();
        picture.dispose();
      }
    },
  );

  test('zero-size and degenerate viewports produce empty paths', () {
    for (final projection in [
      MapLibrePathProjection(viewport: _viewport(), size: Size.zero),
      MapLibrePathProjection(
        viewport: const MapViewport(
          xMin: 0,
          xMax: 0,
          yMin: 0,
          yMax: 0,
          bearing: 0,
          pitch: 60,
        ),
        size: _size,
      ),
    ]) {
      expect(projection.projectPoint(_location(0, 0)), isNull);
      expect(
        projection
            .projectPolygon(_rectangle(-10, -10, 10, 10))
            .computeMetrics(),
        isEmpty,
      );
      expect(
        projection.projectPolyline([
          _location(0, 0),
          _location(10, 10),
        ]).computeMetrics(),
        isEmpty,
      );
    }
  });
}
