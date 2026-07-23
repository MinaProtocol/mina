//! # Utils Module
//!
//! This module provides utility functions to run external commands
//! and fetch the UID and GID of the current user.

use log::{debug, error};
use std::{
    fs::File,
    io,
    path::PathBuf,
    process::{Command, Output},
};
use url::Url;

/// Run an external command and capture its output.
/// Logs the command, its output, and any potential errors.
///
/// # Arguments
///
/// * `cmd` - A string slice that holds the name of the command.
/// * `args` - A slice of string slices that contain the arguments to the command.
///
/// # Returns
///
/// * `io::Result<Output>` - The output from the command execution.
/// Run an external command, capturing its output. Fails (with the command,
/// exit status, and stderr in the message) if the command can't be spawned or
/// exits non-zero — so callers get the real error instead of silently treating
/// a failed run as empty output.
pub fn run_command(cmd: &str, args: &[&str]) -> io::Result<Output> {
    debug!("Running command: {cmd} {}", args.join(" "));

    let output = Command::new(cmd).args(args).output().map_err(|e| {
        error!("Failed to spawn `{cmd}`: {e}");
        io::Error::other(format!("failed to spawn `{cmd}`: {e}"))
    })?;

    debug!("status: {}", output.status);
    debug!("stdout: {}", String::from_utf8_lossy(&output.stdout));
    debug!("stderr: {}", String::from_utf8_lossy(&output.stderr));

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut msg = format!("`{cmd} {}` exited with {}", args.join(" "), output.status);
        if !stderr.trim().is_empty() {
            msg.push_str(&format!("\nstderr: {}", stderr.trim()));
        } else if !stdout.trim().is_empty() {
            msg.push_str(&format!("\nstdout: {}", stdout.trim()));
        }
        error!("{msg}");
        return Err(io::Error::other(msg));
    }

    Ok(output)
}

/// Fetch the UID and GID of the current user.
///
/// # Returns
///
/// * `Option<String>` - A formatted string "UID:GID", or `None` if unable to retrieve.
pub fn get_current_user_uid_gid() -> Option<String> {
    let current_user = uzers::get_current_uid();
    let current_group = uzers::get_current_gid();

    Some(format!("{current_user}:{current_group}"))
}

/// Fetch the schema from a given URL and save it to a file.
/// The file is saved in the given network path.
pub fn fetch_schema(url: &str, network_path: PathBuf) -> Result<PathBuf, reqwest::Error> {
    debug!("Fetching schema from: {url}");

    let parsed_url = Url::parse(url).expect("Invalid URL");
    let filename = parsed_url
        .path_segments()
        .and_then(|mut segments| segments.next_back())
        .unwrap_or("schema.sql");
    let mut file_path = network_path;

    file_path.push(filename);
    let response = reqwest::blocking::get(parsed_url)?;
    let mut file = File::create(&file_path).expect("Failed to create file");

    std::io::copy(
        &mut response
            .bytes()
            .expect("Failed to read bytes from response")
            .as_ref(),
        &mut file,
    )
    .expect("Failed to write to file");

    Ok(file_path)
}

#[cfg(test)]
mod tests {
    use tempdir::TempDir;

    use super::*;

    #[test]
    fn test_run_command() {
        let output = run_command("echo", &["hello", "world"]).unwrap();
        assert!(output.status.success());
        assert_eq!(String::from_utf8_lossy(&output.stdout), "hello world\n");
    }

    #[test]
    fn test_run_command_nonzero_exit_surfaces_stderr() {
        // A non-zero exit is an error, and the message carries stderr rather
        // than being silently swallowed as empty output.
        let err = run_command("sh", &["-c", "echo boom >&2; exit 3"]).unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("exited with"), "got: {msg}");
        assert!(msg.contains("boom"), "got: {msg}");
    }

    #[test]
    fn test_run_command_spawn_failure_names_command() {
        let err = run_command("minimina-no-such-binary-xyz", &[]).unwrap_err();
        assert!(
            err.to_string().contains("minimina-no-such-binary-xyz"),
            "got: {err}"
        );
    }

    #[test]
    fn test_get_current_user_uid_gid() {
        let uid_gid = get_current_user_uid_gid().unwrap();
        assert!(uid_gid.contains(':'));
    }

    #[test]
    fn test_fetch_schema() {
        let url = "https://raw.githubusercontent.com/MinaProtocol/mina/master/src/app/archive/create_schema.sql";
        let tempdir = TempDir::new("test_fetch_schema").expect("Cannot create temporary directory");
        let network_path = tempdir.path();
        let file_path = fetch_schema(url, network_path.to_path_buf()).unwrap();
        assert!(file_path.exists());
        assert_eq!(file_path.file_name().unwrap(), "create_schema.sql");
    }
}
