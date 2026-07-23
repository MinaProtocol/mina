//! # Docker Manager Module
//!
//! Provides an interface for managing Docker operations within the application.
//! Specifically, it offers functionalities to:
//! - Generate a `docker-compose.yaml` file from provided service configurations.
//! - Start up services using the generated Docker Compose file.
//! - Shut down active services.
//! - Handle interactions with the Docker CLI.

use crate::directory_manager::{CONFIG_DIRECTORY, NETWORK_KEYPAIRS};
use crate::genesis_ledger::REPLAYER_INPUT_JSON;
use crate::archive;
use crate::supervisor::{BackendSpec, DockerNodeSpec, Mount, SupervisorPlan};
use crate::{
    service::{ServiceConfig, ServiceType},
    utils::run_command,
};
use serde::{Deserialize, Serialize};
use std::fmt;
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

    /// Path of the supervisor's RPC socket for this network.
    pub fn supervisor_socket(network_path: &Path) -> PathBuf {
        network_path.join("supervisor.sock")
    }

    /// Build the [`SupervisorPlan`] for docker mode: one container **unit** per
    /// daemon service, reusing the same command generation as the (legacy) compose
    /// backend. Container name == network alias == `<service>-<network_id>` so the
    /// peer/archive hostnames the commands bake in resolve via docker DNS; the
    /// host network dir is bind-mounted at `/local-network` and a per-service
    /// config dir at `/config-directory` (both paths the commands expect).
    ///
    /// Archive is expanded to postgres + archive-service + archive-node units;
    /// the uptime-service backend is not yet ported to bollard.
    pub fn build_docker_supervisor_plan(
        &self,
        services: &[ServiceConfig],
        network_id: &str,
    ) -> Result<SupervisorPlan> {
        let network_path_str = self.network_path.to_str().unwrap().to_string();
        let mut nodes = Vec::new();

        // Archive infra first (so postgres/archive-service launch before daemons):
        // an ephemeral postgres container (POSTGRES_DB + initdb.d schema applied on
        // first boot) and the mina-archive service. Both reachable by daemons via
        // docker DNS on their `<name>-<network>` alias.
        if let Some(archive) = ServiceConfig::get_archive_node(services) {
            let archive_port = archive.archive_port.unwrap_or(archive::DEFAULT_ARCHIVE_PORT);
            let pg_container = format!("postgres-{network_id}");
            let svc_container =
                format!("{}-{network_id}", archive::archive_service_unit_name(&archive.service_name));

            nodes.push(DockerNodeSpec {
                name: archive::postgres_unit_name(),
                container_name: pg_container.clone(),
                image: archive::PG_IMAGE.to_string(),
                entrypoint: None,
                cmd: vec![],
                env: archive::PgConfig::default().container_env(),
                ports: vec![], // internal-only; reached via DNS
                mounts: vec![Mount {
                    host: self
                        .network_path
                        .join("postgres-initdb")
                        .to_str()
                        .unwrap()
                        .to_string(),
                    container: "/docker-entrypoint-initdb.d".into(),
                    read_only: true,
                }],
                aliases: vec![pg_container.clone()],
            });

            let mut svc_cmd = vec!["mina-archive".to_string()];
            svc_cmd.extend(archive::archive_service_args(&pg_container, archive_port));
            nodes.push(DockerNodeSpec {
                name: archive::archive_service_unit_name(&archive.service_name),
                container_name: svc_container.clone(),
                image: archive.archive_docker_image.clone().ok_or_else(|| {
                    std::io::Error::new(
                        std::io::ErrorKind::InvalidInput,
                        format!("missing archive docker image for '{}'", archive.service_name),
                    )
                })?,
                entrypoint: None,
                cmd: svc_cmd,
                env: vec![],
                ports: vec![],
                mounts: vec![Mount {
                    host: network_path_str.clone(),
                    container: "/local-network".into(),
                    read_only: false,
                }],
                aliases: vec![svc_container],
            });
        }

        for config in services {
            let cmd_str = match config.service_type {
                ServiceType::Seed => config.generate_seed_command(),
                ServiceType::BlockProducer => config.generate_block_producer_command(None),
                ServiceType::SnarkCoordinator => config.generate_snark_coordinator_command(),
                ServiceType::SnarkWorker => {
                    config.generate_snark_worker_command(network_id.to_string())
                }
                ServiceType::ArchiveNode => {
                    // The archive-node daemon forwards blocks to the archive-service
                    // container via docker DNS.
                    let svc_host = format!(
                        "{}-{network_id}",
                        archive::archive_service_unit_name(&config.service_name)
                    );
                    config.generate_archive_command(svc_host)
                }
                ServiceType::UptimeServiceBackend => {
                    return Err(std::io::Error::new(
                        std::io::ErrorKind::Unsupported,
                        format!(
                            "service '{}' ({:?}) is not yet supported on the bollard docker backend",
                            config.service_name, config.service_type
                        ),
                    ));
                }
            };

            let container_name = format!("{}-{}", config.service_name, network_id);
            let config_dir_host = self
                .network_path
                .join(CONFIG_DIRECTORY)
                .join(&config.service_name);
            std::fs::create_dir_all(&config_dir_host)?;

            let ports = match config.client_port {
                Some(port) => {
                    let gql = port + 1;
                    let external = port + 2;
                    vec![(port, port), (gql, gql), (external, external)]
                }
                None => vec![],
            };

            let image = config.docker_image.clone().ok_or_else(|| {
                std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    format!("missing docker image for '{}'", config.service_name),
                )
            })?;

            nodes.push(DockerNodeSpec {
                name: config.service_name.clone(),
                container_name: container_name.clone(),
                image,
                entrypoint: Some(vec!["mina".to_string()]),
                cmd: cmd_str.split_whitespace().map(str::to_string).collect(),
                env: vec![
                    ("MINA_PRIVKEY_PASS".into(), "naughty blue worm".into()),
                    ("MINA_LIBP2P_PASS".into(), "naughty blue worm".into()),
                    ("MINA_CLIENT_TRUSTLIST".into(), "0.0.0.0/0".into()),
                    ("RAYON_NUM_THREADS".into(), "2".into()),
                ],
                ports,
                mounts: vec![
                    Mount {
                        host: network_path_str.clone(),
                        container: "/local-network".into(),
                        read_only: false,
                    },
                    Mount {
                        host: config_dir_host.to_str().unwrap().to_string(),
                        container: format!("/{CONFIG_DIRECTORY}"),
                        read_only: false,
                    },
                ],
                aliases: vec![container_name],
            });
        }

        Ok(SupervisorPlan {
            network_id: network_id.to_string(),
            socket_path: Self::supervisor_socket(&self.network_path),
            spec: BackendSpec::Docker {
                network_name: format!("minimina-{network_id}"),
                nodes,
            },
        })
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
