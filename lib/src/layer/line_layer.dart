import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:maplibre_flutter/src/map/controller.dart'
    show MapLibreMapController;
import 'package:maplibre_flutter/src/rust/api/dart_types.dart'
    show GeoLocation, MapViewport;

/// A geographic line rendered above the native map texture.
class MapLibreLine {
  const MapLibreLine({
    required this.points,
    required this.color,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.borderColor,
    this.borderStrokeWidth = 0,
    this.dashed = false,
    this.dashSegments = const [10, 6],
  });

  final List<LatLng> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final Color? borderColor;
  final double borderStrokeWidth;
  final bool dashed;
  final List<double> dashSegments;
}

/// Batched projected line overlay for dynamic geographic paths.
class MapLibreLineLayer extends StatelessWidget {
  const MapLibreLineLayer({
    super.key,
    required this.controller,
    required this.lines,
  });

  final MapLibreMapController controller;
  final List<MapLibreLine> lines;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ListenableBuilder(
      listenable: controller.layerController,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final viewport = controller.layerController.viewportBounds;
          if (viewport == null || size.isEmpty) return const SizedBox.shrink();
          return ClipRect(
            child: CustomPaint(
              painter: _LinePainter(lines: lines, viewport: viewport),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    ),
  );
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.lines, required this.viewport});

  final List<MapLibreLine> lines;
  final MapViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final geographic = [
      for (final line in lines)
        for (final point in line.points)
          GeoLocation(latitude: point.latitude, longitude: point.longitude),
    ];
    if (geographic.isEmpty) return;
    final projected = GeoLocation.pointsToScreen(
      points: geographic,
      height: size.height,
      width: size.width,
      vp: viewport,
    );
    var offset = 0;
    for (final line in lines) {
      final count = line.points.length;
      if (count < 2) {
        offset += count;
        continue;
      }
      final path = Path()..moveTo(projected[offset].x, projected[offset].y);
      for (var i = 1; i < count; i++) {
        path.lineTo(projected[offset + i].x, projected[offset + i].y);
      }
      offset += count;
      if (line.borderColor != null && line.borderStrokeWidth > 0) {
        _draw(
          canvas,
          path,
          Paint()
            ..color = line.borderColor!.withValues(
              alpha: line.borderColor!.a * line.opacity.clamp(0.0, 1.0),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = line.borderStrokeWidth + line.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      final paint = Paint()
        ..color = line.color.withValues(
          alpha: line.color.a * line.opacity.clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (line.dashed) {
        final segments = line.dashSegments.length >= 2
            ? line.dashSegments
            : const [10, 6];
        final dash = math.max(1.0, segments[0]);
        final gap = math.max(1.0, segments[1]);
        for (final metric in path.computeMetrics()) {
          for (
            var distance = 0.0;
            distance < metric.length;
            distance += dash + gap
          ) {
            canvas.drawPath(
              metric.extractPath(
                distance,
                math.min(distance + dash, metric.length),
              ),
              paint,
            );
          }
        }
      } else {
        _draw(canvas, path, paint);
      }
    }
  }

  void _draw(Canvas canvas, Path path, Paint paint) =>
      canvas.drawPath(path, paint);

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.lines != lines || old.viewport != viewport;
}
