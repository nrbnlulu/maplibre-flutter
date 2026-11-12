# MapLibre Flutter

Flutter widgets and controllers backed by MapLibre Native through
[flutter_rust_bridge (FRB)](https://cjycode.com/flutter_rust_bridge/), which
generates the Dart/Rust bindings. Rendering uses
[rlutter](https://github.com/nrbnlulu/flutter), a Flutter Rust shell that provides
the GPU device and texture integration.

```dart
import 'package:maplibre_flutter/maplibre_flutter.dart';

await initMapLibre();
```

The public map APIs include `MapLibreMapWidget`, `MapLibreMapController`,
`MapLibreLineLayer`, `MapLibreMapState`, and `MapLibreColor`. Camera moves animate
through MapLibre Native. Initial zoom supports fractional values and per-map
minimum/maximum zoom. Raster base URL changes replace the previous source;
projected line overlays support opacity, casing, and dash patterns. Wheel zoom
claims pointer signals so an enclosing scroll view does not scroll too.

## Experimental independent bridge

This branch pins the Rust and Dart runtimes to
[shri-acha/flutter_rust_bridge, revision 334e4e3](https://github.com/shri-acha/flutter_rust_bridge/tree/334e4e3234c782b7c7bf221f1866440b6b7627ef),
version `2.13.0`. This branch backports the prefix patch to the 2.13
release so applications can retain existing 2.13 Shalom and SIP bindings with
strict codegen-version checks enabled. Its supported `native_symbol_prefix` configuration sets
`maplibre_flutter_` on this package's hash, dispatchers, and callback delivery.
Another FRB plugin can own its bridge in the same rlutter executable when it
uses a different prefix and a compatible shared Rust/Dart runtime. Register each
plugin once and initialize each generated Dart bridge separately.

Use the same Git FRB Dart dependency (or a matching root dependency override)
and Rust runtime revision for every bridge linked into the executable. This
package's Dart API does not depend on an application-owned hub. The old vendored
Dart runtime and handwritten namespace script are not used on this branch.

Install the matching generator with:

```sh
cargo install --git https://github.com/shri-acha/flutter_rust_bridge.git --rev 334e4e3234c782b7c7bf221f1866440b6b7627ef --locked flutter_rust_bridge_codegen
```

`FRB_CODEGEN_BIN` can select an already-built matching generator for
`go-task codegen`. Regenerate Rust and Dart together after native API changes.

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

The default Cargo feature `standalone-frb` enables this package's own generated
FRB dispatcher and stream entrypoint. This is a feature defined by this crate,
not a built-in FRB mode. In this README, "standalone" means that MapLibre owns
its Dart/Rust bridge and can be used independently of an application-owned hub.
Dart callers initialize that bridge with `initMapLibre()` and use the supplied
map widgets and controllers. Standalone use still requires rlutter's shell SDK
and GPU/texture integration; it does not mean support for every Flutter shell.

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
Other map APIs and Rust models remain available. FRB remains a Rust dependency
for the API annotations and supporting types; disabling `standalone-frb` does
not remove FRB from the dependency graph. The consuming application generates
and initializes its own bridge and routes its Dart adapters through that bridge.
This prevents the MapLibre standalone dispatcher from being linked alongside
the hub's dispatcher in the same native runner. MapLibre still needs rlutter's
GPU/texture SDK, and the hub must register its capabilities once. No T5hob
dependencies are required by this repository.

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
- Keep generated dispatch edits out of handwritten code. The standalone bridge
  uses the generator's `native_symbol_prefix`; codegen produces the matching
  native exports and Dart lookups without a post-generation namespace patch.
  Application-owned bridges exclude the standalone dispatcher with
  `default-features = false`.
