RUST_CRATE_TYPE = select({
    "//bzl/host:macos": "cdylib",
    "//bzl/host:linux": "staticlib",
}, no_match_error = "Unsupported platform. Linux and MacOS only")

RUST_PROFILE_DEV = [
    # "cargo build --release" means build with release profile
    # https://doc.rust-lang.org/rustc/codegen-options/index.html
    # defaults:
    # [profile.dev]
    "-C", "opt-level=0",
    "-C", "debuginfo=2",
    "-C", "debug-assertions=on",
    "-C", "overflow-checks=on",
    "-C", "lto=off",  # lto = false
    "-C", "panic=unwind", # panic = 'unwind'
    "-C", "incremental=on",
    "-C", "codegen-units=256", # codegen-units = 16
    # "-C", "rpath=false" # (default)
]

RUST_PROFILE_RELEASE = [
    # "cargo build --release" means build with release profile
    # https://doc.rust-lang.org/rustc/codegen-options/index.html
    # defaults:
    # [profile.release]
    "-C", "opt-level=3",
    "-C", "debuginfo=0",
    "-C", "debug-assertions=off",
    "-C", "overflow-checks=off",
    "-C", "lto=off",
    "-C", "panic=unwind",
    "-C", "incremental=off",
    "-C", "codegen-units=16",
    # rpath = false (default)
]

# FIXME: select on //bzl/config/rust:profile=foo
RUST_PROFILE = select({
    "//bzl/config/rust:profile_dev": RUST_PROFILE_DEV,
    "//bzl/config/rust:profile_release": RUST_PROFILE_RELEASE,
    # "//bzl/config/rust:profile_test": RUST_PROFILE_TEST,
    # "//bzl/config/rust:profile_bench": RUST_PROFILE_BENCH,
    "//conditions:default": ["foo"]
})
