//! # Keys Module
//!
//! This module provides functionalities related to key management for local network.
//! It contains:
//! - Structures to represent mina node keys (`NodeKey`).
//! - A manager (`KeysManager`) that provides methods for generating:
//!   - Block producer key pairs.
//!   - libp2p key pairs.
//!
//! The `KeysManager` relies on Docker and a specific Docker image to generate these key pairs,
//! and uses the filesystem to store and manage these keys. It is designed to produce keys for multiple services
//! and ensure the necessary environment settings are present during the key generation process.
//!
//! Typical use involves creating a `KeysManager` instance with the desired configurations,
//! then invoking the key generation methods as needed.

use std::{
    collections::HashMap,
    path::{Path, PathBuf},
};

use log::{debug, info};

use crate::utils::{get_current_user_uid_gid, run_command};

#[derive(Debug)]
pub struct NodeKey {
    pub key_string: String,
    pub key_path: String,
}

pub struct KeysManager {
    pub network_path: PathBuf,
    pub docker_image: String,
}

impl KeysManager {
    pub fn new(network_path: &Path, docker_image: &str) -> Self {
        KeysManager {
            network_path: network_path.to_path_buf(),
            docker_image: docker_image.to_string(),
        }
    }
    // generate bp key pair for single service
    pub fn generate_bp_key_pair(&self, service_name: &str) -> std::io::Result<NodeKey> {
        info!("Creating block producer keys for: {}", service_name);
        let uid_gid = match get_current_user_uid_gid() {
            Some(uid_gid) => uid_gid,
            None => {
                return Err(std::io::Error::other(
                    "Unable to retrieve UID and GID of current user",
                ))
            }
        };

        let key_subdir = "network-keypairs";
        let volume_path = format!("{}:/local-network", self.network_path.to_str().unwrap());
        let pkey_path = format!("/local-network/{}/{}", key_subdir, service_name);
        let args = vec![
            "run",
            "--rm",
            "--user",
            uid_gid.as_str(),
            "--env",
            "MINA_PRIVKEY_PASS=naughty blue worm",
            "--entrypoint",
            "mina",
            "-v",
            &volume_path,
            self.docker_image.as_str(),
            "advanced",
            "generate-keypair",
            "-privkey-path",
            &pkey_path,
        ];

        let output = run_command("docker", &args)?;

        let stdout_str = String::from_utf8_lossy(&output.stdout);
        let public_key_line = stdout_str
            .lines()
            .find(|line| line.contains("Public key: "))
            .ok_or_else(|| {
                std::io::Error::new(std::io::ErrorKind::NotFound, "Public key not found")
            })?;

        let public_key = public_key_line
            .split(": ")
            .nth(1)
            .ok_or_else(|| {
                std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    "Public key format is incorrect",
                )
            })?
            .to_string();

        let keys = NodeKey {
            key_string: public_key,
            key_path: pkey_path,
        };
        debug!("Generated keypair: {:?}", keys);
        Ok(keys)
    }

    // generate bp key pairs for multiple services
    pub fn generate_bp_key_pairs(
        &self,
        service_names: &[&str],
    ) -> std::io::Result<HashMap<String, NodeKey>> {
        let mut public_keys = HashMap::new();
        for &service_name in service_names {
            let public_key = self.generate_bp_key_pair(service_name)?;
            public_keys.insert(service_name.to_string(), public_key);
        }
        Ok(public_keys)
    }

    // generate libp2p key pair for single service
    pub fn generate_libp2p_key_pair(&self, service_name: &str) -> std::io::Result<NodeKey> {
        info!("Creating libp2p keys for: {}", service_name);

        let key_subdir = "libp2p-keypairs";
        let volume_path = format!("{}:/local-network", self.network_path.to_str().unwrap());
        let pkey_path = format!("/local-network/{}/{}", key_subdir, service_name);

        let args = vec![
            "run",
            "--rm",
            // "--user",
            // "1000:1000",
            "--env",
            "MINA_LIBP2P_PASS=naughty blue worm",
            "--entrypoint",
            "mina",
            "-v",
            &volume_path,
            self.docker_image.as_str(),
            "libp2p",
            "generate-keypair",
            "-privkey-path",
            &pkey_path,
        ];

        let output = run_command("docker", &args)?;

        // Extract the full keypair
        let stdout_str = String::from_utf8_lossy(&output.stdout);
        let keypair = stdout_str.replace("libp2p keypair:", "").trim().to_string();
        let keys = NodeKey {
            key_string: keypair,
            key_path: pkey_path,
        };
        debug!("Generated keypair: {:?}", keys);
        Ok(keys)
    }

    // generate libp2p key pairs for multiple services
    pub fn generate_libp2p_key_pairs(
        &self,
        service_names: &[&str],
    ) -> std::io::Result<HashMap<String, NodeKey>> {
        let mut keypairs = HashMap::new();
        for &service_name in service_names {
            let keypair = self.generate_libp2p_key_pair(service_name)?;
            keypairs.insert(service_name.to_string(), keypair);
        }
        Ok(keypairs)
    }
}
