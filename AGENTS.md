# MapLibre Flutter - Agent Guide

## Project overview
MapLibre Flutter is a Flutter FFI plugin backed by MapLibre Native. Dart widgets and controllers communicate with Rust through flutter_rust_bridge.

## Architecture
- `lib/`: public Dart API and Flutter widgets; entry point `maplibre_flutter.dart`.
- `rust/src/api/`: bridge functions and shared types.
- `rust/src/core/map_session.rs`: map sessions and camera translation.
- `rust/src/core/map_thread.rs`: dedicated MapLibre render thread.
- `rust/src/rust_shell.rs`: Rust shell plugin registration and GPU access.
- `example/runner-rs/`: example Rust shell runner.

## Dependencies and rendering
- `maplibre_native`: the `wgpu-30` branch of the maplibre-native-rs fork.
- `flutter_rust_bridge`: pinned to 2.13.0 in Rust; use the matching generator.
- `flutter-plugin-sdk`: provides shell-owned GPU textures and shares the pinned wgpu revision through the Cargo patch configuration.
- MapLibre renders directly into shell-owned texture views. The renderer runs on its own thread because it is not Send.
- `.cargo/config.toml` expects native core artifacts in `.cache/mln-core`. `tool/setup-mln-core.sh` prepares them and may perform a substantial C++ build.
- The standalone Rust build expects the shell SDK under `example/.dart_tool/flutter_rs/sdk`.

## Development
- `flutter pub get`: resolve Dart dependencies.
- `flutter_rust_bridge_codegen generate`: regenerate bindings after Rust API changes.
- `rlutter dart run build_runner build --build-filter=lib/src/rust/api/dart_types.freezed.dart`: regenerate the shared union implementations if needed.
- `cargo check --manifest-path rust/Cargo.toml`: check Rust.
- `cargo fmt --manifest-path rust/Cargo.toml`: format Rust.
- `rlutter dart format lib example/lib`: format Dart.
- `rlutter dart analyze lib example/lib`: analyze Dart.
- Run the example on desktop using the Rust shell tooling; web is not supported by the native renderer.

## Naming
Use `maplibre_flutter` for package and native artifact names, `MapLibre` for public Dart types, and `maplibre_api` for the bridge module. Deprecated compatibility names and consumer migration instructions are documented in `MIGRATION.md`.

Use the internal `rlutter` toolchain: `rlutter dart ...` for Dart commands and `rlutter run` for the example.

## Taskfile commands

`task rust.fmt-check`, `task rust.check`, `task rust.test`, and `task mln-core` provide native checks and core setup. The current `flutter.*` tasks select FVM or direct Flutter/Dart binaries; use the equivalent `rlutter dart` commands with the internal toolchain. There is no rlutter run task. The `codegen` task deletes `.dart_tool` before generating; invoking the generator directly avoids clearing local dependency metadata.
