import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../extensions/latlng.dart';
import '../map/controller.dart';
import '../rust/api/dart_types.dart';

/// A Flutter widget anchored to a geographic point.
class MapLibreMarker {
  const MapLibreMarker({
    required this.point,
    required this.child,
    this.width = 50,
    this.height = 50,
    this.alignment = Alignment.center,
    this.scale = 1,
    this.key,
  });

  final LatLng point;
  final Widget child;
  final double width;
  final double height;

  /// The point on the widget that stays anchored when the marker scales.
  final Alignment alignment;
  final double scale;
  final Key? key;
}

/// Projects widget markers in one batch into the map's logical viewport.
/// Place this layer in an overlay that fills the map.
class MapLibreMarkerLayer extends StatelessWidget {
  const MapLibreMarkerLayer({
    super.key,
    required this.controller,
    required this.markers,
  });

  final MapLibreMapController controller;
  final List<MapLibreMarker> markers;

  @override
  Widget build(BuildContext context) {
    final layers = controller.layerController;
    return ListenableBuilder(
      listenable: layers.viewportListenable,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final viewport = layers.viewportBounds;
          if (viewport == null || size.isEmpty || markers.isEmpty) {
            return const SizedBox.shrink();
          }

          final screenPoints = GeoLocation.pointsToScreen(
            points: [for (final marker in markers) marker.point.toMapLibre()],
            height: size.height,
            width: size.width,
            vp: viewport,
          );
          return SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < markers.length; i++)
                  if (screenPoints[i].x.isFinite && screenPoints[i].y.isFinite)
                    _positionMarker(markers[i], screenPoints[i]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionMarker(MapLibreMarker marker, ScreenLocation screen) {
    final anchor = marker.alignment.alongSize(
      Size(marker.width, marker.height),
    );
    return Positioned(
      key: marker.key,
      left: screen.x - anchor.dx,
      top: screen.y - anchor.dy,
      width: marker.width,
      height: marker.height,
      child: Transform.scale(
        scale: marker.scale,
        alignment: marker.alignment,
        child: marker.child,
      ),
    );
  }
}
