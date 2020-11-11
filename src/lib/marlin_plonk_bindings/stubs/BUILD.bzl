"""Package variables module.

Package-scoped configuration variable definitions.
"""

PKG_DEBUG_OPT = select({":enable_debug": ["-g"], "//conditions:default": []})
PKG_VERBOSE_OPT = select({":enable_verbose": ["-verbose"], "//conditions:default": []})

PKG_OPTS = PKG_DEBUG_OPT + PKG_VERBOSE_OPT
PKG_ARCHIVE_OPTS = PKG_OPTS

PKG_NS_MODULE_OPTS = PKG_OPTS

# RUST_OPT_LEVEL = ["-C", attr.label(default = "//bzl/config/rust:opt-level")]

RUST_DEBUG_LEVEL = select({
    "//bzl/config/rust:debug-disable": ["-C", "debuginfo=0"],
    "//bzl/config/rust:debug-line-tables": ["-C", "debuginfo=1"],
    "//bzl/config/rust:debug-full": ["-C", "debuginfo=2"],
}, no_match_error = "Unknown Rust debug level")

RUST_OPT_LEVEL = select({
    "//bzl/config/rust:opt-level-disable": ["-C", "opt-level=0"],
    "//bzl/config/rust:opt-level-basic": ["-C", "opt-level=1"],
    "//bzl/config/rust:opt-level-some": ["-C", "opt-level=2"],
    "//bzl/config/rust:opt-level-all": ["-C", "opt-level=3"],
}, no_match_error = "Unknown Rust opt-level")


RUST_PROFILE = RUST_DEBUG_LEVEL + RUST_OPT_LEVEL
