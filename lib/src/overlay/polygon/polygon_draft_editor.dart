import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../widget/drag_markers.dart';

/// Edit a caller-owned list of vertices with draggable Flutter handles.
/// Call [edit] again when [onChanged] fires to rebuild the preview. During a
/// drag the returned handles remain stable, even when a midpoint is inserted.
class MapLibrePolygonDraftEditor {
  MapLibrePolygonDraftEditor({
    required this.points,
    required this.vertexIcon,
    required this.midpointIcon,
    required this.onChanged,
    this.closed = false,
  });

  final List<LatLng> points;
  final Widget vertexIcon, midpointIcon;
  final ValueChanged<LatLng?> onChanged;
  final bool closed;

  List<LatLng>? _pointsBeforeDrag;
  List<MapLibreDragMarker> _handles = const [];
  Object? _activeHandle;

  bool get isDragging => _pointsBeforeDrag != null;

  List<MapLibreDragMarker> edit() {
    if (isDragging) return _handles;
    return _handles = [
      for (var i = 0; i < points.length; i++) _vertex(i),
      for (var i = 1; i < points.length; i++) _midpoint(i - 1, i),
      if (closed && points.length > 2) _midpoint(points.length - 1, 0),
    ];
  }

  MapLibreDragMarker _vertex(int index) => _handle(
    points[index],
    index,
    vertexIcon,
    onLongPress: (_) {
      if (!isDragging) onChanged(points.removeAt(index));
    },
  );

  MapLibreDragMarker _midpoint(int start, int end) {
    final a = points[start];
    final b = points[end];
    return _handle(
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2),
      start + 1,
      midpointIcon,
      insert: true,
    );
  }

  MapLibreDragMarker _handle(
    LatLng point,
    int index,
    Widget icon, {
    bool insert = false,
    ValueChanged<LatLng>? onLongPress,
  }) {
    final handle = Object();
    return MapLibreDragMarker(
      point: point,
      size: const Size(30, 30),
      builder: (_, _, _) => icon,
      onLongPress: onLongPress,
      onDragStart: (_, _) {
        if (isDragging) return;
        _pointsBeforeDrag = List.of(points);
        _activeHandle = handle;
        if (insert) points.insert(index, point);
      },
      onDragUpdate: (_, location) {
        if (_activeHandle != handle) return;
        points[index] = location;
        onChanged(location);
      },
      onDragEnd: (_, location) {
        if (_activeHandle != handle) return;
        _activeHandle = null;
        _pointsBeforeDrag = null;
        onChanged(location);
      },
      onDragCancel: () {
        final previous = _pointsBeforeDrag;
        if (previous == null || _activeHandle != handle) return;
        points
          ..clear()
          ..addAll(previous);
        _pointsBeforeDrag = null;
        _activeHandle = null;
        onChanged(null);
      },
    );
  }
}
