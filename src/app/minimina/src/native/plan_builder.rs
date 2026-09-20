//! Native plan builder: lowers `ServiceConfig`s to the [`SupervisorPlan`] the
//! supervisor runs (one child-process unit per service). Pure "describe", no
//! lifecycle — running, stopping, and reaping are the supervisor's job.

use crate::archive;
use crate::directory_manager::{CONFIG_DIRECTORY, LOGS_DIRECTORY};
use crate::native::port_manager;
use crate::native::postgres as native_postgres;
use crate::postgres;
use crate::service::{daemon_env, keypair_pass_env, ServiceConfig, ServiceType};
use crate::supervisor::plan::{NativeBackendSpec, NativeNodeSpec, Readiness, SupervisorPlan};
use log::warn;
use std::fs;
use std::io::Result;
use std::path::{Path, PathBuf};

pub struct NativePlanBuilder {
    pub network_path: PathBuf,
    pub bin_path: PathBuf,
}

impl NativePlanBuilder {
    pub fn new(network_path: &Path, bin_path: &Path) -> Self {
        NativePlanBuilder {
            network_path: network_path.to_path_buf(),
            bin_path: bin_path.to_path_buf(),
        }
    }

    fn logs_dir(&self) -> PathBuf {
        self.network_path.join(LOGS_DIRECTORY)
    }

    fn config_dir_for_service(&self, service_name: &str) -> PathBuf {
        self.network_path.join(CONFIG_DIRECTORY).join(service_name)
    }

    /// Create the on-disk directories the plan's units will write to
    /// (log dir + per-service config dirs).
    pub fn generate_config(&self, configs: &[ServiceConfig]) -> Result<()> {
        fs::create_dir_all(self.logs_dir())?;
        for config in configs {
            fs::create_dir_all(self.config_dir_for_service(&config.service_name))?;
        }
        Ok(())
    }

    /// Build the [`SupervisorPlan`] the foreground supervisor runs: one
    /// [`NativeNodeSpec`] per service, plus the shared env and per-service
    /// log path.
    /// Checks port availability up front so we fail before spawning anything.
    pub fn build_supervisor_plan(
        &self,
        services: &[ServiceConfig],
        network_id: &str,
    ) -> Result<SupervisorPlan> {
        let mut ports = port_manager::collect_all_ports(services);
        let mut nodes = Vec::new();

        // Archive: the ephemeral postgres cluster (already `initdb`'d and
        // provisioned at `network create`) plus the mina-archive service, both
        // ahead of the daemons and both gated, so nothing downstream can connect
        // to a database or a service that is not up yet. The archive-node daemon
        // itself is emitted by the loop below (build_command adds
        // `-archive-address 127.0.0.1:PORT`).
        if let Some(archive_node) = ServiceConfig::get_archive_node(services) {
            let archive_port = archive_node.resolved_archive_port();
            let pg = native_postgres::pg_config(&self.network_path)?;
            let pgdata = native_postgres::pgdata_dir(&self.network_path);
            let socket_dir = native_postgres::socket_dir(network_id);
            fs::create_dir_all(&socket_dir)?;
            ports.push(pg.port);
            ports.push(archive_port);

            nodes.push(
                NativeNodeSpec::new(
                    postgres::UNIT_NAME,
                    PathBuf::from("postgres"),
                    self.logs_dir().join("postgres.log"),
                )
                .args(native_postgres::server_args(&pgdata, &socket_dir, pg.port))
                .wait_for(Readiness::TcpPort(pg.port))
                // SIGTERM is postgres' *smart* shutdown — it waits for every
                // client to disconnect, which the archive-service's connection
                // pool never does in time. SIGINT is the fast one.
                .stop_signal(nix::sys::signal::Signal::SIGINT as i32),
            );

            let svc_name = archive::archive_service_unit_name(&archive_node.service_name);
            nodes.push(
                NativeNodeSpec::new(
                    &svc_name,
                    self.bin_path.join("mina-archive"),
                    self.logs_dir().join(format!("{svc_name}.log")),
                )
                .args(archive::archive_service_args(
                    &pg,
                    "localhost",
                    archive_port,
                ))
                .env(keypair_pass_env())
                .wait_for(Readiness::TcpPort(archive_port)),
            );
        }

        // Checked after the archive ports are known, and before anything is
        // spawned.
        port_manager::check_ports_available(&ports)?;

        let network_path_str = self.network_path.to_str().unwrap();

        for service in services {
            if service.service_type == ServiceType::UptimeServiceBackend {
                warn!(
                    "Skipping uptime service backend '{}' in native mode",
                    service.service_name
                );
                continue;
            }
            let config_dir = self.config_dir_for_service(&service.service_name);
            fs::create_dir_all(&config_dir)?;
            let config_dir_str = config_dir.to_str().unwrap();
            let (binary, args) =
                self.build_command(service, network_id, network_path_str, config_dir_str)?;
            nodes.push(
                NativeNodeSpec::new(
                    &service.service_name,
                    binary,
                    self.logs_dir()
                        .join(format!("{}.log", service.service_name)),
                )
                .args(args)
                .env(daemon_env()),
            );
        }

        Ok(SupervisorPlan {
            network_id: network_id.to_string(),
            socket_path: SupervisorPlan::socket_path_in(&self.network_path),
            spec: Box::new(NativeBackendSpec { nodes }),
        })
    }

    fn build_command(
        &self,
        service: &ServiceConfig,
        network_id: &str,
        network_path: &str,
        config_dir: &str,
    ) -> Result<(PathBuf, Vec<String>)> {
        let mina_bin = self.bin_path.join("mina");

        match service.service_type {
            ServiceType::ArchiveNode => {
                // The archive node daemon command
                // First we need the mina-archive service, but for native we combine them
                Ok((
                    mina_bin,
                    self.build_daemon_args(service, network_id, network_path, config_dir),
                ))
            }
            ServiceType::SnarkWorker => {
                let mut args = vec![
                    "internal".to_string(),
                    "snark-worker".to_string(),
                    "-shutdown-on-disconnect".to_string(),
                    "false".to_string(),
                    "-config-directory".to_string(),
                    config_dir.to_string(),
                ];

                if let (Some(_host), Some(port)) = (
                    &service.snark_coordinator_host,
                    service.snark_coordinator_port,
                ) {
                    args.push("-daemon-address".to_string());
                    // In native mode, all services are on localhost
                    args.push(format!("127.0.0.1:{}", port));
                }

                if let Some(proof_level) = &service.snark_worker_proof_level {
                    args.push("-proof-level".to_string());
                    args.push(proof_level.clone());
                }

                Ok((mina_bin, args))
            }
            _ => Ok((
                mina_bin,
                self.build_daemon_args(service, network_id, network_path, config_dir),
            )),
        }
    }

    fn build_daemon_args(
        &self,
        service: &ServiceConfig,
        _network_id: &str,
        network_path: &str,
        config_dir: &str,
    ) -> Vec<String> {
        let client_port = service.client_port.unwrap_or(3100);
        let rest_port = client_port + 1;
        let external_port = rest_port + 1;
        let metrics_port = external_port + 1;
        let libp2p_metrics_port = metrics_port + 1;

        let genesis_path = format!("{}/genesis_ledger.json", network_path);
        let precomputed_path = format!("{}/precomputed_blocks.log", config_dir);

        let mut args = vec![
            "daemon".to_string(),
            "-client-port".to_string(),
            client_port.to_string(),
            "-rest-port".to_string(),
            rest_port.to_string(),
            "-insecure-rest-server".to_string(),
            "-external-port".to_string(),
            external_port.to_string(),
            "-metrics-port".to_string(),
            metrics_port.to_string(),
            "-libp2p-metrics-port".to_string(),
            libp2p_metrics_port.to_string(),
            "-config-file".to_string(),
            genesis_path,
            "-log-json".to_string(),
            "-log-level".to_string(),
            "Trace".to_string(),
            "-file-log-level".to_string(),
            "Trace".to_string(),
            "-config-directory".to_string(),
            config_dir.to_string(),
            "-precomputed-blocks-file".to_string(),
            precomputed_path,
            "-log-txn-pool-gossip".to_string(),
            "true".to_string(),
            "-log-snark-work-gossip".to_string(),
            "true".to_string(),
            "-log-precomputed-blocks".to_string(),
            "true".to_string(),
            "-proof-level".to_string(),
            "full".to_string(),
        ];

        // Service-type-specific args
        match service.service_type {
            ServiceType::Seed => {
                args.push("-seed".to_string());
                self.add_libp2p_args(service, network_path, &mut args);
            }
            ServiceType::BlockProducer => {
                self.add_peers_args(service, network_path, &mut args);
                if service.private_key_path.is_some() {
                    args.push("-block-producer-key".to_string());
                    args.push(format!(
                        "{}/network-keypairs/{}.json",
                        network_path, service.service_name
                    ));
                }
                self.add_libp2p_args(service, network_path, &mut args);
            }
            ServiceType::SnarkCoordinator => {
                args.push("-work-selection".to_string());
                args.push("seq".to_string());
                self.add_peers_args(service, network_path, &mut args);
                if let Some(fees) = &service.snark_coordinator_fees {
                    args.push("-snark-worker-fee".to_string());
                    args.push(fees.clone());
                }
                if let Some(pk) = &service.public_key {
                    args.push("-run-snark-coordinator".to_string());
                    args.push(pk.clone());
                }
                self.add_libp2p_args(service, network_path, &mut args);
            }
            ServiceType::ArchiveNode => {
                self.add_peers_args(service, network_path, &mut args);
                args.push("-archive-address".to_string());
                args.push(format!("127.0.0.1:{}", service.resolved_archive_port()));
                self.add_libp2p_args(service, network_path, &mut args);
            }
            _ => {}
        }

        args
    }

    fn add_peers_args(&self, service: &ServiceConfig, network_path: &str, args: &mut Vec<String>) {
        if service.peer_list_file.is_some() {
            args.push("-peer-list-file".to_string());
            args.push(format!("{}/peer_list_file.txt", network_path));
        } else if let Some(peers) = &service.peers {
            for peer in peers {
                args.push("-peer".to_string());
                args.push(peer.clone());
            }
        }
    }

    fn add_libp2p_args(&self, service: &ServiceConfig, network_path: &str, args: &mut Vec<String>) {
        if service.libp2p_keypair_path.is_some() {
            args.push("-libp2p-keypair".to_string());
            args.push(format!(
                "{}/libp2p-keypairs/{}.json",
                network_path, service.service_name
            ));
        } else if let Some(keypair) = &service.libp2p_keypair {
            args.push("-libp2p-keypair".to_string());
            args.push(keypair.clone());
        }
    }
}
