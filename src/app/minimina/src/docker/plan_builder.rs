//! Docker plan builder: lowers `ServiceConfig`s to the [`SupervisorPlan`] the
//! supervisor runs (one bollard container unit per service). Pure "describe",
//! no lifecycle — creating, starting, and removing containers is the
//! supervisor's job.

use crate::directory_manager::CONFIG_DIRECTORY;
use crate::service::{ServiceConfig, ServiceType};
use crate::supervisor::plan::{BackendSpec, DockerNodeSpec, Mount, SupervisorPlan};
use std::io::Result;
use std::path::{Path, PathBuf};

pub struct DockerPlanBuilder {
    pub network_path: PathBuf,
}

impl DockerPlanBuilder {
    pub fn new(network_path: &Path) -> Self {
        DockerPlanBuilder {
            network_path: network_path.to_path_buf(),
        }
    }

    /// Build the [`SupervisorPlan`] for docker mode: one container **unit** per
    /// daemon service, reusing the same command generation as the (legacy) compose
    /// backend. Container name == network alias == `<service>-<network_id>` so the
    /// peer/archive hostnames the commands bake in resolve via docker DNS; the
    /// host network dir is bind-mounted at `/local-network` and a per-service
    /// config dir at `/config-directory` (both paths the commands expect).
    ///
    /// Archive and uptime-service backends are not yet ported to bollard.
    pub fn build_supervisor_plan(
        &self,
        services: &[ServiceConfig],
        network_id: &str,
    ) -> Result<SupervisorPlan> {
        let network_path_str = self.network_path.to_str().unwrap().to_string();
        let mut nodes = Vec::new();

        for config in services {
            let cmd_str = match config.service_type {
                ServiceType::Seed => config.generate_seed_command(),
                ServiceType::BlockProducer => config.generate_block_producer_command(None),
                ServiceType::SnarkCoordinator => config.generate_snark_coordinator_command(),
                ServiceType::SnarkWorker => {
                    config.generate_snark_worker_command(network_id.to_string())
                }
                ServiceType::ArchiveNode | ServiceType::UptimeServiceBackend => {
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
                name: container_name.clone(),
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
            socket_path: SupervisorPlan::socket_path_in(&self.network_path),
            spec: BackendSpec::Docker {
                network_name: format!("minimina-{network_id}"),
                nodes,
            },
        })
    }
}
