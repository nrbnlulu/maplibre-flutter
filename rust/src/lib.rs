pub mod api;
pub mod core;
#[cfg(feature = "standalone-frb")]
mod frb_generated;
mod rust_shell;

pub use rust_shell::register_application;
