#!/bin/sh
set -eu
# FRB invokes Flutter and probes FVM; route Dart operations through rlutter.
bridge_tools=$(mktemp -d)
bridge_bootstrap=0
cleanup() {
  rm -rf "$bridge_tools"
  if [ "$bridge_bootstrap" = 1 ]; then
    rm -f rust/src/frb_generated.rs
  fi
}
trap cleanup EXIT HUP INT TERM
# cargo expand needs the generated module while inspecting the API's StreamSink.
# Seed its boilerplate only on a fresh checkout; codegen replaces this file.
if [ ! -f rust/src/frb_generated.rs ]; then
  bridge_bootstrap=1
  cat > rust/src/frb_generated.rs <<'RS'
flutter_rust_bridge::frb_generated_boilerplate!(
    default_stream_sink_codec = SseCodec,
    default_rust_opaque = RustOpaqueMoi,
    default_rust_auto_opaque = RustAutoOpaqueMoi,
);
RS
fi
cat > "$bridge_tools/fvm" <<'SH'
#!/bin/sh
exit 1
SH
cat > "$bridge_tools/flutter" <<'SH'
#!/bin/sh
if [ "$1" = "--version" ]; then
  exec "${RLUTTER_FLUTTER_ROOT:-$HOME/.cache/rlutter/flutter-BETA}/bin/flutter" "$@"
fi
if [ "$1" = "pub" ]; then
  shift
  if [ "$1" = "run" ]; then
    shift
    exec rlutter dart run "$@"
  fi
  exec rlutter dart pub "$@"
fi
exec rlutter dart "$@"
SH
chmod +x "$bridge_tools/flutter" "$bridge_tools/fvm"
PATH="$bridge_tools:$PATH" "${FRB_CODEGEN_BIN:-flutter_rust_bridge_codegen}" generate --no-auto-upgrade-dependency

bridge_bootstrap=0
