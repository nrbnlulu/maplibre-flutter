import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_flutter/maplibre_flutter.dart';

void main() {
  test('releasing a handle leaves other pan suppressions intact', () {
    final layers = LayerController(sessionId: 0, layers: []);
    addTearDown(layers.dispose);

    final releaseFirst = layers.acquirePanSuppression();
    final releaseSecond = layers.acquirePanSuppression();
    expect(layers.shouldSuppressPan, isTrue);

    releaseFirst();
    releaseFirst();
    expect(layers.shouldSuppressPan, isTrue);

    layers.drawSuppressPan = true;
    releaseSecond();
    expect(layers.shouldSuppressPan, isTrue);

    layers.drawSuppressPan = false;
    expect(layers.shouldSuppressPan, isFalse);
  });
}
