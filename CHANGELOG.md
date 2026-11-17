## Unreleased

- Add `MapLibrePathProjection` for camera-clipped polygon and polyline paths.
  Prevent behind-camera vertices from drawing stray diagonal edges in tilted
  views; use the same paths for polygon editor painting and hit testing.

- Make touch rotation follow the direction of the two-finger twist.

- Use `maplibre_flutter` for the package and native artifacts.
- Expose MapLibre-prefixed Dart APIs for the standalone fork.
- Expose the internal bridge module as `maplibre_api`.

## 0.0.1

* TODO: Describe initial release.
