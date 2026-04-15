//! # Output Module
//!
//! This module is designed to serialize command output into JSON format.
//!
//! It primarily focuses on operations related to networks and nodes:
//!
//! - `network`: Structures and implementations for serializing output related to various network operations like
//!   creation, start, listing, stopping, and more.
//! - `node`: Structures and implementations for serializing output concerning node information and various node-related actions.
//! - `Error`: Represents an error structure to be serialized into JSON format with an accompanying error message.
//!
//! This module also offers utility functions such as `generate_network_info` and implements display
//! formatting for a number of types to further facilitate serialization.

use crate::service::{ServiceConfig, ServiceType};
use std::collections::HashMap;

pub mod network {
    use serde::{Deserialize, Serialize};

    use crate::docker::manager::{ComposeInfo, ContainerInfo};

    #[derive(Debug, Serialize, Deserialize, PartialEq)]
    pub struct Create {
        pub network_id: String,
        pub nodes: std::collections::HashMap<String, super::node::Info>,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Start {
        pub network_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct ListInfo {
        pub network_id: String,
        pub config_dir: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct List {
        pub networks: Vec<ListInfo>,
    }

    impl List {
        pub fn new() -> Self {
            List { networks: vec![] }
        }

        pub fn update(&mut self, networks: Vec<String>, base_dir: &str) {
            for network in networks {
                let config_dir = format!("{}/{}", base_dir, network);
                self.add_network(network, config_dir.as_str());
            }
        }

        pub fn add_network(&mut self, network_id: String, config_dir: &str) {
            self.networks.push(ListInfo {
                network_id,
                config_dir: config_dir.to_string(),
            });
        }
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Stop {
        pub network_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Status {
        pub network_id: String,
        pub status: String,
        pub network_dir: String,
        pub docker_compose_file: String,
        pub services: Vec<super::node::Status>,
    }

    impl Status {
        pub fn new(network_id: &str) -> Self {
            Status {
                network_id: network_id.to_string(),
                status: "unknown".to_string(),
                network_dir: "unknown".to_string(),
                docker_compose_file: "unknown".to_string(),
                services: vec![],
            }
        }

        /// Parse the output of `docker compose ls --format json` to get the status of the network
        pub fn update_from_compose_ls(
            &mut self,
            ls_out: Vec<ComposeInfo>,
            compose_file_path: &str,
        ) {
            // get status and config_files of network for compose info where name == network_id
            let network_status = ls_out
                .iter()
                .find(|compose_info| compose_info.name == self.network_id)
                .map(|compose_info| compose_info.status.clone())
                .unwrap_or_else(|| "not_running".to_string());

            let config_files = ls_out
                .iter()
                .find(|compose_info| compose_info.name == self.network_id)
                .map(|compose_info| compose_info.config_files.clone())
                .unwrap_or_else(|| compose_file_path.to_string());

            self.status = network_status;
            self.docker_compose_file = config_files;
        }

        /// Parse the output of `docker compose ps --format json` to get the status of the nodes
        pub fn update_from_compose_ps(&mut self, ps_out: Vec<ContainerInfo>) {
            ps_out.iter().for_each(|container| {
                let node_id = container.name.clone();
                let status = container.status.clone();
                // let command = container.command.clone();
                let docker_image = container.image.clone();
                let state = container.state.clone();
                self.services.push(super::node::Status {
                    id: node_id,
                    state,
                    status,
                    // command,
                    docker_image,
                });
            });
        }
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Delete {
        pub network_id: String,
    }
}

pub mod node {
    use crate::docker::manager::ContainerState;

    // Import ServiceType from service module
    use super::ServiceType;
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
    pub struct Info {
        pub graphql_uri: Option<String>,
        pub private_key: Option<String>,
        pub node_type: ServiceType,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Status {
        pub id: String,
        pub state: ContainerState,
        pub status: String,
        // pub command: String,
        pub docker_image: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Start {
        // pub fresh_state: bool,
        pub network_id: String,
        pub node_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Stop {
        pub network_id: String,
        pub node_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct ArchiveData {
        pub data: String,
        pub network_id: String,
        pub node_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct Logs {
        pub logs: String,
        pub network_id: String,
        pub node_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct PrecomputedBlocks {
        pub blocks: String,
        pub network_id: String,
        pub node_id: String,
    }

    #[derive(Debug, Serialize, PartialEq)]
    pub struct ReplayerLogs {
        pub logs: String,
        pub network_id: String,
        pub node_id: String,
    }
}

#[derive(Debug, serde::Serialize)]
pub struct Error {
    pub error_message: String,
}

impl ServiceConfig {
    pub fn to_node_info(&self) -> node::Info {
        node::Info {
            graphql_uri: self
                .client_port
                .map(|port| format!("http://localhost:{}/graphql", port + 1)),
            private_key: self.private_key.clone(),
            node_type: self.service_type.clone(),
        }
    }
}

pub fn generate_network_info(services: &[ServiceConfig], network_id: &str) -> network::Create {
    let mut nodes: HashMap<String, node::Info> = HashMap::new();
    for service in services.iter() {
        nodes.insert(service.service_name.clone(), service.to_node_info());
    }

    network::Create {
        network_id: network_id.to_string(),
        nodes,
    }
}

macro_rules! impl_display {
    ($name:path) => {
        impl std::fmt::Display for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "{}", serde_json::to_string_pretty(self).unwrap())?;
                Ok(())
            }
        }
    };
}

impl_display!(network::Create);
impl_display!(network::Start);
impl_display!(network::Stop);
impl_display!(network::Status);
impl_display!(network::ListInfo);
impl_display!(network::List);
impl_display!(network::Delete);
impl_display!(node::Start);
impl_display!(node::Stop);
impl_display!(node::ArchiveData);
impl_display!(node::Logs);
impl_display!(node::PrecomputedBlocks);
impl_display!(node::ReplayerLogs);
impl_display!(node::Status);
impl_display!(Error);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_network_info() {
        let network_id = "generate_network_info_id";
        let bp_service = ServiceConfig {
            service_type: ServiceType::BlockProducer,
            service_name: "BP".to_string(),
            docker_image: Some("bp-image".to_string()),
            git_build: None,
            client_port: Some(8080),
            public_key: Some("B62qjVQQTbzsoC8AJMPdJERChzy2y49JzykPVeNKpeXqfeZcwwK5SwF".to_string()),
            public_key_path: None,
            private_key: Some("EKEQpDAjj7dP3j7fQy4qBU7Kxns85wwq5xMn4zxdyQm83pEWzQ62".to_string()),
            private_key_path: None,
            libp2p_keypair: None,
            libp2p_keypair_path: None,
            libp2p_peerid: None,
            peers: None,
            peer_list_file: None,
            snark_coordinator_port: None,
            snark_coordinator_fees: None,
            snark_worker_proof_level: None,
            archive_schema_files: None,
            archive_port: None,
            archive_docker_image: None,
            worker_nodes: None,
            snark_coordinator_host: None,
            ..Default::default()
        };
        let services = vec![bp_service.clone()];

        let bp_info = node::Info {
            graphql_uri: Some(format!(
                "http://localhost:{}/graphql",
                bp_service.client_port.unwrap() + 1
            )),
            private_key: bp_service.private_key,
            node_type: bp_service.service_type,
        };
        let expect = network::Create {
            network_id: network_id.to_string(),
            nodes: HashMap::from([(bp_service.service_name.clone(), bp_info.clone())]),
        };

        assert_eq!(
            serde_json::to_value(bp_info)
                .unwrap()
                .get("node_type")
                .unwrap(),
            &serde_json::to_value("Block_producer").unwrap()
        );
        assert_eq!(expect, generate_network_info(&services, network_id));
    }
}
