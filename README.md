# MapLibre Flutter

Flutter widgets and controllers backed by MapLibre Native through a Rust FFI bridge.

```dart
import 'package:maplibre_flutter/maplibre_flutter.dart';

await initMapLibre();
```

The public map APIs are `MapLibreMapWidget`, `MapLibreMapController`, `MapLibreMapState`, and `MapLibreColor`. See the example app for configuration and overlays, and [MIGRATION.md](MIGRATION.md) for the public package API.

## Architecture

Dart widgets live in `lib/`, Rust bridge functions and types in `rust/src/api/`, and rendering and session management in `rust/src/core/`. MapLibre Native renders on a dedicated thread into textures owned by the Flutter Rust shell.

## Development

Use a Flutter SDK satisfying `pubspec.yaml` and Rust. Run `flutter pub get`, prepare the Rust shell SDK expected by `rust/Cargo.toml`, and run `tool/setup-mln-core.sh` to prepare the native core cache. This may require building the C++ engine.

After changing Rust bridge APIs, run `flutter_rust_bridge_codegen generate` with version 2.13.0. Check changes with `rlutter dart analyze lib example/lib` and `cargo check --manifest-path rust/Cargo.toml`.

The example includes a Rust shell runner under `example/runner-rs/`. Run it on a supported desktop target with the Rust shell tooling. The native rendering path does not support web.

Use the internal `rlutter` toolchain: `rlutter dart ...` for Dart commands and `rlutter run` for the example.
