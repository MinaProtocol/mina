//! # DirectoryManager Module
//!
//! This module provides functionalities related to managing directories for the local network.
//! The directory structure will be placed in the user's home directory under `~/.minimina/{network_id}`.
//! The directory structure will contain the following subdirectories and files:
//! - `network-keypairs`: Contains the key pairs for the block producer service.
//! - `libp2p-keypairs`: Contains the key pairs for the libp2p service.
//! - `genesis_ledger.json`: Contains the genesis ledger for the network.
//! - `docker-compose.yml`: Contains the docker compose file for the network.
//! - `network.json`: Contains the network topology representation in JSON format.
//! - `peer_list_file.txt`: Contains the list of libp2p peers for the network.

use crate::genesis_ledger::GENESIS_LEDGER_JSON;
use crate::output;
use crate::service::ServiceConfig;
use dirs::home_dir;
use log::{debug, info};
use std::env;
use std::os::unix::fs::PermissionsExt;
use std::{
    fs,
    io::Result,
    path::{Path, PathBuf},
};

pub const NETWORK_KEYPAIRS: &str = "network-keypairs";
const LIBP2P_KEYPAIRS: &str = "libp2p-keypairs";
const MINIMINA_HOME: &str = "MINIMINA_HOME";

#[derive(Clone)]
pub struct DirectoryManager {
    pub base_path: PathBuf,
    pub subdirectories: [&'static str; 2],
}

impl DirectoryManager {
    pub fn new() -> Self {
        let mut base_path = if let Ok(env_path) = env::var(MINIMINA_HOME) {
            PathBuf::from(env_path)
        } else {
            home_dir().expect("Home directory not found")
        };
        base_path.push(".minimina");
        DirectoryManager {
            base_path,
            subdirectories: Self::subdirectories(),
        }
    }

    // for testing purposes
    pub fn _new_with_base_path(base_path: PathBuf) -> Self {
        DirectoryManager {
            base_path,
            subdirectories: Self::subdirectories(),
        }
    }

    pub fn _base_path(&self) -> &PathBuf {
        &self.base_path
    }

    // return path to network directory
    pub fn network_path(&self, network_id: &str) -> PathBuf {
        let network_path = self.base_path.clone();
        network_path.join(network_id)
    }

    // list of all subdirectories that needs to be created for the network
    fn subdirectories() -> [&'static str; 2] {
        [NETWORK_KEYPAIRS, LIBP2P_KEYPAIRS]
    }

    pub fn generate_dir_structure(&self, network_id: &str) -> Result<PathBuf> {
        info!(
            "Creating directory structure for network-id '{}'",
            network_id
        );
        self.create_network_directory(network_id)?;
        self.create_subdirectories(network_id)?;
        self.set_subdirectories_permissions(network_id, 0o700)?;
        let np = self.network_path(network_id);
        Ok(np)
    }

    // return paths to all subdirectories for given network
    fn subdirectories_paths(&self, network_id: &str) -> Vec<PathBuf> {
        let mut subdirectories_paths = vec![];
        for subdirectory in &self.subdirectories {
            let mut subdirectory_path = self.base_path.clone();
            subdirectory_path.push(network_id);
            subdirectory_path.push(subdirectory);
            subdirectories_paths.push(subdirectory_path);
        }
        subdirectories_paths
    }

    pub fn network_path_exists(&self, network_id: &str) -> bool {
        let network_path = self.network_path(network_id);
        network_path.exists()
    }

    pub fn create_network_directory(&self, network_id: &str) -> Result<()> {
        let network_path = self.network_path(network_id);
        fs::create_dir_all(network_path)
    }

    pub fn delete_network_directory(&self, network_id: &str) -> Result<()> {
        let network_path = self.network_path(network_id);
        fs::remove_dir_all(network_path)
    }

    pub fn list_network_directories(&self) -> Result<Vec<String>> {
        let mut networks = vec![];
        for entry in fs::read_dir(&self.base_path)? {
            let entry = entry?;
            if entry.file_type()?.is_dir() {
                if let Some(network_id) = entry.file_name().to_str() {
                    networks.push(network_id.to_string());
                }
            }
        }
        Ok(networks)
    }

    pub fn get_network_keypair_files(&self, network_id: &str) -> Result<Vec<String>> {
        self.get_files_in_network_subdir(network_id, NETWORK_KEYPAIRS, Some(".pub"))
    }

    pub fn _get_libp2p_keypair_files(&self, network_id: &str) -> Result<Vec<String>> {
        self.get_files_in_network_subdir(network_id, LIBP2P_KEYPAIRS, Some(".peerid"))
    }

    fn get_files_in_network_subdir(
        &self,
        network_id: &str,
        subdir: &str,
        not_containing: Option<&str>,
    ) -> Result<Vec<String>> {
        let path = self.network_path(network_id).join(subdir);
        let mut files = vec![];
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            if entry.file_type()?.is_file() {
                if let Some(file_name) = entry.file_name().to_str() {
                    if let Some(sub_str) = not_containing {
                        if !file_name.contains(sub_str) {
                            files.push(file_name.to_string());
                        }
                    } else {
                        files.push(file_name.to_string());
                    }
                }
            }
        }

        Ok(files)
    }

    fn create_subdirectories(&self, network_id: &str) -> Result<()> {
        for subdirectory in self.subdirectories_paths(network_id) {
            fs::create_dir_all(subdirectory)?;
        }
        Ok(())
    }

    fn set_subdirectories_permissions(&self, network_id: &str, mode: u32) -> Result<()> {
        for subdirectory in self.subdirectories_paths(network_id) {
            fs::set_permissions(subdirectory, fs::Permissions::from_mode(mode))?;
        }
        Ok(())
    }

    /// Copies all network and libp2p keypairs from service paths to the appropriate
    /// network subdirectories and sets permissions
    pub fn copy_all_network_keys(
        &self,
        network_id: &str,
        services: &Vec<ServiceConfig>,
    ) -> Result<()> {
        let network_keys = self.network_path(network_id).join(self.subdirectories[0]);
        let libp2p_keys = self.network_path(network_id).join(self.subdirectories[1]);

        for service in services {
            // copy network keypairs + permissions
            if let Some(network_key_path) = &service.private_key_path {
                let service_network_key = network_keys
                    .clone()
                    .join(format!("{}.json", &service.service_name));

                fs::copy(network_key_path, &service_network_key)?;
                set_key_file_permissions(&service_network_key)?;
            }

            // copy libp2p keypairs + permissions
            if let Some(libp2p_key_path) = &service.libp2p_keypair_path {
                let service_libp2p_key = libp2p_keys
                    .clone()
                    .join(format!("{}.json", &service.service_name));

                fs::copy(libp2p_key_path, &service_libp2p_key)?;
                set_key_file_permissions(&service_libp2p_key)?;
            }
        }

        Ok(())
    }

    pub fn copy_uptime_service_config(
        &self,
        network_id: &str,
        service: &ServiceConfig,
    ) -> Result<()> {
        info!("Copying uptime service config for {}", service.service_name);
        let uptime_service_config_path =
            self.network_path(network_id).join("uptime_service_config");
        fs::create_dir_all(&uptime_service_config_path)?;
        if let Some(uptime_service_backend_app_config) = &service.uptime_service_backend_app_config
        {
            let dest_path = uptime_service_config_path.join(
                uptime_service_backend_app_config
                    .file_name()
                    .expect("Failed to extract filename from source path"),
            );
            debug!(
                "Copying uptime service backend from {:?} app config to {:?}",
                uptime_service_backend_app_config, dest_path
            );
            fs::copy(uptime_service_backend_app_config, dest_path)?;
        }
        if let Some(uptime_service_backend_minasheets) = &service.uptime_service_backend_minasheets
        {
            let dest_path = uptime_service_config_path.join(
                uptime_service_backend_minasheets
                    .file_name()
                    .expect("Failed to extract filename from source path"),
            );
            debug!(
                "Copying uptime service backend from {:?} app config to {:?}",
                uptime_service_backend_minasheets, dest_path
            );
            fs::copy(uptime_service_backend_minasheets, dest_path)?;
        }
        if let Some(other_files) = &service.uptime_service_other_config_files {
            for file in other_files {
                let dest_path = uptime_service_config_path.join(
                    file.file_name()
                        .expect("Failed to extract filename from source path"),
                );
                debug!(
                    "Copying uptime service backend from {:?} app config to {:?}",
                    file, dest_path
                );
                fs::copy(file, dest_path)?;
            }
        }

        Ok(())
    }

    pub fn peer_list_file(&self, network_id: &str) -> PathBuf {
        self.network_path(network_id).join("peer_list_file.txt")
    }

    pub fn create_peer_list_file(&self, network_id: &str, peers: &[&ServiceConfig]) -> Result<()> {
        use std::io::Write;

        let peer_list_path = self.peer_list_file(network_id);
        let mut file = fs::File::create(peer_list_path)?;

        for peer in peers {
            let peer_hostname = format!("{}-{}", peer.service_name, network_id);
            let external_port = peer.client_port.unwrap() + 2;
            let libp2p_key = peer.libp2p_peerid.clone().unwrap();
            writeln!(
                file,
                "/dns4/{}/tcp/{}/p2p/{}",
                peer_hostname, external_port, libp2p_key
            )?;
        }

        Ok(())
    }

    /// Checks whether the genesis timestamp is too far in the past.
    pub fn check_genesis_timestamp(&self, network_id: &str) -> Result<()> {
        use chrono::{prelude::*, Duration};

        let network_path = self.network_path(network_id);
        let genesis_ledger_path = network_path.join(GENESIS_LEDGER_JSON);
        let contents = fs::read_to_string(genesis_ledger_path)?;
        let json: serde_json::Value = serde_json::from_str(&contents)?;
        let genesis = json
            .get("genesis")
            .expect("'genesis' field should be present in genesis ledger");
        let genesis_timestamp = DateTime::parse_from_rfc3339(
            genesis
                .get("genesis_state_timestamp")
                .expect("'genesis_state_timestamp' should be a field in 'genesis' object")
                .as_str()
                .unwrap(),
        )
        .unwrap();

        // use k genesis parameter to calculate cutoff time
        // in case k is not present, use default value of 20
        let k = match genesis.get("k") {
            Some(k) => k.to_string().parse::<u32>().unwrap(),
            None => 20_u32,
        };
        let cutoff = Local::now()
            .checked_sub_signed(Duration::minutes((k / 2 * 3) as i64))
            .unwrap();

        // if we're outside of the first half of the first transition frontier,
        // we throw an error
        if cutoff > genesis_timestamp {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("Genesis timestamp '{genesis_timestamp}' may be outdated."),
            ));
        }

        Ok(())
    }

    /// Copies the genesis ledger at `genesis_ledger_path` to the network directory
    pub fn copy_genesis_ledger(&self, network_id: &str, genesis_ledger_path: &Path) -> Result<()> {
        let network_genesis_path = self.genesis_ledger_path(network_id);
        fs::copy(genesis_ledger_path, network_genesis_path).map(|_| ())
    }

    pub fn overwrite_genesis_timestamp(
        &self,
        network_id: &str,
        genesis_ledger_path: &Path,
    ) -> Result<()> {
        use crate::genesis_ledger::current_timestamp;
        use fs::{read_to_string, write};

        let contents = read_to_string(genesis_ledger_path)?;
        let mut ledger: serde_json::Value = serde_json::from_str(&contents)?;
        let genesis = ledger.get_mut("genesis").unwrap();
        let timestamp = genesis.get_mut("genesis_state_timestamp").unwrap();

        *timestamp = serde_json::Value::String(current_timestamp());

        let contents = serde_json::to_string_pretty(&ledger)?;
        write(self.genesis_ledger_path(network_id), contents)
    }

    /// Returns the genesis ledger path for the given network
    pub fn genesis_ledger_path(&self, network_id: &str) -> PathBuf {
        self.network_path(network_id).join(GENESIS_LEDGER_JSON)
    }

    /// Returns the network file path for the given network
    pub fn network_file_path(&self, network_id: &str) -> PathBuf {
        self.network_path(network_id).join("network.json")
    }

    pub fn save_network_info(&self, network_id: &str, services: &[ServiceConfig]) -> Result<()> {
        let network_file_path = self.network_file_path(network_id);
        let contents = format!("{}", output::generate_network_info(services, network_id));
        fs::write(network_file_path, contents)
    }

    pub fn get_network_info(&self, network_id: &str) -> Result<String> {
        let network_file_path = self.network_file_path(network_id);
        fs::read_to_string(network_file_path)
    }

    /// Returns the services file path for the given network
    pub fn services_file_path(&self, network_id: &str) -> PathBuf {
        self.network_path(network_id).join("services.json")
    }

    pub fn save_services_info(&self, network_id: &str, services: &[ServiceConfig]) -> Result<()> {
        let services_file_path = self.services_file_path(network_id);
        let contents = serde_json::to_string_pretty(services)?;
        fs::write(services_file_path, contents)
    }

    pub fn get_services_info(&self, network_id: &str) -> Result<Vec<ServiceConfig>> {
        let services_file_path = self.services_file_path(network_id);
        let contents = fs::read_to_string(services_file_path)?;
        let services: Vec<ServiceConfig> = serde_json::from_str(&contents)?;
        Ok(services)
    }

    /// Returns the topology file path for the given network
    pub fn topology_file_path(&self, network_id: &str) -> PathBuf {
        self.network_path(network_id).join("topology.json")
    }
}

fn set_key_file_permissions(file: &Path) -> Result<()> {
    fs::set_permissions(file, fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use tempdir::TempDir;

    use super::*;

    #[test]
    fn test_create_and_delete_network_directory() {
        let tempdir = TempDir::new("test_create_and_delete_network_directory")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.to_path_buf());
        let network_id = "test_network";

        // Create the network directory
        dir_manager.create_network_directory(network_id).unwrap();
        let network_path = dir_manager.network_path(network_id);
        assert!(network_path.exists());

        // Delete the network directory
        dir_manager.delete_network_directory(network_id).unwrap();
        assert!(!network_path.exists());
    }

    #[test]
    fn test_create_subdirectories() {
        let tempdir =
            TempDir::new("test_create_subdirectories").expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.to_path_buf());
        let network_id = "test_network";
        let subdirectories = dir_manager.subdirectories;

        // Create the network and subdirectories
        dir_manager.create_network_directory(network_id).unwrap();
        dir_manager.create_subdirectories(network_id).unwrap();

        for subdir in &subdirectories {
            let mut subdir_path = dir_manager._base_path().clone();
            subdir_path.push(network_id);
            subdir_path.push(subdir);
            assert!(subdir_path.exists());
        }

        // Clean up
        dir_manager.delete_network_directory(network_id).unwrap();
    }

    #[test]
    fn test_list_networks() {
        let tempdir =
            TempDir::new("test_list_networks").expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.to_path_buf());

        let network_ids = ["test_network1", "test_network2"];

        // Create some network directories
        for network_id in &network_ids {
            dir_manager.create_network_directory(network_id).unwrap();
        }

        // Check that all network directories are listed
        let listed_networks = dir_manager.list_network_directories().unwrap();
        for network_id in &network_ids {
            assert!(listed_networks.contains(&network_id.to_string()));
        }

        // Clean up
        for network_id in &network_ids {
            dir_manager.delete_network_directory(network_id).unwrap();
        }
    }

    #[test]
    fn test_chmod_network_subdirectories() {
        let tempdir = TempDir::new("test_chmod_network_subdirectories")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.to_path_buf());
        let network_id = "test_network";
        let subdirectories = dir_manager.subdirectories;

        // Create the network and subdirectories
        dir_manager.create_network_directory(network_id).unwrap();
        dir_manager.create_subdirectories(network_id).unwrap();
        // Set readonly permissions
        dir_manager
            .set_subdirectories_permissions(network_id, 0o444)
            .unwrap();

        // Check that the subdirectories have readonly permissions
        for subdir in &subdirectories {
            let mut subdir_path = dir_manager._base_path().clone();
            subdir_path.push(network_id);
            subdir_path.push(subdir);
            let metadata = fs::metadata(subdir_path).unwrap();
            assert!(metadata.permissions().readonly());
        }

        // Clean up
        dir_manager.delete_network_directory(network_id).unwrap();
    }

    #[test]
    fn test_network_subdirectories_paths() {
        let tempdir = TempDir::new("test_network_subdirectories_paths")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.to_path_buf());
        let network_id = "test_network";
        let subdirectories = dir_manager.subdirectories;
        let paths = dir_manager.subdirectories_paths(network_id);

        for (path, subdir) in paths.iter().zip(&subdirectories) {
            let mut subdir_path = dir_manager._base_path().clone();
            subdir_path.push(network_id);
            subdir_path.push(subdir);
            assert_eq!(path, &subdir_path);
        }
    }

    #[test]
    fn test_check_genesis_timestamp() -> Result<()> {
        use chrono::{prelude::*, Duration};
        let tempdir = TempDir::new("test_network_subdirectories_paths")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let network_id = "test_network";
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.into());
        let genesis_ledger_path = dir_manager
            .network_path(network_id)
            .join(GENESIS_LEDGER_JSON);
        fs::create_dir_all(PathBuf::from(base_path).join(network_id))?;

        let k = 20;
        let now = Local::now();
        let old_time = now
            .checked_sub_signed(Duration::minutes(k / 2 * 3 + 1))
            .unwrap()
            .format("%Y-%m-%dT%H:%M:%S%.6f%Z");
        let recent_time = now
            .checked_sub_signed(Duration::minutes(k / 2 * 3 - 1))
            .unwrap()
            .format("%Y-%m-%dT%H:%M:%S%.6f%Z");

        let old_genesis = format!(
            "{{
                \"genesis\": {{
                    \"k\": {k},
                    \"genesis_state_timestamp\": \"{old_time}\"
                }}
            }}"
        );
        let recent_genesis = format!(
            "{{
                \"genesis\": {{
                    \"k\": {k},
                    \"genesis_state_timestamp\": \"{recent_time}\"
                }}
            }}",
        );

        println!("Old:    {old_time}");
        println!("Recent: {recent_time}");

        // genesis ledger is too old so the timestamp will be overwritten
        fs::write(genesis_ledger_path.clone(), old_genesis.clone())?;
        assert!(dir_manager.check_genesis_timestamp(network_id).is_err());

        // genesis ledger is recent enough so the timestamp will not be overwritten
        fs::write(genesis_ledger_path.clone(), recent_genesis.clone())?;
        assert!(dir_manager.check_genesis_timestamp(network_id).is_ok());

        dir_manager.delete_network_directory(network_id)?;

        Ok(())
    }

    #[test]
    fn test_get_files_in_network_subdir() {
        let tempdir = TempDir::new("test_get_files_in_network_subdir")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let network_id = "test_network";
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.into());
        let subdir = "test_subdir";
        let file1 = "test_file1";
        let file2 = "test_file2.peerid";

        // Create the network and subdirectories
        dir_manager.create_network_directory(network_id).unwrap();
        let subdir_path = dir_manager.network_path(network_id).join(subdir);

        //Create the subdirectory
        fs::create_dir_all(&subdir_path).unwrap();

        // Create the files
        fs::File::create(subdir_path.join(file1)).unwrap();
        fs::File::create(subdir_path.join(file2)).unwrap();

        // Check that the files are listed
        let files = dir_manager
            .get_files_in_network_subdir(network_id, subdir, None)
            .unwrap();
        assert!(files.contains(&file1.to_string()));
        assert!(files.contains(&file2.to_string()));

        // Check that the files are listed with filter not_containing
        let files = dir_manager
            .get_files_in_network_subdir(network_id, subdir, Some("peerid"))
            .unwrap();
        assert!(files.contains(&file1.to_string()));
        assert!(!files.contains(&file2.to_string()));
    }

    #[test]
    fn test_save_network_info() {
        let tempdir =
            TempDir::new("test_save_network_info").expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let network_id = "test_network";
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.into());
        let services = vec![
            ServiceConfig {
                service_name: "test_service1".to_string(),
                ..Default::default()
            },
            ServiceConfig {
                service_name: "test_service2".to_string(),
                ..Default::default()
            },
        ];

        // Create the network and subdirectories
        dir_manager.create_network_directory(network_id).unwrap();

        // Save the network info
        dir_manager
            .save_network_info(network_id, &services)
            .unwrap();

        // Check that the network info is saved
        let network_info = dir_manager.get_network_info(network_id).unwrap();
        assert!(network_info.contains("test_service1"));
        assert!(network_info.contains("test_service2"));

        // Clean up
        dir_manager.delete_network_directory(network_id).unwrap();
    }

    #[test]
    fn test_save_services_info() {
        let tempdir =
            TempDir::new("test_save_services_info").expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let network_id = "test_network";
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.into());
        let services = vec![
            ServiceConfig {
                service_name: "test_service1".to_string(),
                ..Default::default()
            },
            ServiceConfig {
                service_name: "test_service2".to_string(),
                ..Default::default()
            },
        ];

        // Create the network and subdirectories
        dir_manager.create_network_directory(network_id).unwrap();

        // Save the services info
        dir_manager
            .save_services_info(network_id, &services)
            .unwrap();

        // Check that the services info is saved
        let services_info = dir_manager.get_services_info(network_id).unwrap();
        assert_eq!(services_info.len(), 2);
        assert_eq!(services_info[0].service_name, "test_service1");
        assert_eq!(services_info[1].service_name, "test_service2");

        // Clean up
        dir_manager.delete_network_directory(network_id).unwrap();
    }

    #[test]
    fn test_copy_uptime_service_config() {
        let tempdir = TempDir::new("test_copy_uptime_service_config")
            .expect("Cannot create temporary directory");
        let base_path = tempdir.path();
        let network_id = "test_network";
        let dir_manager = DirectoryManager::_new_with_base_path(base_path.into());
        let services = vec![ServiceConfig {
            service_name: "test_service1".to_string(),
            service_type: crate::service::ServiceType::UptimeServiceBackend,
            uptime_service_backend_app_config: Some(PathBuf::from(
                "./tests/data/uptime_service_network/uptime_service_config_test/app_config.json",
            )),
            uptime_service_backend_minasheets: Some(PathBuf::from(
                "./tests/data/uptime_service_network/uptime_service_config_test/minasheets.json",
            )),
            ..Default::default()
        }];
        let uptime_service = ServiceConfig::get_uptime_service_backend(&services).unwrap();
        dir_manager.create_network_directory(network_id).unwrap();
        let res = dir_manager.copy_uptime_service_config(network_id, uptime_service);
        assert!(res.is_ok());
        assert!(dir_manager
            .network_path(network_id)
            .join("uptime_service_config")
            .exists());
        assert!(dir_manager
            .network_path(network_id)
            .join("uptime_service_config")
            .join("app_config.json")
            .exists());
        assert!(dir_manager
            .network_path(network_id)
            .join("uptime_service_config")
            .join("minasheets.json")
            .exists());
        dir_manager.delete_network_directory(network_id).unwrap();
    }
}
