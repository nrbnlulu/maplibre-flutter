// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_flutter/maplibre_flutter.dart' as current;
import 'package:maplibre_flutter/galileo_flutter.dart' as legacy;

void main() {
  test('legacy entry point preserves color and state aliases', () {
    const color = legacy.GalileoColor(r: 1, g: 0, b: 0, a: 1);
    expect(color, const current.MapLibreColor(r: 1, g: 0, b: 0, a: 1));
    expect(legacy.GalileoMapState.ready, current.MapLibreMapState.ready);
    expect(
      legacy.GalileoMapController.create,
      current.MapLibreMapController.create,
    );
    expect(
      legacy.GalileoMapWidget.fromController,
      current.MapLibreMapWidget.fromController,
    );
  });
}
