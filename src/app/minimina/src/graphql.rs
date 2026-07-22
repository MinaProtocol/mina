use chrono::{DateTime, NaiveDateTime, Utc};
use log::{info, warn};

use crate::{directory_manager::DirectoryManager, exit_with, output::network, TIMEOUT_IN_SECS};
use std::{
    self,
    io::{Error, ErrorKind, Result},
};

pub struct GraphQl {
    directory_manager: DirectoryManager,
}

impl GraphQl {
    pub fn new(directory_manager: DirectoryManager) -> Self {
        Self { directory_manager }
    }

    pub fn get_endpoint(&self, node_id: &str, network_id: &str) -> Option<String> {
        let nodes = self.directory_manager.get_network_info(network_id);
        match nodes {
            Ok(nodes) => {
                let info = serde_json::from_str::<network::Create>(&nodes).unwrap();
                let node = info.nodes.get(node_id)?;
                let graphql_endpoint = node.graphql_uri.as_ref()?;
                Some(graphql_endpoint.to_string())
            }
            Err(_) => None,
        }
    }

    /// Waits for graphql server to start
    pub fn wait_for_server(&self, gql_ep: &str) -> Result<()> {
        let mut retries = 0;
        let mut graphql_running = false;
        info!("Waiting for graphql to start '{gql_ep}'");
        let client = reqwest::blocking::Client::new();

        while !graphql_running && retries < TIMEOUT_IN_SECS {
            let response = client
                .get(gql_ep)
                .header("Content-Type", "application/json")
                .send();

            if response.is_ok() {
                graphql_running = true;
            } else {
                retries += 1;
                std::thread::sleep(std::time::Duration::from_secs(1));
            }
        }
        if !graphql_running {
            return exit_with(format!(
                "Failed to start graphql '{gql_ep}' within {TIMEOUT_IN_SECS}s",
            ));
        }
        Ok(())
    }

    /// Requests filtered logs via graphql
    pub fn request_filtered_logs(&self, gql_ep: &str) -> Result<()> {
        // Filtered logs request payload
        let query = r#"{
        "query": "mutation MyMutation 
                    { startFilteredLog(filter: [\"21ccae8c619bc2666474085272d5fe1d\", 
                                                \"ef1182dc30f3e0aa9f6bf11c0ab90ba6\",
                                                \"64e2d3e86c37c09b15efdaf7470ce879\",
                                                \"db06cb5030f39e86e84b30d033f3bc5c\", 
                                                \"60076de624bf0c5fc0843b875001cf84\", 
                                                \"27953f46376ba8abc0c61400e2c38f8b\", 
                                                \"b4b5f5b1d1a0c457cbd13a35d1c8b57b\", 
                                                \"0fc65f5594c5e9ee0b6f0ddde747c758\", 
                                                \"b5a89d6d616a35fb6f73d1eaad6b2dbd\", 
                                                \"1c4150aa7058a3058c4d20ae90ff7ec3\", 
                                                \"f7254e63ad51092a0bd3078580ef9ce3\", 
                                                \"74a81f1e2f8d548e4550faa136c68160\", 
                                                \"30fe76cee159ea215fc05549e861501e\"]) }"
    }"#;

        let client = reqwest::blocking::Client::new();
        info!("Sending request to: {gql_ep}");
        let response = client
            .post(gql_ep)
            .header("Content-Type", "application/json")
            .body(query)
            .send();
        if let Err(e) = response {
            return exit_with(format!(
                "Failed to send request to graphql endpoint '{gql_ep}': {e}",
            ));
        }

        // Read the response body
        let response_body = response.unwrap().text();
        if let Err(e) = response_body {
            return exit_with(format!(
                "Failed to read response body from graphql endpoint '{gql_ep}': {e}",
            ));
        }
        info!("Response body: {}", response_body.unwrap());

        Ok(())
    }
}

/// Parse the genesis timestamp string the daemon reports (ISO-8601) into a UTC
/// datetime.
///
/// The daemon reports ISO-8601 with a trailing `Z` for the UTC offset; that is
/// normalized to `+00:00` so it parses as RFC-3339. A timestamp carrying no
/// offset at all is assumed to already be UTC. This is a pure function, factored
/// out so it is testable without a running daemon.
fn parse_genesis_timestamp(s: &str) -> Result<DateTime<Utc>> {
    let normalized = s.replace('Z', "+00:00");

    // Offset-bearing timestamp (the common case: daemon reports "...Z").
    if let Ok(dt) = DateTime::parse_from_rfc3339(&normalized) {
        return Ok(dt.with_timezone(&Utc));
    }

    // Naive timestamp with no offset: assume it is already UTC. Try with and
    // without fractional seconds.
    for fmt in ["%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S"] {
        if let Ok(ndt) = NaiveDateTime::parse_from_str(&normalized, fmt) {
            return Ok(DateTime::from_naive_utc_and_offset(ndt, Utc));
        }
    }

    Err(Error::new(
        ErrorKind::InvalidData,
        format!("genesisTimestamp is not an ISO-8601 timestamp: {s:?}"),
    ))
}

/// Ask a running daemon for the genesis timestamp it is actually using.
///
/// Part of the hardfork readiness gate. POSTs
/// `query { genesisConstants { genesisTimestamp } }` and parses the returned
/// ISO-8601 string into a UTC datetime. The daemon is always queried directly:
/// there is deliberately no static fallback, because the genesis instant in
/// force is only known to the running daemon.
#[allow(dead_code)]
pub fn genesis_timestamp(gql_endpoint: &str) -> Result<DateTime<Utc>> {
    let query = r#"{ "query": "query { genesisConstants { genesisTimestamp } }" }"#;

    let client = reqwest::blocking::Client::new();
    let response = client
        .post(gql_endpoint)
        .header("Content-Type", "application/json")
        .body(query)
        .send()
        .map_err(|e| {
            Error::new(
                ErrorKind::Other,
                format!("Failed to query genesisTimestamp from '{gql_endpoint}': {e}"),
            )
        })?;

    let body = response.text().map_err(|e| {
        Error::new(
            ErrorKind::Other,
            format!("Failed to read genesisTimestamp response from '{gql_endpoint}': {e}"),
        )
    })?;

    let json: serde_json::Value = serde_json::from_str(&body).map_err(|e| {
        Error::new(
            ErrorKind::InvalidData,
            format!("genesisTimestamp response from '{gql_endpoint}' is not JSON: {e}"),
        )
    })?;

    let raw = json["data"]["genesisConstants"]["genesisTimestamp"]
        .as_str()
        .ok_or_else(|| {
            Error::new(
                ErrorKind::InvalidData,
                format!("genesisTimestamp missing from GraphQL response of '{gql_endpoint}'"),
            )
        })?;

    parse_genesis_timestamp(raw)
}

/// Poll until the daemon is both `SYNCED` and past its genesis timestamp.
///
/// Part of the hardfork readiness gate. `SYNCED` alone is reached roughly one
/// genesis-delay *before* the chain starts producing, so this additionally waits
/// for the wall clock to reach the genesis timestamp the daemon reports. This is
/// the stronger readiness check hardfork support needs; it is not yet wired into
/// the network-create flow (a separate ticket).
///
/// Transient GraphQL/HTTP errors during polling are tolerated (logged and
/// retried). Returns an error only if neither condition is met within the
/// overall timeout.
#[allow(dead_code)]
pub fn wait_for_genesis(gql_endpoint: &str) -> Result<()> {
    const INTERVAL_IN_SECS: u64 = 2;
    let mut elapsed = 0u64;
    info!("Waiting for genesis readiness (SYNCED + past genesis) at '{gql_endpoint}'");
    let client = reqwest::blocking::Client::new();

    while u64::from(TIMEOUT_IN_SECS) > elapsed {
        match poll_genesis_ready(&client, gql_endpoint) {
            Ok(true) => {
                info!("Genesis reached at '{gql_endpoint}': daemon SYNCED and past genesis");
                return Ok(());
            }
            Ok(false) => {}
            Err(e) => {
                warn!("Transient error while polling genesis readiness at '{gql_endpoint}': {e}");
            }
        }
        std::thread::sleep(std::time::Duration::from_secs(INTERVAL_IN_SECS));
        elapsed += INTERVAL_IN_SECS;
    }

    exit_with(format!(
        "Genesis not reached at '{gql_endpoint}' within {TIMEOUT_IN_SECS}s \
         (daemon never synced past its genesis timestamp)",
    ))
}

/// One poll of the genesis gate: true iff `syncStatus == "SYNCED"` and the wall
/// clock is at or past the daemon's genesis timestamp.
#[allow(dead_code)]
fn poll_genesis_ready(client: &reqwest::blocking::Client, gql_endpoint: &str) -> Result<bool> {
    let query = r#"{ "query": "query { syncStatus }" }"#;
    let body = client
        .post(gql_endpoint)
        .header("Content-Type", "application/json")
        .body(query)
        .send()
        .and_then(|r| r.text())
        .map_err(|e| Error::new(ErrorKind::Other, format!("syncStatus request failed: {e}")))?;

    let json: serde_json::Value = serde_json::from_str(&body)
        .map_err(|e| Error::new(ErrorKind::InvalidData, format!("syncStatus not JSON: {e}")))?;

    let sync_status = json["data"]["syncStatus"].as_str().ok_or_else(|| {
        Error::new(
            ErrorKind::InvalidData,
            "syncStatus missing from GraphQL response".to_string(),
        )
    })?;

    if sync_status != "SYNCED" {
        return Ok(false);
    }

    Ok(Utc::now() >= genesis_timestamp(gql_endpoint)?)
}

#[cfg(test)]
mod test {
    #[test]
    fn test_get_endpoint() {
        use super::*;
        use crate::directory_manager::DirectoryManager;
        use std::fs::File;
        use std::io::Write;
        use std::path::PathBuf;
        use tempdir::TempDir;

        let tempdir = TempDir::new("test_get_endpoint").expect("Cannot create temporary directory");
        let network_info_str = "{
            \"network_id\": \"test_deserialize\",
            \"nodes\": {
                \"mina-archive\": {
                    \"graphql_uri\": null,
                    \"private_key\": null,
                    \"node_type\": \"Archive_node\"
                },
                \"mina-snark-coordinator\": {
                    \"graphql_uri\": \"http://localhost:7001/graphql\",
                    \"private_key\": null,
                    \"node_type\": \"Snark_coordinator\"
                },
                \"mina-bp-1\": {
                    \"graphql_uri\": \"http://localhost:4001/graphql\",
                    \"private_key\": null,
                    \"node_type\": \"Block_producer\"
                },
                \"mina-bp-2\": {
                    \"graphql_uri\": \"http://localhost:4006/graphql\",
                    \"private_key\": null,
                    \"node_type\": \"Block_producer\"
                },
                \"mina-seed-1\": {
                    \"graphql_uri\": \"http://localhost:3101/graphql\",
                    \"private_key\": null,
                    \"node_type\": \"Seed_node\"
                },
                \"mina-snark-worker-1\": {
                    \"graphql_uri\": null,
                    \"private_key\": null,
                    \"node_type\": \"Snark_worker\"
                }
            }
        }";
        let base_path = PathBuf::from(tempdir.path());
        let network_id = "test_deserialize";
        let directory_manager = DirectoryManager::_new_with_base_path(base_path);
        directory_manager
            .create_network_directory(network_id)
            .unwrap();
        let network_info_file = directory_manager.network_file_path(network_id);
        let mut file = File::create(network_info_file).unwrap();
        file.write_all(network_info_str.as_bytes()).unwrap();

        let graphql = GraphQl::new(directory_manager);

        let endpoint = graphql.get_endpoint("mina-bp-1", network_id).unwrap();
        assert_eq!(endpoint, "http://localhost:4001/graphql");

        let endpoint = graphql.get_endpoint("mina-bp-2", network_id).unwrap();
        assert_eq!(endpoint, "http://localhost:4006/graphql");

        let endpoint = graphql.get_endpoint("mina-snark-worker-1", network_id);
        assert_eq!(endpoint, None);
    }

    #[test]
    fn test_parse_genesis_timestamp_z_suffix() {
        use super::parse_genesis_timestamp;
        use chrono::{TimeZone, Utc};

        let parsed = parse_genesis_timestamp("2024-01-02T03:04:05Z").unwrap();
        assert_eq!(parsed, Utc.with_ymd_and_hms(2024, 1, 2, 3, 4, 5).unwrap());
    }

    #[test]
    fn test_parse_genesis_timestamp_explicit_offset() {
        use super::parse_genesis_timestamp;
        use chrono::{TimeZone, Utc};

        // +00:00 offset should be equivalent to the Z-suffixed form.
        let parsed = parse_genesis_timestamp("2024-01-02T03:04:05+00:00").unwrap();
        assert_eq!(parsed, Utc.with_ymd_and_hms(2024, 1, 2, 3, 4, 5).unwrap());

        // A non-zero offset must be normalized back to UTC.
        let parsed = parse_genesis_timestamp("2024-01-02T05:04:05+02:00").unwrap();
        assert_eq!(parsed, Utc.with_ymd_and_hms(2024, 1, 2, 3, 4, 5).unwrap());
    }

    #[test]
    fn test_parse_genesis_timestamp_naive_assumed_utc() {
        use super::parse_genesis_timestamp;
        use chrono::{TimeZone, Utc};

        // No offset at all: assumed to already be UTC.
        let parsed = parse_genesis_timestamp("2024-01-02T03:04:05").unwrap();
        assert_eq!(parsed, Utc.with_ymd_and_hms(2024, 1, 2, 3, 4, 5).unwrap());
    }

    #[test]
    fn test_parse_genesis_timestamp_invalid() {
        use super::parse_genesis_timestamp;

        assert!(parse_genesis_timestamp("not-a-timestamp").is_err());
    }
}
