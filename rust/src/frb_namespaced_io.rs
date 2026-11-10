// Included inside frb_generated::io after code generation.
// Only the four bridge-specific exports need a package prefix. The remaining
// Flutter Rust Bridge runtime exports belong to its shared dependency.
flutter_rust_bridge::frb_generated_io_cst_codec!();

#[export_name = "maplibre_flutter_frb_get_rust_content_hash"]
pub extern "C" fn frb_get_rust_content_hash() -> i32 {
    FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH
}

#[export_name = "maplibre_flutter_frb_pde_ffi_dispatcher_primary"]
pub extern "C" fn frb_pde_ffi_dispatcher_primary(
    func_id: i32,
    port_: i64,
    ptr_: *mut u8,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    pde_ffi_dispatcher_primary_impl(func_id, port_, ptr_, rust_vec_len_, data_len_)
}

#[export_name = "maplibre_flutter_frb_pde_ffi_dispatcher_sync"]
pub extern "C" fn frb_pde_ffi_dispatcher_sync(
    func_id: i32,
    ptr_: *mut u8,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    pde_ffi_dispatcher_sync_impl(func_id, ptr_, rust_vec_len_, data_len_)
}

#[export_name = "maplibre_flutter_frb_dart_fn_deliver_output"]
pub extern "C" fn frb_dart_fn_deliver_output(
    call_id: i32,
    ptr_: *mut u8,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    let message = unsafe {
        flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
            ptr_,
            rust_vec_len_,
            data_len_,
        )
    };
    FLUTTER_RUST_BRIDGE_HANDLER.dart_fn_handle_output(call_id, message)
}
