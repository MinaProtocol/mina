//! Locate the `mina` binary for native mode.
//!
//! Only invoked when the user did not pass `--bin-path` on the CLI.
//! Search order:
//!   1. `/usr/local/bin` (source / manual installs)
//!   2. `/usr/bin`       (debian package installs)
//!   3. first `mina` on `PATH` (via `which mina`)

use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

const DEFAULT_SEARCH_PATHS: &[&str] = &["/usr/local/bin", "/usr/bin"];

/// Returns the directory containing the `mina` binary, or a descriptive
/// `NotFound` error listing what was tried.
pub fn locate() -> io::Result<PathBuf> {
    for dir in DEFAULT_SEARCH_PATHS {
        if Path::new(dir).join("mina").exists() {
            return Ok(PathBuf::from(dir));
        }
    }

    if let Some(parent) = which_mina().as_deref().and_then(Path::parent) {
        return Ok(parent.to_path_buf());
    }

    Err(io::Error::new(
        io::ErrorKind::NotFound,
        format!(
            "Mina binary not found. Searched {} and PATH. \
             Please install mina or use --bin-path to specify the location.",
            DEFAULT_SEARCH_PATHS.join(", ")
        ),
    ))
}

fn which_mina() -> Option<PathBuf> {
    let output = Command::new("which").arg("mina").output().ok()?;
    if !output.status.success() {
        return None;
    }
    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if path.is_empty() {
        None
    } else {
        Some(PathBuf::from(path))
    }
}
