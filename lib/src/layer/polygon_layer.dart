import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../extensions/latlng.dart';
import '../map/controller.dart';
import '../projection/path_projection.dart';
import '../projection/polygon_geometry.dart';
import 'controller.dart';

enum MapLibrePolygonLabelPlacement { centroid }

/// A geographic ring drawn in Flutter above the native map texture.
class MapLibrePolygon<T> {
  const MapLibrePolygon({
    required this.points,
    this.color = const Color(0x00000000),
    this.borderColor = const Color(0xff000000),
    this.borderStrokeWidth = 0,
    this.hitValue,
    this.label,
    this.labelPlacement = MapLibrePolygonLabelPlacement.centroid,
    this.labelStyle = const TextStyle(),
  });

  /// Treat this list as immutable. Supply a new list when the ring changes.
  final List<LatLng> points;
  final Color color;
  final Color borderColor;
  final double borderStrokeWidth;
  final T? hitValue;
  final String? label;
  final MapLibrePolygonLabelPlacement labelPlacement;
  final TextStyle labelStyle;
}

class MapLibreLayerHitResult<T> {
  const MapLibreLayerHitResult(this.hitValues);

  /// Matched values in topmost-first paint order.
  final List<T> hitValues;
}

typedef MapLibreLayerHitNotifier<T> = ValueNotifier<MapLibreLayerHitResult<T>?>;

/// Renders and hit tests geographic polygons using the same clipped paths.
/// Place this layer in an overlay that fills the map.
class MapLibrePolygonLayer<T> extends StatelessWidget {
  const MapLibrePolygonLayer({
    super.key,
    required this.controller,
    required this.polygons,
    this.hitNotifier,
  });

  final MapLibreMapController controller;
  final List<MapLibrePolygon<T>> polygons;
  final MapLibreLayerHitNotifier<T>? hitNotifier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => CustomPaint(
      painter: _PolygonPainter(
        polygons,
        controller.layerController,
        constraints.biggest,
        hitNotifier,
        Directionality.of(context),
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _PolygonPainter<T> extends CustomPainter {
  _PolygonPainter(
    this.polygons,
    this.layers,
    this.size,
    this.hitNotifier,
    this.direction,
  ) : super(repaint: layers.viewportListenable);

  final List<MapLibrePolygon<T>> polygons;
  final LayerController layers;
  final Size size;
  final MapLibreLayerHitNotifier<T>? hitNotifier;
  final TextDirection direction;
  static final _labelAnchors = Expando<({LatLng? point})>();

  LatLng? _labelAnchor(MapLibrePolygon<T> polygon) =>
      switch (polygon.labelPlacement) {
        MapLibrePolygonLabelPlacement.centroid =>
          (_labelAnchors[polygon.points] ??= (
            point: polygonLabelAnchor(polygon.points),
          )).point,
      };

  Path _path(MapLibrePolygon<T> polygon, MapLibrePathProjection projection) =>
      projection.projectPolygon([
        for (final point in polygon.points) point.toMapLibre(),
      ]);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = layers.viewportBounds;
    if (viewport == null || size.isEmpty) return;
    final projection = MapLibrePathProjection(viewport: viewport, size: size);

    for (final polygon in polygons) {
      if (polygon.points.length < 3) continue;
      final outline = _path(polygon, projection);
      if (outline.getBounds().isEmpty) continue;
      canvas.drawPath(outline, Paint()..color = polygon.color);
      if (polygon.borderStrokeWidth > 0) {
        canvas.drawPath(
          outline,
          Paint()
            ..color = polygon.borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = polygon.borderStrokeWidth
            ..strokeJoin = StrokeJoin.round,
        );
      }
      if (polygon.label case final String label) {
        final anchor = _labelAnchor(polygon);
        if (anchor == null) continue;
        final labelPoint = projection.projectPoint(anchor.toMapLibre());
        if (labelPoint == null || !outline.contains(labelPoint)) continue;
        final text = TextPainter(
          text: TextSpan(text: label, style: polygon.labelStyle),
          textDirection: direction,
        )..layout();
        text.paint(
          canvas,
          labelPoint - Offset(text.width / 2, text.height / 2),
        );
        text.dispose();
      }
    }
  }

  @override
  bool hitTest(Offset position) {
    final notifier = hitNotifier;
    if (notifier == null) return false;
    final viewport = layers.viewportBounds;
    final projection = viewport == null || size.isEmpty
        ? null
        : MapLibrePathProjection(viewport: viewport, size: size);
    final values = [
      if (projection != null)
        for (final polygon in polygons.reversed)
          if (polygon.hitValue case final T value)
            if (_path(polygon, projection).contains(position)) value,
    ];
    notifier.value = values.isEmpty ? null : MapLibreLayerHitResult(values);
    return values.isNotEmpty;
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter<T> old) =>
      old.polygons != polygons ||
      old.layers != layers ||
      old.size != size ||
      old.direction != direction;
}
