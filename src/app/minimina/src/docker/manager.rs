//! # Docker Manager Module
//!
//! Provides an interface for managing Docker operations within the application.
//! Specifically, it offers functionalities to:
//! - Generate a `docker-compose.yaml` file from provided service configurations.
//! - Start up services using the generated Docker Compose file.
//! - Shut down active services.
//! - Handle interactions with the Docker CLI.

use crate::directory_manager::NETWORK_KEYPAIRS;
use crate::genesis_ledger::REPLAYER_INPUT_JSON;
use crate::{
    docker::compose::DockerCompose, docker::compose::CONFIG_DIRECTORY, service::ServiceConfig,
    utils::run_command,
};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::fs::File;
use std::io::Write;
use std::{
    io::Result,
    path::{Path, PathBuf},
    process::Output,
};

#[derive(Debug, Serialize, Deserialize)]
pub struct ContainerInfo {
    #[serde(rename = "ID")]
    pub id: String,
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Image")]
    pub image: String,
    #[serde(rename = "Command")]
    pub command: String,
    #[serde(rename = "CreatedAt")]
    pub created_at: String,
    #[serde(rename = "State")]
    pub state: ContainerState,
    #[serde(rename = "Status")]
    pub status: String,
    #[serde(rename = "Health")]
    pub health: String,
    #[serde(rename = "ExitCode")]
    pub exit_code: i32,
    #[serde(rename = "Labels")]
    pub labels: String,
    #[serde(rename = "Service")]
    pub service: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub enum ContainerState {
    #[serde(rename = "created")]
    Created,
    #[serde(rename = "exited")]
    Exited,
    #[serde(rename = "running")]
    Running,
    #[serde(rename = "paused")]
    Paused,
    #[serde(rename = "restarting")]
    Restarting,
    #[serde(rename = "removing")]
    Removing,
    #[serde(rename = "dead")]
    Dead,
    #[serde(rename = "unknown")]
    Unknown,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ComposeInfo {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Status")]
    pub status: String,
    #[serde(rename = "ConfigFiles")]
    pub config_files: String,
}

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

    pub fn compose_generate_file(&self, configs: &[ServiceConfig]) -> Result<()> {
        let mut file = File::create(&self.compose_path)?;
        let contents = DockerCompose::generate(configs, &self.network_path);
        file.write_all(contents.as_bytes())?;
        Ok(())
    }

    pub fn exec(&self, service: &str, cmd: &[&str]) -> Result<Output> {
        let mut args = vec!["exec", "-i", service];
        args.extend_from_slice(cmd);
        let out = run_command("docker", &args)?;
        Ok(out)
    }

    pub fn cp(&self, service: &str, src: &Path, dest: &Path) -> Result<Output> {
        let destination = format!("{}:{}", service, dest.to_str().unwrap());
        let args = vec!["cp", src.to_str().unwrap(), destination.as_str()];
        let out = run_command("docker", &args)?;
        Ok(out)
    }

    pub fn _compose_up(&self) -> Result<Output> {
        self.run_docker_compose(&["up", "-d"])
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

    /// Create the network
    pub fn compose_create(&self, specific_service: Option<String>) -> Result<Output> {
        let mut args = vec!["create"];
        let specific_service = specific_service.as_deref();
        if let Some(service) = specific_service {
            args.push(service);
        }
        self.run_docker_compose(&args)
    }

    /// Start all services in the network
    pub fn compose_start_all(&self) -> Result<Output> {
        self.run_docker_compose(&["start"])
    }

    /// Stop all services in the network
    pub fn compose_stop_all(&self) -> Result<Output> {
        self.run_docker_compose(&["stop"])
    }

    /// Start a subset of services in the network
    pub fn compose_start(&self, services: Vec<&str>) -> Result<Output> {
        let mut cmd = vec!["start"];
        cmd.extend(services);
        self.run_docker_compose(&cmd)
    }

    /// Stop a subset of services in the network
    pub fn compose_stop(&self, services: Vec<&str>) -> Result<Output> {
        let mut cmd = vec!["stop"];
        cmd.extend(services);
        self.run_docker_compose(&cmd)
    }

    pub fn compose_ls(&self) -> Result<Vec<ComposeInfo>> {
        let output = self.run_docker_compose(&["ls", "--format", "json"])?;
        let stdout_str = String::from_utf8_lossy(&output.stdout);
        let compose_info = serde_json::from_str(&stdout_str)?;
        Ok(compose_info)
    }

    /// Get docker info of all services in the network
    pub fn compose_ps(&self, filter: Option<ContainerState>) -> Result<Vec<ContainerInfo>> {
        let mut cmd: Vec<String> = vec![
            "ps".to_string(),
            "-a".to_string(),
            "--format".to_string(),
            "json".to_string(),
        ];

        if let Some(state) = filter {
            cmd.push("--filter".to_string());
            cmd.push(format!("status={}", state));
        }

        // Convert Vec<String> to Vec<&str> for compatibility with run_docker_compose
        let cmd_str_slices: Vec<&str> = cmd.iter().map(AsRef::as_ref).collect();

        let output = self.run_docker_compose(&cmd_str_slices)?;
        let stdout_str = String::from_utf8_lossy(&output.stdout);
        let lines: Vec<&str> = stdout_str.trim().split('\n').collect();

        let containers: Vec<ContainerInfo> = lines
            .iter()
            .filter_map(|&line| serde_json::from_str::<ContainerInfo>(line).ok())
            .collect();

        Ok(containers)
    }

    /// Compose version
    /// returns Option<String>
    pub fn compose_version() -> Option<String> {
        let output = run_command("docker", &["compose", "version", "--short"]).ok()?;
        if output.status.success() {
            let stdout_str = String::from_utf8_lossy(&output.stdout);
            let version = stdout_str.trim().to_string();
            Some(version)
        } else {
            None
        }
    }

    /// Execute a command in a compose service
    pub fn compose_dump_precomputed_blocks(
        &self,
        node_id: &str,
        network_id: &str,
    ) -> Result<Output> {
        let service = format!("{node_id}-{network_id}");
        let cmd = &[
            "exec",
            &service,
            "cat",
            &format!("/{CONFIG_DIRECTORY}/precomputed_blocks.log"),
        ];
        self.run_docker_compose(cmd)
    }

    /// Execute `pg_dump` on the postgres db
    pub fn compose_dump_archive_data(&self, network_id: &str) -> Result<Output> {
        let service = format!("postgres-{network_id}");
        let cmd = &[
            "exec", &service, "pg_dump", "--insert", "-U", "postgres", "archive",
        ];
        self.run_docker_compose(cmd)
    }

    /// Execute archive service replayer
    pub fn compose_run_replayer(&self, node_id: &str, network_id: &str) -> Result<Output> {
        // -input-file PATH (genesis ledger)
        // -output-file PATH (output ledger)
        let service = format!("{node_id}-{network_id}");
        let pg_archive_uri =
            format!("postgres://postgres:postgres@postgres-{network_id}:5432/archive");
        let cmd = &[
            "exec",
            &service,
            "mina-replayer",
            "--continue-on-error",
            "--input-file",
            &format!("/local-network/{}", REPLAYER_INPUT_JSON),
            "--archive-uri",
            &pg_archive_uri,
            "--output-file",
            "/dev/null",
        ];
        self.run_docker_compose(cmd)
    }

    pub fn compose_import_account(
        &self,
        node_id: &str,
        network_id: &str,
        account_file: &str,
    ) -> Result<Output> {
        let service = format!("{node_id}-{network_id}");
        let privkey_path = format!("/local-network/{NETWORK_KEYPAIRS}/{account_file}");
        let cmd = &[
            "run",
            "--rm",
            "--entrypoint",
            "mina",
            &service,
            "accounts",
            "import",
            "--privkey-path",
            privkey_path.as_str(),
            "--config-directory",
            &format!("/{CONFIG_DIRECTORY}"),
        ];
        self.run_docker_compose(cmd)
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

    /// Filter container by service name
    /// returns Option<ContainerInfo>
    pub fn filter_container_by_name(
        &self,
        containers: Vec<ContainerInfo>,
        service_name: &str,
    ) -> Option<ContainerInfo> {
        let containers: Vec<ContainerInfo> = containers
            .into_iter()
            .filter(|container| container.service == service_name)
            .collect();

        if containers.is_empty() {
            None
        } else {
            assert!(
                containers.len() == 1,
                "Expected 1 container for '{}', found {}",
                service_name,
                containers.len()
            );
            Some(containers.into_iter().next().unwrap())
        }
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

    pub fn run_docker_logs(&self, node_id: &str, network_id: &str) -> Result<Output> {
        let container = format!("{node_id}-{network_id}");
        let args: Vec<&str> = vec!["logs", &container];
        run_command("docker", &args)
    }
}

impl fmt::Display for ContainerState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let state_str = match self {
            ContainerState::Created => "created",
            ContainerState::Exited => "exited",
            ContainerState::Running => "running",
            ContainerState::Paused => "paused",
            ContainerState::Restarting => "restarting",
            ContainerState::Removing => "removing",
            ContainerState::Dead => "dead",
            ContainerState::Unknown => "unknown",
        };
        write!(f, "{}", state_str)
    }
}
