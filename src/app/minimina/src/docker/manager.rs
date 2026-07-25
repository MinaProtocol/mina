//! # Legacy docker-compose shim
//!
//! The network create/delete paths still shell out to `docker compose down`
//! (teardown) and `mina client status` via the `docker` CLI. Everything else —
//! the network lifecycle and every node command — now runs on the supervisor
//! (see [`crate::supervisor`]); plans are built by
//! [`crate::docker::plan_builder`]. This shim shrinks to nothing once the
//! network create/delete teardown is folded into the supervisor's `stop`.

use crate::utils::run_command;
use std::{
    io::Result,
    path::{Path, PathBuf},
    process::Output,
};

#[derive(Clone)]
pub struct DockerManager {
    pub network_path: PathBuf,
    pub compose_path: PathBuf,
}

impl DockerManager {
    pub fn new(network_path: &Path) -> Self {
        let compose_path = network_path.join("docker-compose.yaml");
        DockerManager {
            network_path: network_path.to_path_buf(),
            compose_path,
        }
    }

    pub fn compose_down(
        &self,
        specific_service: Option<String>,
        remove_volumes: bool,
        remove_images: bool,
    ) -> Result<Output> {
        let mut args = vec!["down"];
        let specific_service = specific_service.as_deref();
        if let Some(service) = specific_service {
            args.push(service);
        }

        if remove_volumes {
            args.push("--volumes");
        }

        if remove_images {
            args.push("--rmi");
            args.push("all");
        }

        args.push("--remove-orphans");
        self.run_docker_compose(&args)
    }

    #[allow(dead_code)]
    pub fn compose_client_status(
        &self,
        node_id: &str,
        network_id: &str,
        client_port: u16,
    ) -> Result<Output> {
        let service = format!("{node_id}-{network_id}");
        let cmd = &[
            "exec",
            &service,
            "mina",
            "client",
            "status",
            "-daemon-port",
            &client_port.to_string(),
        ];
        self.run_docker_compose(cmd)
    }

    fn run_docker_compose(&self, subcommands: &[&str]) -> Result<Output> {
        let network_id = self
            .network_path
            .file_name()
            .expect("Failed to extract file name")
            .to_str()
            .expect("Failed to convert OsStr to str");

        let base_args = &[
            "compose",
            "-f",
            self.compose_path
                .to_str()
                .expect("Failed to convert file path to str"),
            "-p",
            network_id,
        ];

        let mut args: Vec<&str> = base_args.to_vec();
        args.extend_from_slice(subcommands);

        let out = run_command("docker", &args)?;
        Ok(out)
    }
}
