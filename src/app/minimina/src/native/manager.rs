use crate::archive;
use crate::directory_manager::CONFIG_DIRECTORY;
use crate::native::port_manager;
use crate::service::{ServiceConfig, ServiceType};
use crate::supervisor::{BackendSpec, NativeNodeSpec, SupervisorPlan};
use log::warn;
use std::fs;
use std::io::Result;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct NativeManager {
    pub network_path: PathBuf,
    pub bin_path: PathBuf,
}

impl NativeManager {
    pub fn new(network_path: &Path, bin_path: &Path) -> Self {
        NativeManager {
            network_path: network_path.to_path_buf(),
            bin_path: bin_path.to_path_buf(),
        }
    }

    fn logs_dir(&self) -> PathBuf {
        self.network_path.join("logs")
    }

    fn config_dir_for_service(&self, service_name: &str) -> PathBuf {
        self.network_path.join(CONFIG_DIRECTORY).join(service_name)
    }

    /// Generate native config (stores services.json, creates dirs)
    pub fn generate_config(&self, configs: &[ServiceConfig]) -> Result<()> {
        // Create logs directory
        fs::create_dir_all(self.logs_dir())?;
        // Create per-service config directories
        for config in configs {
            fs::create_dir_all(self.config_dir_for_service(&config.service_name))?;
        }
        Ok(())
    }

    /// No-op for native mode - processes are created on start
    pub fn create(&self, _specific_service: Option<String>) -> Result<std::process::Output> {
        Command::new("true").output()
    }

    /// Path of the supervisor's RPC socket for this network.
    pub fn supervisor_socket(network_path: &Path) -> PathBuf {
        network_path.join("supervisor.sock")
    }

    /// Build the [`SupervisorPlan`] the foreground supervisor runs: one
    /// [`NodeSpec`] per service (reusing the same command generation as
    /// [`Self::start_service`]), plus the shared env and per-service log path.
    /// Checks port availability up front so we fail before spawning anything.
    pub fn build_supervisor_plan(
        &self,
        services: &[ServiceConfig],
        network_id: &str,
    ) -> Result<SupervisorPlan> {
        let ports = port_manager::collect_all_ports(services);
        port_manager::check_ports_available(&ports)?;

        let network_path_str = self.network_path.to_str().unwrap();
        let mut nodes = Vec::new();

        // Archive: an ephemeral postgres process (its cluster is `initdb`'d and
        // schema-applied at `network create`) + the mina-archive service, both
        // launched before the daemons. The archive-node daemon itself is emitted
        // by the loop below (build_command adds `-archive-address 127.0.0.1:PORT`).
        if let Some(archive) = ServiceConfig::get_archive_node(services) {
            let archive_port = archive.archive_port.unwrap_or(archive::DEFAULT_ARCHIVE_PORT);
            let pgdata = self.network_path.join("pgdata");
            let socket_dir = archive::postgres_socket_dir(network_id);
            fs::create_dir_all(&socket_dir)?;
            nodes.push(NativeNodeSpec {
                name: archive::postgres_unit_name(),
                binary: PathBuf::from("postgres"),
                args: archive::postgres_server_args(
                    pgdata.to_str().unwrap(),
                    socket_dir.to_str().unwrap(),
                ),
                env: vec![],
                log_file: self.logs_dir().join("postgres.log"),
            });

            let svc_name = archive::archive_service_unit_name(&archive.service_name);
            nodes.push(NativeNodeSpec {
                name: svc_name.clone(),
                binary: self.bin_path.join("mina-archive"),
                args: archive::archive_service_args("localhost", archive_port),
                env: vec![
                    ("MINA_PRIVKEY_PASS".into(), "naughty blue worm".into()),
                    ("MINA_LIBP2P_PASS".into(), "naughty blue worm".into()),
                ],
                log_file: self.logs_dir().join(format!("{svc_name}.log")),
            });
        }

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
            nodes.push(NativeNodeSpec {
                name: service.service_name.clone(),
                binary,
                args,
                env: vec![
                    ("MINA_PRIVKEY_PASS".into(), "naughty blue worm".into()),
                    ("MINA_LIBP2P_PASS".into(), "naughty blue worm".into()),
                    ("MINA_CLIENT_TRUSTLIST".into(), "0.0.0.0/0".into()),
                    ("RAYON_NUM_THREADS".into(), "2".into()),
                ],
                log_file: self.logs_dir().join(format!("{}.log", service.service_name)),
            });
        }

        Ok(SupervisorPlan {
            network_id: network_id.to_string(),
            socket_path: Self::supervisor_socket(&self.network_path),
            spec: BackendSpec::Native { nodes },
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
                if let Some(archive_port) = service.archive_port {
                    args.push("-archive-address".to_string());
                    args.push(format!("127.0.0.1:{}", archive_port));
                }
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
