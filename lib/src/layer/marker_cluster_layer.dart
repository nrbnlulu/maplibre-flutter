import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../extensions/latlng.dart';
import '../map/controller.dart';
import '../projection/path_projection.dart';
import 'marker_layer.dart';

/// A group of nearby widget markers and their Web Mercator centroid.
class MapLibreMarkerCluster<T> {
  MapLibreMarkerCluster._(this.center, List<T> members)
    : members = List.unmodifiable(members);

  final LatLng center;
  final List<T> members;
}

/// Groups projected widget markers within [radius] logical pixels. Single
/// markers keep their widgets; [clusterBuilder] renders groups of two or more.
class MapLibreMarkerClusterLayer<T> extends StatelessWidget {
  const MapLibreMarkerClusterLayer({
    super.key,
    required this.controller,
    required this.items,
    required this.positionOf,
    required this.markerBuilder,
    required this.clusterBuilder,
    this.radius = 45,
  }) : assert(radius > 0 && radius < double.infinity);

  final MapLibreMapController controller;
  final List<T> items;
  final LatLng Function(T) positionOf;
  final MapLibreMarker Function(T) markerBuilder;
  final MapLibreMarker Function(BuildContext, MapLibreMarkerCluster<T>)
  clusterBuilder;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final layers = controller.layerController;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: layers.viewportListenable,
        builder: (context, _) {
          final viewport = layers.viewportBounds;
          final size = constraints.biggest;
          if (viewport == null || size.isEmpty || items.isEmpty) {
            return const SizedBox.shrink();
          }
          final projection = MapLibrePathProjection(
            viewport: viewport,
            size: size,
          );
          final groups = groupProjectedMarkers(
            items,
            radius: radius,
            project: (item) =>
                projection.projectPoint(positionOf(item).toMapLibre()),
          );
          return MapLibreMarkerLayer(
            controller: controller,
            markers: [
              for (final group in groups)
                if (group.length == 1)
                  markerBuilder(group.single)
                else
                  clusterBuilder(
                    context,
                    MapLibreMarkerCluster._(_center(group), group),
                  ),
            ],
          );
        },
      ),
    );
  }

  LatLng _center(List<T> group) {
    final sum = group.fold(Offset.zero, (sum, item) {
      final point = positionOf(item);
      return sum +
          toMercator(
            LatLng(
              point.latitude.clamp(-85.0511, 85.0511),
              point.longitude,
            ).toMapLibre(),
          );
    });
    final center = fromMercator(sum / group.length.toDouble());
    return LatLng(center.latitude, center.longitude);
  }
}

List<List<T>> groupProjectedMarkers<T>(
  List<T> items, {
  required double radius,
  required Offset? Function(T) project,
}) {
  final groups = <List<T>>[];
  final cells = <(int, int), List<({int index, Offset position})>>{};
  final radiusSquared = radius * radius;
  for (final item in items) {
    final position = project(item);
    if (position == null || !position.isFinite) {
      groups.add([item]);
      continue;
    }
    final x = (position.dx / radius).floor();
    final y = (position.dy / radius).floor();
    int? firstMatch;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final anchors = cells[(x + dx, y + dy)];
        if (anchors == null) continue;
        for (final anchor in anchors) {
          if ((firstMatch == null || anchor.index < firstMatch) &&
              (anchor.position - position).distanceSquared < radiusSquared) {
            firstMatch = anchor.index;
          }
        }
      }
    }
    if (firstMatch == null) {
      // Keep the first marker as the anchor and prefer the earliest match.
      (cells[(x, y)] ??= []).add((index: groups.length, position: position));
      groups.add([item]);
    } else {
      groups[firstMatch].add(item);
    }
  }
  return groups;
}
