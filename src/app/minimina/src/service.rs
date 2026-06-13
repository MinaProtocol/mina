//! # Service Module
//!
//! This module provides structures and methods to hold and manage configurations for different Mina daemons.
//! With these configurations, docker-compose files can be dynamically generated to deploy and manage nodes in the network.

use log::warn;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::{
    docker::compose::CONFIG_DIRECTORY, genesis_ledger::GENESIS_LEDGER_JSON, topology::GitBuild,
};

#[derive(Debug, Serialize, Deserialize, PartialEq, Clone, Default)]
pub enum ServiceType {
    #[serde(rename = "Seed_node")]
    Seed,
    #[default]
    #[serde(rename = "Block_producer")]
    BlockProducer,
    #[serde(rename = "Snark_worker")]
    SnarkWorker,
    #[serde(rename = "Snark_coordinator")]
    SnarkCoordinator,
    #[serde(rename = "Archive_node")]
    ArchiveNode,
    #[serde(rename = "Uptime_service_backend")]
    UptimeServiceBackend,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ServiceConfig {
    pub service_type: ServiceType,
    pub service_name: String,
    pub docker_image: Option<String>,
    pub git_build: Option<GitBuild>,
    pub client_port: Option<u16>,
    pub public_key: Option<String>,
    pub public_key_path: Option<String>,
    pub private_key: Option<String>,
    /// Path to the privkey file used by `mina daemon --block-producer-key KEYFILE ...`
    pub private_key_path: Option<PathBuf>,
    pub libp2p_keypair: Option<String>,
    /// Path to the libp2p keyfile used by `mina daemon --libp2p-keypair KEYFILE ...`
    pub libp2p_keypair_path: Option<PathBuf>,
    pub libp2p_peerid: Option<String>,
    pub peers: Option<Vec<String>>,
    /// Path to the file used by `mina daemon --peer-list-file PATH ...`
    pub peer_list_file: Option<PathBuf>,

    //snark coordinator specific
    pub snark_coordinator_fees: Option<String>,
    pub worker_nodes: Option<u16>,

    //snark worker specific
    pub snark_worker_proof_level: Option<String>,
    // on snark_worker -daemon-address <snark_coordinator_host>:<snark_coordinator_port>
    pub snark_coordinator_host: Option<String>,
    pub snark_coordinator_port: Option<u16>,

    //archive node specific
    pub archive_docker_image: Option<String>,
    pub archive_schema_files: Option<Vec<String>>,
    pub archive_port: Option<u16>,

    //uptime service backend specific
    pub uptime_service_backend_app_config: Option<PathBuf>,
    pub uptime_service_backend_minasheets: Option<PathBuf>,
    pub uptime_service_other_config_files: Option<Vec<PathBuf>>,
}

impl ServiceConfig {
    pub fn generate_peer(
        seed_name: &str,
        network_name: &str,
        libp2p_peerid: &str,
        external_port: u16,
    ) -> String {
        let seed_host = format!("{}-{}", seed_name, network_name);
        format!(
            "/dns4/{}/tcp/{}/p2p/{}",
            seed_host, external_port, libp2p_peerid
        )
    }

    /// Generate base daemon command common for most mina services
    pub fn generate_base_command(&self) -> Vec<String> {
        let client_port = self.client_port.unwrap_or(3100);
        let rest_port = client_port + 1;
        let external_port = rest_port + 1;
        let metrics_port = external_port + 1;
        let libp2p_metrics_port = metrics_port + 1;

        vec![
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
            format!("/local-network/{GENESIS_LEDGER_JSON}"),
            "-log-json".to_string(),
            "-log-level".to_string(),
            "Trace".to_string(),
            "-file-log-level".to_string(),
            "Trace".to_string(),
            "-config-directory".to_string(),
            format!("/{CONFIG_DIRECTORY}"),
            "-precomputed-blocks-file".to_string(),
            format!("/{CONFIG_DIRECTORY}/precomputed_blocks.log"),
            "-log-txn-pool-gossip".to_string(),
            "true".to_string(),
            "-log-snark-work-gossip".to_string(),
            "true".to_string(),
            "-log-precomputed-blocks".to_string(),
            "true".to_string(),
            "-proof-level".to_string(),
            "full".to_string(),
        ]
    }

    /// Generate command for seed node
    pub fn generate_seed_command(&self) -> String {
        assert_eq!(self.service_type, ServiceType::Seed);

        let mut base_command = self.generate_base_command();
        base_command.push("-seed".to_string());

        self.add_libp2p_command(&mut base_command);
        base_command.join(" ")
    }

    pub fn generate_archive_command(&self, archive_service_host: String) -> String {
        assert_eq!(self.service_type, ServiceType::ArchiveNode);
        let mut base_command = self.generate_base_command();

        // Handling multiple peers
        self.add_peers_command(&mut base_command);

        if let Some(archive_port) = &self.archive_port {
            base_command.push("-archive-address".to_string());
            base_command.push(format!("{}:{}", archive_service_host, archive_port));
        } else {
            warn!(
                "No archive port provided for archive node '{}'. This is not recommended.",
                self.service_name
            );
        }

        self.add_libp2p_command(&mut base_command);
        base_command.join(" ")
    }

    /// Generate command for block producer node
    pub fn generate_block_producer_command(
        &self,
        uptime_service_hostname: Option<String>,
    ) -> String {
        assert_eq!(self.service_type, ServiceType::BlockProducer);

        let mut base_command = self.generate_base_command();

        // Handling multiple peers
        self.add_peers_command(&mut base_command);

        if let Some(uptime_service_host) = &uptime_service_hostname {
            base_command.push("-uptime-url".to_string());
            base_command.push(format!("http://{}:8080/v1/submit", uptime_service_host));
        }

        if self.private_key_path.is_some() {
            base_command.push("-block-producer-key".to_string());
            base_command.push(format!(
                "/local-network/network-keypairs/{}.json",
                self.service_name
            ));
            if uptime_service_hostname.is_some() {
                base_command.push("-uptime-submitter-key".to_string());
                base_command.push(format!(
                    "/local-network/network-keypairs/{}.json",
                    self.service_name
                ));
            }
        } else if let Some(public_key_path) = &self.public_key_path {
            base_command.push("-block-producer-key".to_string());
            base_command.push(public_key_path.clone());
            if uptime_service_hostname.is_some() {
                base_command.push("-uptime-submitter-key".to_string());
                base_command.push(public_key_path.clone());
            }
        } else {
            warn!(
                "No public or private key path provided for block producer node '{}'. This is not recommended.",
                self.service_name
            );
        }

        self.add_libp2p_command(&mut base_command);
        base_command.join(" ")
    }

    /// Generate command for snark coordinator node
    pub fn generate_snark_coordinator_command(&self) -> String {
        assert_eq!(self.service_type, ServiceType::SnarkCoordinator);

        let mut base_command = self.generate_base_command();

        base_command.push("-work-selection".to_string());
        base_command.push("seq".to_string());

        self.add_peers_command(&mut base_command);

        if let Some(snark_worker_fees) = &self.snark_coordinator_fees {
            base_command.push("-snark-worker-fee".to_string());
            base_command.push(snark_worker_fees.clone());
        } else {
            warn!(
                "No snark worker fees provided for snark coordinator node '{}'. This is not recommended.",
                self.service_name
            );
        }

        if let Some(public_key) = &self.public_key {
            base_command.push("-run-snark-coordinator".to_string());
            base_command.push(public_key.clone());
        } else {
            warn!(
                "No public key provided for snark coordinator node '{}'. This is not recommended.",
                self.service_name
            );
        }

        self.add_libp2p_command(&mut base_command);
        base_command.join(" ")
    }

    /// Generate command for snark worker node
    pub fn generate_snark_worker_command(&self, network_name: String) -> String {
        assert_eq!(self.service_type, ServiceType::SnarkWorker);
        let mut base_command = vec![
            "internal".to_string(),
            "snark-worker".to_string(),
            "-shutdown-on-disconnect".to_string(),
            "false".to_string(),
            "-config-directory".to_string(),
            format!("/{CONFIG_DIRECTORY}"),
        ];

        if let (Some(host), Some(port)) =
            (&self.snark_coordinator_host, self.snark_coordinator_port)
        {
            base_command.push("-daemon-address".to_string());
            base_command.push(format!("{}-{}:{}", host, network_name, port));
        } else {
            warn!(
                "No snark coordinator port or host provided for snark worker node '{}'. This is not recommended.",
                self.service_name
            );
        }

        if let Some(proof_level) = &self.snark_worker_proof_level {
            base_command.push("-proof-level".to_string());
            base_command.push(proof_level.clone());
        } else {
            warn!(
                "No proof level provided for snark worker node '{}'. This is not recommended.",
                self.service_name
            );
        }

        base_command.join(" ")
    }

    fn add_peers_command(&self, base_command: &mut Vec<String>) {
        if self.peer_list_file.is_some() {
            base_command.push("-peer-list-file".to_string());
            base_command.push("/local-network/peer_list_file.txt".into());
        } else if let Some(ref peers) = self.peers {
            for peer in peers.iter() {
                base_command.push("-peer".to_string());
                base_command.push(peer.clone());
            }
        } else {
            warn!(
                "No peers provided for block producer node '{}'. This is not recommended.",
                self.service_name
            );
        }
    }

    fn add_libp2p_command(&self, base_command: &mut Vec<String>) {
        if self.libp2p_keypair_path.is_some() {
            base_command.push("-libp2p-keypair".to_string());
            base_command.push(format!(
                "/local-network/libp2p-keypairs/{}.json",
                self.service_name
            ));
        } else if let Some(libp2p_keypair) = &self.libp2p_keypair {
            base_command.push("-libp2p-keypair".to_string());
            base_command.push(libp2p_keypair.clone());
        } else {
            warn!(
                "No libp2p keypair provided for node '{}'. This is not recommended.",
                self.service_name
            );
        }
    }

    pub fn get_seeds(services: &[Self]) -> Vec<&Self> {
        services
            .iter()
            .filter(|service| ServiceType::Seed == service.service_type)
            .collect()
    }

    pub fn get_archive_node(services: &[Self]) -> Option<&Self> {
        let mut archive_nodes = services
            .iter()
            .filter(|s| s.service_type == ServiceType::ArchiveNode);

        let first_node = archive_nodes.next();

        if archive_nodes.next().is_some() {
            panic!("There can only be one archive node in topology");
        }

        first_node
    }

    pub fn get_uptime_service_backend(services: &[Self]) -> Option<&Self> {
        let mut uptime_service_backends = services
            .iter()
            .filter(|s| s.service_type == ServiceType::UptimeServiceBackend);

        let first_backend = uptime_service_backends.next();

        if uptime_service_backends.next().is_some() {
            panic!("There can only be one uptime service backend in topology");
        }

        first_backend
    }
}
