pub mod api;
pub mod core;
#[cfg(feature = "standalone-frb")]
mod frb_generated;
#[cfg(feature = "standalone-frb")]
mod bridge_sink;
mod rust_shell;

pub use rust_shell::register_application;
