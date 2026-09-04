//! # Genesis Ledger Module
//!
//! This module provides functionalities to generate a default genesis ledger for a given network.
//! The generated ledger contains basic account structures populated with information from provided service keys.
//! It handles the serialization of the ledger to a formatted JSON structure and saves it as `genesis_ledger.json`.

extern crate chrono;
use chrono::prelude::*;

use log::{debug, info};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::prelude::*;
use std::path::Path;

use crate::keys::NodeKey;

pub(crate) const GENESIS_LEDGER_JSON: &str = "genesis_ledger.json";
pub(crate) const REPLAYER_INPUT_JSON: &str = "replayer_input.json";

/// Genesis ledger format
#[derive(Serialize, Deserialize)]
struct GenesisLedger {
    genesis: Genesis,
    ledger: Ledger,
}

#[derive(Serialize, Deserialize)]
struct Genesis {
    genesis_state_timestamp: String,
}

#[derive(Serialize, Deserialize)]
struct Ledger {
    #[serde(skip_serializing_if = "Option::is_none")]
    name: Option<String>,
    accounts: Vec<Account>,
}

#[derive(Serialize, Deserialize)]
struct Account {
    pk: String,
    sk: Option<String>,
    balance: String,
    delegate: Option<String>,
    timing: Option<Timing>,
}

#[derive(Serialize, Deserialize)]
struct Timing {
    initial_minimum_balance: String,
    cliff_time: String,
    cliff_amount: String,
    vesting_period: String,
    vesting_increment: String,
}

/// Replayer input format
#[derive(Serialize, Deserialize)]
struct ReplayerInput {
    start_slot_since_genesis: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    target_epoch_ledgers_state_hash: Option<String>,
    genesis_ledger: ReplayerGensisLedger,
}

#[derive(Serialize, Deserialize)]
struct ReplayerGensisLedger {
    accounts: Vec<Account>,
    add_genesis_winner: bool,
}

pub mod default {

    use super::*;

    pub struct LedgerGenerator;

    impl LedgerGenerator {
        /// Generate default genesis ledger
        pub fn generate(
            network_path: &Path,
            bp_keys: &HashMap<String, NodeKey>,
        ) -> std::io::Result<()> {
            info!("Generating default genesis ledger.");
            let accounts: Vec<Account> = bp_keys
                .values()
                .map(|key_info| Account {
                    pk: key_info.key_string.clone(),
                    sk: None,
                    balance: "11550000.000000000".into(),
                    delegate: None,
                    timing: None,
                })
                .collect();

            let ledger = Ledger {
                name: Some("default_genesis_ledger".into()),
                accounts,
            };

            let genesis = Genesis {
                genesis_state_timestamp: current_timestamp(),
            };

            let genesis_ledger = GenesisLedger { genesis, ledger };

            let content = serde_json::to_string_pretty(&genesis_ledger)?;
            debug!("Generated genesis ledger: {}", content);

            // Construct the path to file
            let path = network_path.to_path_buf();
            let path = path.join(GENESIS_LEDGER_JSON);

            // Write content to the output file.
            let mut file = File::create(path)?;
            file.write_all(content.as_bytes())?;

            Ok(())
        }

        /// Generate replayer input file out of genesis ledger
        pub fn generate_replayer_input(network_path: &Path) -> std::io::Result<()> {
            let genesis_ledger_file = network_path.join(GENESIS_LEDGER_JSON);
            let genesis_ledger = serde_json::from_str::<GenesisLedger>(&std::fs::read_to_string(
                genesis_ledger_file,
            )?)?;

            let accounts = genesis_ledger.ledger.accounts;
            let replayer_input = ReplayerInput {
                start_slot_since_genesis: 0,
                target_epoch_ledgers_state_hash: None,
                genesis_ledger: ReplayerGensisLedger {
                    accounts,
                    add_genesis_winner: true,
                },
            };

            let content = serde_json::to_string_pretty(&replayer_input)?;

            let output_file = network_path.join(REPLAYER_INPUT_JSON);
            let mut file = File::create(output_file)?;
            file.write_all(content.as_bytes())?;

            Ok(())
        }
    }
}

pub fn current_timestamp() -> String {
    let datetime = Local::now();
    datetime.format("%Y-%m-%dT%H:%M:%S%.6f%Z").to_string()
}

pub fn set_slot_since_genesis(network_path: &Path, slot_since_genesis: u64) -> std::io::Result<()> {
    let replayer_input_file = network_path.join(REPLAYER_INPUT_JSON);
    let mut replayer_input =
        serde_json::from_str::<ReplayerInput>(&std::fs::read_to_string(replayer_input_file)?)?;

    replayer_input.start_slot_since_genesis = slot_since_genesis;

    let content = serde_json::to_string_pretty(&replayer_input)?;

    let output_file = network_path.join(REPLAYER_INPUT_JSON);
    let mut file = File::create(output_file)?;
    file.write_all(content.as_bytes())?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use tempdir::TempDir;

    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_generate_default_ledger() {
        let tempdir = TempDir::new("test_generate_default_ledger")
            .expect("Cannot create temporary directory");
        let network_path = tempdir.path();
        let mut bp_keys_map: HashMap<String, NodeKey> = HashMap::new();
        let service_key = NodeKey {
            key_string: "test_key".to_string(),
            key_path: "test_key_path".to_string(),
        };
        bp_keys_map.insert("node0".to_string(), service_key);
        let result = default::LedgerGenerator::generate(network_path, &bp_keys_map);
        println!("{:?}", result);
        assert!(result.is_ok());

        let path = network_path.to_path_buf();
        let path = path.join(GENESIS_LEDGER_JSON);
        assert!(path.exists());
        let content = std::fs::read_to_string(path).unwrap();
        assert!(content.contains("genesis_state_timestamp"));
        assert!(content.contains("ledger"));
        assert!(content.contains("test_key"));
    }

    #[test]
    fn test_generate_replayer_input() {
        let tempdir = TempDir::new("test_generate_replayer_input")
            .expect("Cannot create temporary directory");
        let network_path = tempdir.path();
        let mut bp_keys_map: HashMap<String, NodeKey> = HashMap::new();
        let service_key = NodeKey {
            key_string: "test_key".to_string(),
            key_path: "test_key_path".to_string(),
        };
        bp_keys_map.insert("node0".to_string(), service_key);
        let result = default::LedgerGenerator::generate(network_path, &bp_keys_map);
        println!("{:?}", result);
        assert!(result.is_ok());

        let result = default::LedgerGenerator::generate_replayer_input(network_path);
        println!("{:?}", result);
        assert!(result.is_ok());

        let path = network_path.to_path_buf();
        let path = path.join(REPLAYER_INPUT_JSON);
        assert!(path.exists());
        let content = std::fs::read_to_string(path).unwrap();
        assert!(content.contains("genesis_ledger"));
        assert!(content.contains("test_key"));
        assert!(content.contains("start_slot_since_genesis"));
    }

    #[test]
    fn test_deserialize_genesis_ledger() {
        let genesis_ledger = r#"{
            "genesis": {
              "genesis_state_timestamp": "2023-09-20T17:20:57.897531+02:00"
            },
            "ledger": {
              "name": "default_genesis_ledger",
              "accounts": [
                {
                  "pk": "POTATO",
                  "sk": null,
                  "balance": "11550000.000000000",
                  "delegate": null
                },
                {
                  "pk": "TOMATO",
                  "sk": null,
                  "balance": "11550000.000000000",
                  "delegate": null,
                  "timing": {
                    "initial_minimum_balance": "10000",
                    "cliff_time": "8",
                    "cliff_amount": "0",
                    "vesting_period": "4",
                    "vesting_increment": "5000"
                  }
                }
              ]
            }
          }"#;
        let genesis_ledger: GenesisLedger = serde_json::from_str(genesis_ledger).unwrap();
        assert_eq!(
            genesis_ledger.genesis.genesis_state_timestamp,
            "2023-09-20T17:20:57.897531+02:00"
        );
        assert_eq!(
            genesis_ledger.ledger.name,
            Some("default_genesis_ledger".into())
        );
        assert_eq!(genesis_ledger.ledger.accounts.len(), 2);
        assert_eq!(genesis_ledger.ledger.accounts[0].pk, "POTATO");
        assert_eq!(genesis_ledger.ledger.accounts[1].pk, "TOMATO");
        assert_eq!(
            genesis_ledger.ledger.accounts[1]
                .timing
                .as_ref()
                .unwrap()
                .initial_minimum_balance,
            "10000"
        );
        assert_eq!(
            genesis_ledger.ledger.accounts[1]
                .timing
                .as_ref()
                .unwrap()
                .cliff_time,
            "8"
        );
        assert_eq!(
            genesis_ledger.ledger.accounts[1]
                .timing
                .as_ref()
                .unwrap()
                .cliff_amount,
            "0"
        );
        assert_eq!(
            genesis_ledger.ledger.accounts[1]
                .timing
                .as_ref()
                .unwrap()
                .vesting_period,
            "4"
        );
        assert_eq!(
            genesis_ledger.ledger.accounts[1]
                .timing
                .as_ref()
                .unwrap()
                .vesting_increment,
            "5000"
        );
    }

    #[test]
    fn test_deserialize_replayer_input() {
        let replayer_input = r#"{
            "start_slot_since_genesis": 0,
            "genesis_ledger": {
              "accounts": [
                {
                  "pk": "POTATO",
                  "sk": null,
                  "balance": "11550000.000000000",
                  "delegate": null
                },
                {
                  "pk": "TOMATO",
                  "sk": null,
                  "balance": "11550000.000000000",
                  "delegate": null
                }
              ],
              "add_genesis_winner": true
            }
          }"#;
        let replayer_input: ReplayerInput = serde_json::from_str(replayer_input).unwrap();
        assert_eq!(replayer_input.start_slot_since_genesis, 0);
        assert_eq!(replayer_input.genesis_ledger.accounts.len(), 2);
        assert_eq!(replayer_input.genesis_ledger.accounts[0].pk, "POTATO");
        assert_eq!(replayer_input.genesis_ledger.accounts[1].pk, "TOMATO");
    }

    #[test]
    fn test_set_slot_since_genesis() {
        let tempdir =
            TempDir::new("test_set_slot_since_genesis").expect("Cannot create temporary directory");
        let network_path = tempdir.path();
        let mut bp_keys_map: HashMap<String, NodeKey> = HashMap::new();
        let service_key = NodeKey {
            key_string: "test_key".to_string(),
            key_path: "test_key_path".to_string(),
        };
        bp_keys_map.insert("node0".to_string(), service_key);
        let result = default::LedgerGenerator::generate(network_path, &bp_keys_map);
        println!("{:?}", result);
        assert!(result.is_ok());

        let result = default::LedgerGenerator::generate_replayer_input(network_path);
        println!("{:?}", result);
        assert!(result.is_ok());

        let result = set_slot_since_genesis(network_path, 100);
        println!("{:?}", result);
        assert!(result.is_ok());

        let path = network_path.to_path_buf();
        let path = path.join(REPLAYER_INPUT_JSON);
        assert!(path.exists());
        let content = std::fs::read_to_string(path).unwrap();
        let replayer_input: ReplayerInput = serde_json::from_str(&content).unwrap();

        assert_eq!(replayer_input.start_slot_since_genesis, 100);
    }
}
