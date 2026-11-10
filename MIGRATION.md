# MapLibre Flutter API

This standalone fork uses `maplibre_flutter` for the Dart package and native artifacts, `MapLibre` for public Dart types, and `maplibre_api` for the internal bridge module.

## Public entry point

```dart
import 'package:maplibre_flutter/maplibre_flutter.dart';

await initMapLibre();
```

The public map APIs are `MapLibreMapWidget`, `MapLibreMapController`, `MapLibreMapState`, and `MapLibreColor`. Color and coordinate extensions provide `toMapLibre()`. Consumers should use the public entry point rather than internal generated bridge files.

## Runtime

The diagnostics toggle is `MAPLIBRE_FRAME_STATS`, and the log filename is `maplibre_flutter.log`. Example bundle identifiers use the fork's package name.

## Validation

Use `rlutter dart analyze lib example/lib` for Dart analysis and `cargo fmt --manifest-path rust/Cargo.toml -- --check` for Rust formatting. The Taskfile also provides `rust.fmt-check`, `rust.check`, and `rust.test`.

Regenerate bindings with flutter_rust_bridge_codegen 2.13.0 after bridge API changes. Full native compilation and rendering require `.cache/mln-core/libmbgl-core.a` and its associated headers. The previous binding generation used `DOCS_RS=1` to bypass native core compilation during expansion.
