import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:maplibre_flutter/map_editing.dart';
import 'package:maplibre_flutter/src/layer/marker_cluster_layer.dart';

void main() {
  test('clustering uses the earliest anchor across grid cells', () {
    const positions = {
      'first': Offset(19, 0),
      'second': Offset(0, 0),
      'matches both': Offset(9.5, 0),
      'hidden': null,
    };
    expect(
      groupProjectedMarkers(
        positions.keys.toList(),
        radius: 10,
        project: (item) => positions[item],
      ),
      [
        ['first', 'matches both'],
        ['second'],
        ['hidden'],
      ],
    );
  });

  test('canceling a midpoint insertion restores the caller-owned draft', () {
    const vertices = [LatLng(30, 33), LatLng(31, 33), LatLng(31, 34)];
    const moved = LatLng(32, 34);
    final points = [...vertices];
    final changes = <LatLng?>[];
    final editor = MapLibrePolygonDraftEditor(
      points: points,
      vertexIcon: const SizedBox(),
      midpointIcon: const SizedBox(),
      onChanged: changes.add,
      closed: true,
    );
    final handles = editor.edit();
    expect(handles, hasLength(6));
    final closingEdge = handles.last;
    closingEdge.onDragStart!(DragStartDetails(), closingEdge.point);
    closingEdge.onDragUpdate!(
      DragUpdateDetails(globalPosition: Offset.zero),
      moved,
    );
    expect(points, [...vertices, moved]);
    expect(editor.edit(), same(handles));
    closingEdge.onDragCancel!();
    expect(points, vertices);
    expect(changes, [moved, null]);
    expect(editor.isDragging, isFalse);

    final midpoint = editor.edit()[3];
    midpoint.onDragStart!(DragStartDetails(), midpoint.point);
    midpoint.onDragUpdate!(
      DragUpdateDetails(globalPosition: Offset.zero),
      moved,
    );
    midpoint.onDragEnd!(DragEndDetails(), moved);
    expect(points, [vertices.first, moved, ...vertices.skip(1)]);
    expect(editor.isDragging, isFalse);
    expect(editor.edit(), hasLength(8));
  });
}
