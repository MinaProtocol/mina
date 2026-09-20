//! Docker plan builder: lowers `ServiceConfig`s to the [`SupervisorPlan`] the
//! supervisor runs (one bollard container unit per service). Pure "describe",
//! no lifecycle — creating, starting, and removing containers is the
//! supervisor's job.

use crate::archive;
use crate::directory_manager::CONFIG_DIRECTORY;
use crate::docker::postgres as docker_postgres;
use crate::postgres::PgConfig;
use crate::service::{daemon_env, ServiceConfig, ServiceType};
use crate::supervisor::plan::{DockerBackendSpec, DockerNodeSpec, Readiness, SupervisorPlan};
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
    /// Archive is expanded to postgres + archive-service + archive-node units;
    /// the uptime-service backend is not yet ported to bollard.
    pub fn build_supervisor_plan(
        &self,
        services: &[ServiceConfig],
        network_id: &str,
    ) -> Result<SupervisorPlan> {
        let network_path_str = self.network_path.to_str().unwrap().to_string();
        let mut nodes = Vec::new();

        // Archive infra first (so postgres/archive-service launch before daemons):
        // an ephemeral postgres container (POSTGRES_DB + initdb.d schema applied on
        // first boot) and the mina-archive service. Both reachable by daemons via
        // docker DNS on their `<name>-<network>` container name / alias. In the new
        // spec a unit's `name` *is* the container name and network alias, so the
        // peer/archive hostnames the commands bake in resolve directly.
        if let Some(archive_node) = ServiceConfig::get_archive_node(services) {
            let archive_port = archive_node.resolved_archive_port();
            let pg = PgConfig::default();
            let pg_container = docker_postgres::container_name(network_id);
            let svc_container = format!(
                "{}-{network_id}",
                archive::archive_service_unit_name(&archive_node.service_name)
            );

            // No published ports: internal-only, reached via DNS — which is also
            // why readiness is an exec rather than a connect from the host.
            nodes.push(
                DockerNodeSpec::new(pg_container.clone(), docker_postgres::IMAGE)
                    .env(docker_postgres::container_env(&pg))
                    .mount_ro(
                        docker_postgres::initdb_dir(&self.network_path)
                            .to_str()
                            .unwrap(),
                        "/docker-entrypoint-initdb.d",
                    )
                    .wait_for(Readiness::Command(docker_postgres::readiness_command(&pg))),
            );

            let svc_image = archive_node.archive_docker_image.clone().ok_or_else(|| {
                std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    format!(
                        "missing archive docker image for '{}'",
                        archive_node.service_name
                    ),
                )
            })?;
            let mut svc_cmd = vec!["mina-archive".to_string()];
            svc_cmd.extend(archive::archive_service_args(
                &pg,
                &pg_container,
                archive_port,
            ));
            nodes.push(
                DockerNodeSpec::new(svc_container, svc_image)
                    .cmd(svc_cmd)
                    .mount_rw(network_path_str.clone(), "/local-network"),
            );
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

            nodes.push(
                DockerNodeSpec::new(container_name, image)
                    .entrypoint(vec!["mina".to_string()])
                    .cmd(cmd_str.split_whitespace().map(str::to_string).collect())
                    .env(daemon_env())
                    .ports(ports)
                    .mount_rw(network_path_str.clone(), "/local-network")
                    .mount_rw(
                        config_dir_host.to_str().unwrap(),
                        format!("/{CONFIG_DIRECTORY}"),
                    ),
            );
        }

        Ok(SupervisorPlan {
            network_id: network_id.to_string(),
            socket_path: SupervisorPlan::socket_path_in(&self.network_path),
            spec: Box::new(DockerBackendSpec {
                network_name: format!("minimina-{network_id}"),
                nodes,
            }),
        })
    }
}
