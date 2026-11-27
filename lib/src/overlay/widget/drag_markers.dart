import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../extensions/latlng.dart';
import '../../map/controller.dart';
import '../../rust/api/dart_types.dart' show ScreenLocation;

/// A map-anchored Flutter handle with geographic drag callbacks.
class MapLibreDragMarker {
  const MapLibreDragMarker({
    required this.point,
    required this.builder,
    this.key,
    this.size = const Size(40, 40),
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.onLongPress,
    this.onTap,
  });

  final Key? key;
  final LatLng point;
  final Size size;
  final Widget Function(BuildContext, LatLng, bool) builder;
  final void Function(DragStartDetails, LatLng)? onDragStart;
  final void Function(DragUpdateDetails, LatLng)? onDragUpdate;
  final void Function(DragEndDetails, LatLng)? onDragEnd;
  final VoidCallback? onDragCancel;
  final void Function(LatLng)? onLongPress;
  final void Function(LatLng)? onTap;
}

/// Displays draggable handles in an overlay that fills the map.
/// While a handle owns a pointer, the underlying map cannot pan with it.
class MapLibreDragMarkers extends StatelessWidget {
  const MapLibreDragMarkers({
    super.key,
    required this.controller,
    required this.markers,
  });

  final MapLibreMapController controller;
  final List<MapLibreDragMarker> markers;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListenableBuilder(
      listenable: controller.layerController.viewportListenable,
      builder: (context, _) => SizedBox.expand(
        child: Stack(
          children: [
            for (var i = 0; i < markers.length; i++)
              _DragHandle(
                key: markers[i].key ?? ValueKey(i),
                controller: controller,
                mapSize: constraints.biggest,
                marker: markers[i],
              ),
          ],
        ),
      ),
    ),
  );
}

class _DragHandle extends StatefulWidget {
  const _DragHandle({
    super.key,
    required this.controller,
    required this.mapSize,
    required this.marker,
  });

  final MapLibreMapController controller;
  final Size mapSize;
  final MapLibreDragMarker marker;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  final _releases = <int, VoidCallback>{};
  LatLng? _draft;
  Offset? _dragPosition;

  void _releasePointer(PointerEvent event) {
    final release = _releases.remove(event.pointer);
    // Keep pan suppressed until the map's ancestor listener has processed up.
    if (release != null) scheduleMicrotask(release);
  }

  @override
  void dispose() {
    for (final release in _releases.values) {
      release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.controller.layerController;
    final viewport = layers.viewportBounds;
    final size = widget.mapSize;
    if (viewport == null || size.isEmpty) return const SizedBox.shrink();

    final marker = widget.marker;
    final location = _draft ?? marker.point;
    final projected = location.toMapLibre().toScreen(
      height: size.height,
      width: size.width,
      vp: viewport,
    );
    final screen = Offset(projected.x, projected.y);
    if (!screen.isFinite) return const SizedBox.shrink();

    return Positioned(
      left: screen.dx - marker.size.width / 2,
      top: screen.dy - marker.size.height / 2,
      width: marker.size.width,
      height: marker.size.height,
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons & kPrimaryButton != 0) {
            _releases.putIfAbsent(event.pointer, layers.acquirePanSuppression);
          }
        },
        onPointerUp: _releasePointer,
        onPointerCancel: _releasePointer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => marker.onTap?.call(location),
          onLongPress: marker.onLongPress == null
              ? null
              : () => marker.onLongPress!(location),
          onPanStart: (details) {
            setState(() {
              _draft = marker.point;
              _dragPosition = screen;
            });
            marker.onDragStart?.call(details, marker.point);
          },
          onPanUpdate: (details) {
            final previous = _dragPosition;
            final currentViewport = layers.viewportBounds;
            if (previous == null || currentViewport == null) return;
            final position = _dragPosition = previous + details.delta;
            final geo = ScreenLocation(x: position.dx, y: position.dy)
                .toGeographical(
                  height: size.height,
                  width: size.width,
                  vp: currentViewport,
                );
            if (!geo.latitude.isFinite || !geo.longitude.isFinite) return;
            final next = LatLng(geo.latitude, geo.longitude);
            setState(() => _draft = next);
            marker.onDragUpdate?.call(details, next);
          },
          onPanEnd: (details) {
            final point = _draft;
            if (point == null) return;
            _clearDrag();
            marker.onDragEnd?.call(details, point);
          },
          onPanCancel: () {
            if (_draft == null) return;
            _clearDrag();
            marker.onDragCancel?.call();
          },
          child: marker.builder(context, location, _draft != null),
        ),
      ),
    );
  }

  void _clearDrag() {
    setState(() {
      _draft = null;
      _dragPosition = null;
    });
  }
}
