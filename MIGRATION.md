# MapLibre Flutter rename

The package is being renamed to `maplibre_flutter`, with `MapLibre` as the public API prefix. The rendering engine is already MapLibre Native.

## Commit sequence

1. Record the naming and migration contract.
2. Rename the private Rust shell plugin.
3. Rename the Rust bridge module, initialization functions and color type; regenerate bindings and update callers together.
4. Rename the Dart widget, controller, state and extension APIs, retaining deprecated public compatibility aliases.
5. Rename the package, native artifacts and example identities together so build references remain consistent.
6. Refresh architecture documentation and audit remaining references.

## Consumer migration

Change the dependency to `maplibre_flutter` and import `package:maplibre_flutter/maplibre_flutter.dart`.

| Old API | Replacement |
| --- | --- |
| `initGalileo` | `initMapLibre` |
| `GalileoMapWidget` | `MapLibreMapWidget` |
| `GalileoMapController` | `MapLibreMapController` |
| `GalileoMapState` | `MapLibreMapState` |
| `GalileoColor` | `MapLibreColor` |
| `toGalileo()` | `toMapLibre()` |

Deprecated aliases and an old entry-point forwarding file ease source migration inside the new package. They do not preserve the old package URI. Consumers importing internal generated bridge files must migrate those imports as well.

## Validation

Regenerate bindings with flutter_rust_bridge_codegen 2.13.0. Check Rust formatting and compilation, Dart formatting and analysis, existing tests, and native example builds on available targets. A desktop smoke test should initialize the bridge and render a map. Record environment limitations rather than treating unavailable checks as passes.

## Runtime and validation notes

The diagnostics toggle is now `MAPLIBRE_FRAME_STATS`, and the log filename is `maplibre_flutter.log`. Example bundle identifiers were also renamed; installing the renamed example can create a separate app installation.

The old engine-specific `rust/tests/native_texture_render.rs` predates the MapLibre renderer and still imports the former engine and removed WindowlessRenderer API. It needs a separate renderer test migration; changing those dependency identifiers mechanically would not produce a valid test.

Bindings were regenerated with 2.13.0 using `DOCS_RS=1` to bypass the missing native core during expansion. Full native compilation and rendering require `.cache/mln-core/libmbgl-core.a` and its associated headers.

Validation during this migration: `rlutter dart analyze lib example/lib test` completed with no errors or warnings and ten existing internal-SDK material.dart deprecation notices; Rust formatting and diff whitespace checks passed. The compatibility runtime test could not load because the available Flutter tester and internal framework disagree on dart:ui texture callback and semantics APIs. Full native checking stops at the absent core archive.
