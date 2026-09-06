use crate::keys::NodeKey;
use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

fn mina_command_error(mina_bin: &Path, service_name: &str, e: io::Error) -> io::Error {
    if e.kind() == io::ErrorKind::NotFound {
        io::Error::new(
            e.kind(),
            format!(
                "Failed to run '{}': {}. Is mina installed and in your PATH or specified via --bin-path?",
                mina_bin.display(), e
            ),
        )
    } else {
        io::Error::other(format!("Failed to run mina for {}: {}", service_name, e))
    }
}

pub struct NativeKeysManager {
    pub network_path: PathBuf,
    pub bin_path: PathBuf,
}

impl NativeKeysManager {
    pub fn new(network_path: &Path, bin_path: &Path) -> Self {
        NativeKeysManager {
            network_path: network_path.to_path_buf(),
            bin_path: bin_path.to_path_buf(),
        }
    }

    pub fn generate_bp_key_pair(&self, service_name: &str) -> io::Result<NodeKey> {
        let keypair_dir = self.network_path.join("network-keypairs");
        std::fs::create_dir_all(&keypair_dir)?;

        let privkey_path = keypair_dir.join(service_name);
        let mina_bin = self.bin_path.join("mina");
        let output = Command::new(&mina_bin)
            .args([
                "advanced",
                "generate-keypair",
                "-privkey-path",
                privkey_path.to_str().unwrap(),
            ])
            .env("MINA_PRIVKEY_PASS", "naughty blue worm")
            .output()
            .map_err(|e| mina_command_error(&mina_bin, service_name, e))?;

        if !output.status.success() {
            return Err(io::Error::other(format!(
                "Failed to generate bp keypair for {}: {}",
                service_name,
                String::from_utf8_lossy(&output.stderr)
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let public_key = stdout
            .lines()
            .find_map(|line| line.strip_prefix("Public key: "))
            .ok_or_else(|| {
                io::Error::other(format!(
                    "Could not parse public key from output: {}",
                    stdout
                ))
            })?
            .trim()
            .to_string();

        Ok(NodeKey {
            key_string: public_key,
            key_path: format!(
                "{}/network-keypairs/{}",
                self.network_path.display(),
                service_name
            ),
        })
    }

    pub fn generate_bp_key_pairs(
        &self,
        service_names: &[&str],
    ) -> io::Result<HashMap<String, NodeKey>> {
        let mut keys = HashMap::new();
        for name in service_names {
            let key = self.generate_bp_key_pair(name)?;
            keys.insert(name.to_string(), key);
        }
        Ok(keys)
    }

    pub fn generate_libp2p_key_pair(&self, service_name: &str) -> io::Result<NodeKey> {
        let keypair_dir = self.network_path.join("libp2p-keypairs");
        std::fs::create_dir_all(&keypair_dir)?;

        let privkey_path = keypair_dir.join(service_name);
        let mina_bin = self.bin_path.join("mina");
        let output = Command::new(&mina_bin)
            .args([
                "libp2p",
                "generate-keypair",
                "-privkey-path",
                privkey_path.to_str().unwrap(),
            ])
            .env("MINA_LIBP2P_PASS", "naughty blue worm")
            .output()
            .map_err(|e| mina_command_error(&mina_bin, service_name, e))?;

        if !output.status.success() {
            return Err(io::Error::other(format!(
                "Failed to generate libp2p keypair for {}: {}",
                service_name,
                String::from_utf8_lossy(&output.stderr)
            )));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let keypair = stdout
            .lines()
            .find_map(|line| line.strip_prefix("libp2p keypair:"))
            .ok_or_else(|| {
                io::Error::other(format!(
                    "Could not parse libp2p keypair from output: {}",
                    stdout
                ))
            })?
            .trim()
            .to_string();

        Ok(NodeKey {
            key_string: keypair,
            key_path: format!(
                "{}/libp2p-keypairs/{}",
                self.network_path.display(),
                service_name
            ),
        })
    }

    pub fn generate_libp2p_key_pairs(
        &self,
        service_names: &[&str],
    ) -> io::Result<HashMap<String, NodeKey>> {
        let mut keys = HashMap::new();
        for name in service_names {
            let key = self.generate_libp2p_key_pair(name)?;
            keys.insert(name.to_string(), key);
        }
        Ok(keys)
    }
}
