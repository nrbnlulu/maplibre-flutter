# MapLibre Flutter

Flutter widgets and controllers backed by MapLibre Native through a Rust FFI bridge.

```dart
import 'package:maplibre_flutter/maplibre_flutter.dart';

await initMapLibre();
```

The public map APIs are `MapLibreMapWidget`, `MapLibreMapController`, `MapLibreMapState`, and `MapLibreColor`. See the example app for configuration and overlays.

## Architecture

Dart widgets live in `lib/`, Rust bridge functions and types in `rust/src/api/`, and rendering and session management in `rust/src/core/`. MapLibre Native renders on a dedicated thread into textures owned by the Flutter Rust shell.

## Standalone builds

This fork uses the rlutter Rust shell and its GPU/texture SDK. Native builds
run through rlutter and Cargo. Standard Flutter platform Rust build hooks and
Cargokit are not provided; this does not add support for other Flutter shells.
Native tooling requires a C++ compiler, libclang for bindgen, and the platform
GPU dependencies required by the Rust shell. Run codegen in that same native
build environment.

Use `rlutter dart pub get`, then run it in `example` to prepare that runner's
SDK. Run `go-task mln-core` from this checkout to prepare the native core cache,
then `go-task run` to launch the Linux example. The cache is local to this
checkout; Android requires target-specific native artifacts and SDK setup.

Run `go-task codegen` after changing the public bridge API. It uses FRB 2.13.0,
regenerates the standalone bindings and Freezed models, and preserves dependency
metadata. Run `rlutter dart analyze lib example/lib` to check Dart consumers.
The codegen Flutter SDK probe defaults to rlutter's cached Flutter SDK; set
`RLUTTER_FLUTTER_ROOT` to override its location.

## Using the Rust implementation in an application-owned bridge

The default Cargo feature `standalone-frb` retains the package's own generated
FRB entrypoints and Dart bindings. Existing standalone Dart callers continue
to use `initMapLibre()` and the existing map widget/controller API.

An application that owns its own FRB bridge can consume the implementation:

```toml
[dependencies]
maplibre_flutter = { git = "https://github.com/nrbnlulu/maplibre-flutter.git", rev = "<commit>", default-features = false }
```

The application must provide the matching flutter-plugin-sdk/wgpu patches and
register MapLibre capabilities once through `register_application`. It owns
its bridge initialization, DTO conversion and Dart adapters. Disabling the
feature excludes MapLibre's generated FRB dispatcher and sink-based frame
stream entrypoint. `rendered_map_frames(session_id)` instead returns a Tokio
watch receiver that the application can adapt to its own generated sink.
Other map APIs and Rust models remain available. No T5hob dependencies are
required by this repository.

Cargo features are additive: every dependency on this crate in the application
must leave `standalone-frb` disabled. Another dependency enabling the default
feature will restore the standalone dispatch exports. Use `cargo tree -e
features` when diagnosing unexpected exports. The public Dart package uses its
standalone bridge; using an application-owned bridge requires application-side
Dart adapters, not just disabling a Cargo feature.

## Adding functions and types

- Internal Rust helpers need no Dart bindings. Add behavior and implementation
  types in the appropriate Rust modules.
- For standalone Dart APIs, expose functions and DTOs through `crate::api`,
  keep the existing public module paths, and run `go-task codegen`. Update
  explicit exports in `lib/maplibre_flutter.dart` for new public types.
- Functions whose signatures use generated FRB sinks must be gated behind
  `standalone-frb`. Provide a bridge-neutral receiver or callback helper for
  application-owned bridges, mark it `#[frb(ignore)]`, and delegate the
  standalone stream function to it.
- Application-owned bridges must update their own DTOs, conversions, wrapper
  functions and Dart exports when they adopt new implementation APIs. Their
  bindings are generated in the consuming application, not in this package.
- Keep generated dispatch edits out of handwritten code. Use standard FRB
  exports and the standard 2.13.0 runtime; symbol-prefix patches are unnecessary
  when each final application links only its selected generated bridge.
