#!/usr/bin/env python3
"""Reapply MapLibre's FRB export namespace after code generation."""

from pathlib import Path

root = Path(__file__).resolve().parent.parent
rust = root / "rust/src/frb_generated.rs"
dart = root / "lib/src/rust/frb_generated.dart"

rust_text = rust.read_text()
original_macro = "flutter_rust_bridge::frb_generated_boilerplate_io!();"
replacement_macro = 'include!("frb_namespaced_io.rs");'
if original_macro in rust_text:
    rust.write_text(rust_text.replace(original_macro, replacement_macro, 1))
elif replacement_macro not in rust_text:
    raise RuntimeError("MapLibre FRB Rust boilerplate marker changed")

dart_text = dart.read_text()
original_class = (
    "class RustLib extends BaseEntrypoint<RustLibApi, RustLibApiImpl, RustLibWire> {"
)
replacement_class = (
    original_class
    + "\n  @override\n  String get rustSymbolPrefix => 'maplibre_flutter_';"
)
if replacement_class not in dart_text:
    if original_class not in dart_text:
        raise RuntimeError("MapLibre FRB Dart entrypoint marker changed")
    dart.write_text(dart_text.replace(original_class, replacement_class, 1))
