mod cli;
mod directory_manager;
mod docker;
mod genesis_ledger;
mod graphql;
mod keys;
mod native;
mod output;
mod service;
mod topology;
mod utils;

use crate::{
    genesis_ledger::*,
    keys::{KeysManager, NodeKey},
    native::{keys::NativeKeysManager, manager::NativeManager},
    output::{network, node},
    service::{ServiceConfig, ServiceType},
    utils::fetch_schema,
};
use clap::Parser;
use cli::{
    Cli, Command, CommandWithNetworkId, CommandWithNodeId, DefaultLogLevel, ExecutionMode,
    NetworkCommand, NodeCommand,
};
use directory_manager::DirectoryManager;
use docker::manager::{ContainerState, DockerManager};
use env_logger::{Builder, Env};
use graphql::GraphQl;
use log::{error, info, warn};
use std::{
    collections::HashMap,
    io::{Error, ErrorKind, Result},
    path::Path,
    process::exit,
};

// The least supported version of docker compose
const LEAST_COMPOSE_VERSION: &str = "2.21.0";

// Hardcoded daemon image for default network
const DEFAULT_DAEMON_DOCKER_IMAGE: &str =
    "gcr.io/o1labs-192920/mina-daemon:2.0.0berkeley-rc1-1551e2f-bullseye-berkeley";

// Hardcoded archive image for default network
const DEFAULT_ARCHIVE_DOCKER_IMAGE: &str =
    "gcr.io/o1labs-192920/mina-archive:2.0.0berkeley-rc1-1551e2f-bullseye";

const IMAGE_COMMIT_HASH: &str = "1551e2f";

// Timeout in seconds for waiting operations
const TIMEOUT_IN_SECS: u16 = 180;

fn main() -> Result<()> {
    let cli: Cli = Cli::parse();
    Builder::from_env(Env::default().default_filter_or(cli.command.log_level())).init();

    let directory_manager = DirectoryManager::new();
    let mode = cli.mode;
    let bin_path = cli.bin_path;

    check_execution_environment(&mode, &bin_path)?;

    match cli.command {
        Command::Network(net_cmd) => match net_cmd {
            NetworkCommand::Create(cmd) => {
                let network_id = cmd.network_id().to_string();
                let network_path = directory_manager.network_path(&network_id);
                let docker = DockerManager::new(&network_path);

                check_setup_network(&docker, &directory_manager, &network_id)?;

                // key-pairs for block producers and libp2p keys for all services
                // for default network (not topology based)
                let mut bp_keys_opt: Option<HashMap<String, NodeKey>> = None;
                let mut libp2p_keys_opt: Option<HashMap<String, NodeKey>> = None;

                // consume the genesis ledger
                handle_genesis_ledger(
                    &cmd,
                    &directory_manager,
                    &network_id,
                    &mut bp_keys_opt,
                    &mut libp2p_keys_opt,
                    &mode,
                    &bin_path,
                )?;

                // build services from topology file
                let services = handle_topology(
                    &cmd,
                    &directory_manager,
                    &network_id,
                    bp_keys_opt,
                    libp2p_keys_opt,
                )?;

                // copy libp2p + network keys
                if let Err(e) = directory_manager.copy_all_network_keys(&network_id, &services) {
                    return exit_with(format!("Failed to copy keys with error: {e}"));
                }

                match mode {
                    ExecutionMode::Docker => {
                        // generate docker compose
                        if let Err(e) = docker.compose_generate_file(&services) {
                            return exit_with(format!(
                                "Failed to generate docker-compose.yaml with error: {e}"
                            ));
                        }
                        create_network(&docker, &directory_manager, &network_id, &services)
                    }
                    ExecutionMode::Native => {
                        let native = NativeManager::new(&network_path, &bin_path);
                        if let Err(e) = native.generate_config(&services) {
                            return exit_with(format!(
                                "Failed to generate native config with error: {e}"
                            ));
                        }
                        create_network_native(&native, &directory_manager, &network_id, &services)
                    }
                }
            }

            NetworkCommand::Info(cmd) => {
                let network_id = cmd.network_id;
                check_network_exists(&network_id)?;

                match directory_manager.get_network_info(&network_id) {
                    Ok(json_data) => {
                        println!("{json_data}");
                        Ok(())
                    }
                    Err(e) => {
                        let error_message = format!(
                            "Failed to get info for network '{network_id}' with error: {e}"
                        );
                        exit_with(error_message)
                    }
                }
            }

            NetworkCommand::Status(cmd) => {
                let network_id = cmd.network_id;
                let network_path = directory_manager.network_path(&network_id);
                check_network_exists(&network_id)?;

                let docker = DockerManager::new(&network_path);
                let ls_out = match docker.compose_ls() {
                    Ok(out) => out,
                    Err(e) => {
                        let error_message = format!(
                            "Failed to get status from docker compose ls for network '{network_id}': {e}."
                        );
                        return exit_with(error_message);
                    }
                };

                let ps_out = match docker.compose_ps(None) {
                    Ok(out) => out,
                    Err(e) => {
                        let error_message = format!(
                            "Failed to get status from docker compose ps for network '{network_id}': {e}."
                        );
                        return exit_with(error_message);
                    }
                };

                let compose_file_path = docker.compose_path.to_str().unwrap();
                let mut status = network::Status::new(&network_id);
                status.update_from_compose_ls(ls_out, compose_file_path);
                status.update_from_compose_ps(ps_out);
                status.network_dir = network_path.into_os_string().into_string().unwrap();

                println!("{status}");
                Ok(())
            }

            NetworkCommand::Delete(cmd) => {
                let network_id = cmd.network_id;
                check_network_exists(&network_id)?;

                let network_path = directory_manager.network_path(&network_id);

                // Stop processes/containers first
                match mode {
                    ExecutionMode::Docker => {
                        let docker = DockerManager::new(&network_path);
                        if let Err(e) = docker.compose_down(None, true, true) {
                            let error_message =
                                format!("Failed to delete network '{network_id}': {e}");
                            return exit_with(error_message);
                        }
                    }
                    ExecutionMode::Native => {
                        let native = NativeManager::new(&network_path, &bin_path);
                        if let Err(e) = native.destroy() {
                            let error_message =
                                format!("Failed to delete network '{network_id}': {e}");
                            return exit_with(error_message);
                        }
                    }
                }

                match directory_manager.delete_network_directory(&network_id) {
                    Ok(_) => {
                        println!("{}", network::Delete { network_id });
                        Ok(())
                    }
                    Err(e) => {
                        let error_message =
                            format!("Failed to delete network directory for '{network_id}': {e}");
                        exit_with(error_message)
                    }
                }
            }

            NetworkCommand::List => {
                let networks = directory_manager
                    .list_network_directories()
                    .expect("Failed to list networks");
                let mut list = network::List::new();

                if networks.is_empty() {
                    println!("{list}");
                } else {
                    list.update(
                        networks,
                        directory_manager.base_path.as_path().to_str().unwrap(),
                    );
                    println!("{list}");
                }

                Ok(())
            }

            NetworkCommand::Start(cmd) => {
                let network_id = cmd.network_id().to_string();
                let network_path = directory_manager.network_path(&network_id);

                check_network_exists(&network_id)?;
                if let Err(e) = directory_manager.check_genesis_timestamp(&network_id) {
                    warn!("{e} In case network is unstable consider updating by running 'network create' again.");
                }

                match mode {
                    ExecutionMode::Docker => {
                        let docker = DockerManager::new(&network_path);
                        match docker.compose_start_all() {
                            Ok(output) => {
                                if cmd.verbose {
                                    println!("Status: {}", output.status);
                                    println!("Stdout: {}", String::from_utf8_lossy(&output.stdout));
                                    println!("Stderr: {}", String::from_utf8_lossy(&output.stderr));
                                }
                                println!("{}", network::Start { network_id });
                                Ok(())
                            }
                            Err(e) => {
                                let error_message =
                                    format!("Failed to start network '{network_id}': {e}");
                                exit_with(error_message)
                            }
                        }
                    }
                    ExecutionMode::Native => {
                        let native = NativeManager::new(&network_path, &bin_path);
                        let services = directory_manager.get_services_info(&network_id)?;
                        match native.start_all(&services, &network_id) {
                            Ok(_) => {
                                println!("{}", network::Start { network_id });
                                Ok(())
                            }
                            Err(e) => {
                                let error_message =
                                    format!("Failed to start network '{network_id}': {e}");
                                exit_with(error_message)
                            }
                        }
                    }
                }
            }

            NetworkCommand::Stop(cmd) => {
                let network_id = cmd.network_id;
                check_network_exists(&network_id)?;

                let network_path = directory_manager.network_path(&network_id);

                match mode {
                    ExecutionMode::Docker => {
                        let docker = DockerManager::new(&network_path);
                        match docker.compose_stop_all() {
                            Ok(_) => {
                                println!("{}", network::Stop { network_id });
                                Ok(())
                            }
                            Err(e) => {
                                let error_message =
                                    format!("Failed to stop network '{network_id}': {e}");
                                exit_with(error_message)
                            }
                        }
                    }
                    ExecutionMode::Native => {
                        let native = NativeManager::new(&network_path, &bin_path);
                        match native.stop_all() {
                            Ok(_) => {
                                println!("{}", network::Stop { network_id });
                                Ok(())
                            }
                            Err(e) => {
                                let error_message =
                                    format!("Failed to stop network '{network_id}': {e}");
                                exit_with(error_message)
                            }
                        }
                    }
                }
            }
        },

        Command::Node(node_cmd) => match node_cmd {
            NodeCommand::Start(cmd) => {
                let node_id = cmd.node_args.node_id().to_string();
                let network_id = cmd.node_args.network_id().to_string();
                let container = format!("{node_id}-{network_id}");
                let network_path = directory_manager.network_path(&network_id);
                let docker = DockerManager::new(&network_path);
                let nodes = docker.compose_ps(None)?;

                let mut _fresh_state;

                _fresh_state = match docker.filter_container_by_name(nodes, &container) {
                    Some(node) => match node.state {
                        ContainerState::Running => {
                            warn!("Node '{node_id}' is already running in network '{network_id}'.");
                            false
                        }
                        ContainerState::Created => {
                            info!("Starting node '{node_id}' in network '{network_id}' for the first time.");
                            true
                        }
                        container_state => {
                            info!(
                                "Node '{node_id}' is {} in network '{network_id}'.",
                                container_state.to_string()
                            );
                            false
                        }
                    },
                    None => {
                        let error =
                            format!("Node '{node_id}' does not exist in network '{network_id}'.");
                        return handle_start_error(&node_id, error.as_str());
                    }
                };

                if cmd.fresh_state {
                    info!("Starting node '{node_id}' in network '{network_id}' with fresh state.");
                    docker.compose_down(Some(container.clone()), true, false)?;
                    docker.compose_create(Some(container.clone()))?;
                    _fresh_state = true;
                }

                if cmd.import_accounts {
                    warn!("Importing accounts for node '{node_id}' in network '{network_id}'. This can take a moment...");
                    import_all_accounts(&docker, &directory_manager, &node_id, &network_id)?;
                }

                match docker.compose_start(vec![&container]) {
                    Ok(out) => {
                        if out.status.success() {
                            if cmd.graphql_filtered_logs {
                                warn!("Waiting for graphql server to be operational so I can request filtered logs. This can take a moment...");
                                let gql = GraphQl::new(directory_manager.clone());
                                if let Some(gql_ep) = gql.get_endpoint(&node_id, &network_id) {
                                    gql.wait_for_server(&gql_ep)?;
                                    gql.request_filtered_logs(&gql_ep)?;
                                }
                            }

                            if cmd.node_args.raw_output {
                                println!(
                                    "Node '{node_id}' on network '{network_id}' \
                                          has been started. {}",
                                    String::from_utf8_lossy(&out.stdout)
                                );
                            } else {
                                println!(
                                    "{}",
                                    node::Start {
                                        // fresh_state,
                                        node_id,
                                        network_id,
                                    }
                                )
                            }

                            Ok(())
                        } else {
                            handle_start_error(&node_id, String::from_utf8_lossy(&out.stderr))
                        }
                    }
                    Err(e) => handle_start_error(&node_id, e),
                }
            }

            NodeCommand::Stop(cmd) => {
                let node_id = cmd.node_id().to_string();
                let network_id = cmd.network_id().to_string();
                let container = format!("{node_id}-{network_id}");
                let network_path = directory_manager.network_path(&network_id);
                let docker = DockerManager::new(&network_path);

                match docker.compose_stop(vec![&container]) {
                    Ok(out) => {
                        if out.status.success() {
                            if cmd.raw_output {
                                println!(
                                    "Node '{node_id}' on network '{network_id}' \
                                          has been stopped. {}",
                                    String::from_utf8_lossy(&out.stdout)
                                );
                            } else {
                                println!(
                                    "{}",
                                    node::Stop {
                                        node_id,
                                        network_id,
                                    }
                                )
                            }
                            Ok(())
                        } else {
                            handle_stop_error(&node_id, String::from_utf8_lossy(&out.stderr))
                        }
                    }
                    Err(e) => handle_stop_error(&node_id, e),
                }
            }

            NodeCommand::Logs(cmd) => {
                let node_id = cmd.node_id();
                let network_id = cmd.network_id();
                let network_path = directory_manager.network_path(network_id);

                match mode {
                    ExecutionMode::Docker => {
                        let docker = DockerManager::new(&network_path);
                        let services = directory_manager
                            .get_services_info(network_id)
                            .expect("Failed to get services info");
                        match docker.run_docker_logs(node_id, network_id) {
                            Ok(output) => {
                                if output.status.success() {
                                    info!(
                                        "Successfully got logs for '{node_id}' on '{network_id}'"
                                    );
                                    let out = if is_node_uptime_service(services, node_id) {
                                        &output.stderr
                                    } else {
                                        &output.stdout
                                    };
                                    if cmd.raw_output {
                                        println!("{}", String::from_utf8_lossy(out));
                                    } else {
                                        println!(
                                            "{}",
                                            output::node::Logs {
                                                logs: String::from_utf8_lossy(out).into(),
                                                network_id: network_id.into(),
                                                node_id: node_id.into(),
                                            }
                                        )
                                    }
                                } else {
                                    let error_message = format!(
                                        "Failed to get logs for '{node_id}' on '{network_id}': {}",
                                        String::from_utf8_lossy(&output.stderr)
                                    );
                                    return exit_with(error_message);
                                }
                            }
                            Err(e) => error!("Error while running 'docker logs {node_id}'{e}"),
                        }
                    }
                    ExecutionMode::Native => {
                        let native = NativeManager::new(&network_path, &bin_path);
                        match native.service_logs(node_id) {
                            Ok(logs) => {
                                if cmd.raw_output {
                                    println!("{logs}");
                                } else {
                                    println!(
                                        "{}",
                                        output::node::Logs {
                                            logs,
                                            network_id: network_id.into(),
                                            node_id: node_id.into(),
                                        }
                                    )
                                }
                            }
                            Err(e) => error!("Error getting logs for '{node_id}': {e}"),
                        }
                    }
                }

                Ok(())
            }

            NodeCommand::DumpArchiveData(cmd) => {
                let network_id = cmd.network_id();
                let node_id = cmd.node_id();
                let network_path = directory_manager.network_path(cmd.network_id());
                let docker = DockerManager::new(&network_path);
                let services = directory_manager
                    .get_services_info(network_id)
                    .expect("Failed to get services info");

                check_network_exists(network_id)?;

                if !is_node_archive(services, node_id) {
                    let error_message = format!(
                        "Node '{node_id}' is not an archive node in '{network_id}' network."
                    );
                    return exit_with(error_message);
                }

                match docker.compose_dump_archive_data(network_id) {
                    Ok(output) => {
                        if output.status.success() {
                            info!("Successfully dumped archive data for node '{node_id}', network '{network_id}'");
                            if cmd.raw_output {
                                println!("{}", String::from_utf8_lossy(&output.stdout));
                            } else {
                                println!(
                                    "{}",
                                    output::node::ArchiveData {
                                        data: String::from_utf8_lossy(&output.stdout).into(),
                                        network_id: network_id.into(),
                                        node_id: node_id.into(),
                                    }
                                )
                            }
                        } else {
                            let error_message = format!(
                                "Failed to dump archive data for node '{node_id}', network '{network_id}': {}",
                                String::from_utf8_lossy(&output.stderr)
                            );
                            return exit_with(error_message);
                        }
                    }
                    Err(e) => {
                        return exit_with(format!(
                            "Error while dumping archive data for node '{node_id}', network_id '{network_id}': {e}"
                        ))
                    }
                }

                Ok(())
            }

            NodeCommand::DumpPrecomputedBlocks(cmd) => {
                let node_id = cmd.node_id();
                let network_id = cmd.network_id();
                let network_path = directory_manager.network_path(cmd.network_id());
                let docker = DockerManager::new(&network_path);

                check_network_exists(network_id)?;

                match docker.compose_dump_precomputed_blocks(node_id, network_id) {
                    Ok(output) => {
                        if output.status.success() {
                            info!("Successfully dumped precomputed blocks for '{node_id}' on '{network_id}'");
                            if cmd.raw_output {
                                println!("{}", String::from_utf8_lossy(&output.stdout));
                            } else {
                                println!(
                                    "{}",
                                    output::node::PrecomputedBlocks {
                                        blocks: String::from_utf8_lossy(&output.stdout).into(),
                                        network_id: network_id.into(),
                                        node_id: node_id.into(),
                                    }
                                )
                            }
                        } else {
                            let error_message = format!(
                                "Failed to dump precomputed blocks for '{node_id}' on '{network_id}': {}", String::from_utf8_lossy(&output.stderr)
                            );
                            return exit_with(error_message);
                        }
                    }
                    Err(e) => {
                        let error_message = format!(
                            "Failed to dump precomputed blocks for '{node_id}' on '{network_id}': {e}"
                        );
                        return exit_with(error_message);
                    }
                }

                Ok(())
            }

            NodeCommand::RunReplayer(cmd) => {
                let start_slot = cmd.start_slot_since_genesis;
                let node_id = cmd.node_args.node_id();
                let network_id = cmd.node_args.network_id();
                let network_path = directory_manager.network_path(cmd.node_args.network_id());
                let docker = DockerManager::new(&network_path);
                let services = directory_manager
                    .get_services_info(network_id)
                    .expect("Failed to get services info");
                check_network_exists(network_id)?;

                if !is_node_archive(services, node_id) {
                    let error_message = format!(
                        "Node '{node_id}' is not an archive node in '{network_id}' network."
                    );
                    return exit_with(error_message);
                }

                if let Err(e) = genesis_ledger::set_slot_since_genesis(&network_path, start_slot) {
                    let error_message = format!(
                        "Failed to set slot since genesis to '{start_slot}' for node '{node_id}' on network '{network_id}': {e}"
                    );
                    return exit_with(error_message);
                }

                let archive_service_id = format!("{node_id}-service");
                match docker.compose_run_replayer(&archive_service_id, network_id) {
                    Ok(output) => {
                        if output.status.success() {
                            info!("Successfully ran replayer for node '{node_id}' on network '{network_id}' \
                                    and start_slot_since_genesis '{start_slot}'");
                            if cmd.node_args.raw_output {
                                println!("{}", String::from_utf8_lossy(&output.stdout));
                            } else {
                                println!(
                                    "{}",
                                    output::node::ReplayerLogs {
                                        logs: String::from_utf8_lossy(&output.stdout).into(),
                                        network_id: network_id.into(),
                                        node_id: node_id.into(),
                                    }
                                )
                            }
                        } else {
                            let error_message = format!(
                                "Failed to run replayer for node '{node_id}' on network '{network_id}' \
                                  and start_slot_since_genesis '{start_slot}': {}",
                                String::from_utf8_lossy(&output.stderr)
                            );
                            return exit_with(error_message);
                        }
                    }
                    Err(e) => {
                        return exit_with(format!(
                            "Error while running replayer for node '{node_id}' on network '{network_id}' \
                              and start_slot_since_genesis '{start_slot}': {e}"
                        ));
                    }
                }

                Ok(())
            }
        },
    }
}

fn create_network(
    docker: &DockerManager,
    directory_manager: &DirectoryManager,
    network_id: &str,
    services: &[ServiceConfig],
) -> Result<()> {
    match docker.compose_create(None) {
        Ok(output) => {
            if !output.status.success() {
                let error_message = format!(
                    "Failed to create network '{network_id}' with 'docker compose create': {}",
                    String::from_utf8_lossy(&output.stderr)
                );
                return exit_with(error_message);
            }
            info!("Successfully created docker-compose for network '{network_id}'!");

            // if we have archive node we need to:
            //  - create input file for replayer (for run-replayer command)
            //  - create database and apply schema scripts
            if let Some(archive_node) = ServiceConfig::get_archive_node(services) {
                // generate input file for mina-replayer
                default::LedgerGenerator::generate_replayer_input(
                    &directory_manager.network_path(network_id),
                )?;

                // create archive database and apply schema scripts
                // start postgres container
                let postgres_name = format!("postgres-{network_id}");
                let error_message =
                    format!("Failed to start postgres container in network '{network_id}'.");

                match docker.compose_start(vec![&postgres_name]) {
                    Ok(out) => {
                        if out.status.success() {
                            info!("Successfully started postgres container in network '{network_id}'!");
                        } else {
                            return exit_with(format!(
                                "{}: {}",
                                error_message,
                                String::from_utf8_lossy(&out.stderr)
                            ));
                        }
                    }
                    Err(e) => return exit_with(format!("{error_message}: {e}")),
                };

                // make sure postgres is running
                container_is_running(docker, &postgres_name)?;

                // create database
                let cmd = ["createdb", "-U", "postgres", "archive"];
                docker.exec(&postgres_name, &cmd)?;

                // apply schema scripts
                let scripts = archive_node.archive_schema_files.as_ref().unwrap();
                apply_schema_scripts(
                    docker.clone(),
                    &postgres_name,
                    scripts,
                    &directory_manager.network_path(network_id),
                )?;

                // stop postgres
                docker.compose_stop(vec![&postgres_name])?;
            }

            // generate network.json and services.json
            if let Err(e) = directory_manager.save_network_info(network_id, services) {
                error!("Error generating network.json: {e}")
            }

            if let Err(e) = directory_manager.save_services_info(network_id, services) {
                error!("Error generating services.json: {e}")
            }

            println!("{}", output::generate_network_info(services, network_id));
            Ok(())
        }
        Err(e) => {
            let error_message = format!(
                "Failed to register network '{network_id}' with 'docker compose create': {e}"
            );
            exit_with(error_message)
        }
    }
}

fn container_is_running(docker: &DockerManager, container_name: &str) -> Result<()> {
    let mut container_running = false;
    let mut retries = 0;

    while !container_running && retries < TIMEOUT_IN_SECS {
        let containers = docker.compose_ps(None)?;
        let container = docker.filter_container_by_name(containers, container_name);

        if let Some(container) = container {
            if container.state == ContainerState::Running {
                container_running = true;
            }
        }

        retries += 1;
        std::thread::sleep(std::time::Duration::from_secs(1));
    }

    if !container_running {
        return exit_with(format!(
            "Failed to start container '{container_name}' within {TIMEOUT_IN_SECS}s",
        ));
    }

    Ok(())
}

#[allow(dead_code)]
fn wait_for_daemon(
    docker: &DockerManager,
    node_id: &str,
    network_id: &str,
    client_port: u16,
) -> Result<()> {
    let mut retries = 0;
    let mut daemon_running = false;
    info!("Waiting for daemon to start for node '{node_id}' on network '{network_id}'...");
    while !daemon_running && retries < TIMEOUT_IN_SECS {
        let out = docker.compose_client_status(node_id, network_id, client_port)?;
        if out.status.success() {
            daemon_running = true;
        } else {
            retries += 1;
            std::thread::sleep(std::time::Duration::from_secs(1));
        }
    }
    if !daemon_running {
        return exit_with(format!(
            "Failed to start daemon for node '{node_id}' on network '{network_id}' within {TIMEOUT_IN_SECS}s",
        ));
    }
    Ok(())
}

/// Applies provided schema `scripts` to the postgres db, `postgres_name`
fn apply_schema_scripts(
    docker: DockerManager,
    postgres_name: &str,
    scripts: &Vec<String>,
    network_path: &Path,
) -> Result<()> {
    // copy scripts first
    for script in scripts {
        let file_path = fetch_schema(script, network_path.to_path_buf()).unwrap();
        let file_name = file_path.file_name().unwrap().to_str().unwrap();
        let docker_file_path = Path::new("/tmp").join(file_path.file_name().unwrap());

        info!("Copying schema script: {}", file_name);
        docker.cp(postgres_name, &file_path, &docker_file_path)?;
    }

    // then apply scripts 1 by 1
    for script in scripts {
        let file_path = fetch_schema(script, network_path.to_path_buf()).unwrap();
        let file_name = file_path.file_name().unwrap().to_str().unwrap();
        let docker_file_path = Path::new("/tmp").join(file_path.file_name().unwrap());
        let cmd = [
            "psql",
            "-U",
            "postgres",
            "-d",
            "archive",
            "-f",
            docker_file_path.to_str().unwrap(),
        ];

        info!("Applying schema script: {}", file_name);
        docker.exec(postgres_name, &cmd)?;
    }

    Ok(())
}

/// Generates a genesis ledger for the default network:
/// 1 seed, 2 bps, and a snark coordinator with one woker
fn generate_default_genesis_ledger(
    bp_keys_opt: &mut Option<HashMap<String, NodeKey>>,
    libp2p_keys_opt: &mut Option<HashMap<String, NodeKey>>,
    network_path: &Path,
    docker_image: &str,
    mode: &ExecutionMode,
    bin_path: &Path,
) -> Result<()> {
    info!("Genesis ledger not provided. Generating default genesis ledger.");

    // set default services to generate keys for
    let seeds = vec!["mina-seed-1"];
    let block_producers = vec!["mina-bp-1", "mina-bp-2"];
    let snark_coordinators = vec!["mina-snark-coordinator"];
    let snark_workers = vec!["mina-snark-worker-1"];
    let archive = vec!["mina-archive"];
    let all_services = [
        seeds,
        block_producers,
        snark_coordinators,
        snark_workers,
        archive,
    ]
    .concat();

    // generate key-pairs for default services based on mode
    match mode {
        ExecutionMode::Docker => {
            let keys_manager = KeysManager::new(network_path, docker_image);
            *bp_keys_opt = Some(
                keys_manager
                    .generate_bp_key_pairs(&all_services)
                    .expect("Failed to generate key pairs for mina services."),
            );
            *libp2p_keys_opt = Some(
                keys_manager
                    .generate_libp2p_key_pairs(&all_services)
                    .expect("Failed to generate libp2p key pairs for mina services."),
            );
        }
        ExecutionMode::Native => {
            let keys_manager = NativeKeysManager::new(network_path, bin_path);
            *bp_keys_opt = Some(
                keys_manager
                    .generate_bp_key_pairs(&all_services)
                    .expect("Failed to generate key pairs for mina services."),
            );
            *libp2p_keys_opt = Some(
                keys_manager
                    .generate_libp2p_key_pairs(&all_services)
                    .expect("Failed to generate libp2p key pairs for mina services."),
            );
        }
    }

    // generate default genesis ledger
    if let Err(e) = default::LedgerGenerator::generate(network_path, bp_keys_opt.as_ref().unwrap())
    {
        error!("Error generating default ledger: {e}");
    }

    Ok(())
}

/// Generates a topology file for the default network:
/// 1 seed, 2 bps, and a snark coordinator with one woker
fn generate_default_topology(
    bp_keys: &HashMap<String, NodeKey>,
    libp2p_keys: &HashMap<String, NodeKey>,
    docker_image: &str,
    docker_image_archive: &str,
    network_id: &str,
) -> Vec<service::ServiceConfig> {
    let seed_name = "mina-seed-1";
    let libp2p_peerid = libp2p_keys[seed_name]
        .key_string
        .split(',')
        .next_back()
        .unwrap();
    let peer = ServiceConfig::generate_peer(
        seed_name,
        network_id,
        libp2p_peerid,
        3102, //external port on my mina_seed_1 will be 3102
    );
    let seed = ServiceConfig {
        service_type: ServiceType::Seed,
        service_name: seed_name.to_string(),
        docker_image: Some(docker_image.into()),
        client_port: Some(3100),
        libp2p_keypair: Some(libp2p_keys[seed_name].key_string.clone()),
        libp2p_peerid: Some(libp2p_peerid.to_string()),
        ..Default::default()
    };

    let bp_1_name = "mina-bp-1";
    let bp_1 = ServiceConfig {
        service_type: ServiceType::BlockProducer,
        service_name: bp_1_name.to_string(),
        docker_image: Some(docker_image.into()),
        client_port: Some(4000),
        public_key: Some(bp_keys[bp_1_name].key_string.clone()),
        public_key_path: Some(bp_keys[bp_1_name].key_path.clone()),
        libp2p_keypair: Some(libp2p_keys[bp_1_name].key_string.clone()),
        peers: Some(vec![peer.clone()]),
        ..Default::default()
    };

    let bp_2_name = "mina-bp-2";
    let bp_2 = ServiceConfig {
        service_type: ServiceType::BlockProducer,
        service_name: bp_2_name.to_string(),
        docker_image: Some(docker_image.into()),
        client_port: Some(4005),
        public_key: Some(bp_keys[bp_2_name].key_string.clone()),
        public_key_path: Some(bp_keys[bp_2_name].key_path.clone()),
        libp2p_keypair: Some(libp2p_keys[bp_2_name].key_string.clone()),
        peers: Some(vec![peer.clone()]),
        ..Default::default()
    };

    let snark_coordinator_name = "mina-snark-coordinator";
    let snark_coordinator = ServiceConfig {
        service_type: ServiceType::SnarkCoordinator,
        service_name: snark_coordinator_name.to_string(),
        docker_image: Some(docker_image.into()),
        client_port: Some(7000),
        public_key: Some(bp_keys[snark_coordinator_name].key_string.clone()),
        libp2p_keypair: Some(libp2p_keys[snark_coordinator_name].key_string.clone()),
        peers: Some(vec![peer.clone()]),
        snark_coordinator_fees: Some("0.001".into()),
        worker_nodes: Some(1),
        ..Default::default()
    };

    let snark_worker_1_name = "mina-snark-worker-1";
    let snark_worker_1 = ServiceConfig {
        service_type: ServiceType::SnarkWorker,
        service_name: snark_worker_1_name.to_string(),
        docker_image: Some(docker_image.into()),
        snark_coordinator_port: Some(7000),
        snark_worker_proof_level: Some("full".into()),
        snark_coordinator_host: Some(snark_coordinator.service_name.clone()),
        ..Default::default()
    };

    let archive_node_name = "mina-archive";
    let archive_node = ServiceConfig {
        service_type: ServiceType::ArchiveNode,
        service_name: archive_node_name.to_string(),
        docker_image: Some(docker_image.into()),
        client_port: Some(5005),
        public_key: Some(bp_keys[archive_node_name].key_string.clone()),
        public_key_path: Some(bp_keys[archive_node_name].key_path.clone()),
        libp2p_keypair: Some(libp2p_keys[archive_node_name].key_string.clone()),
        peers: Some(vec![peer]),
        archive_docker_image: Some(docker_image_archive.into()),
        archive_schema_files: Some(vec![
            format!("https://raw.githubusercontent.com/MinaProtocol/mina/{IMAGE_COMMIT_HASH}/src/app/archive/zkapp_tables.sql"),
            format!("https://raw.githubusercontent.com/MinaProtocol/mina/{IMAGE_COMMIT_HASH}/src/app/archive/create_schema.sql"),
        ]),
        archive_port: Some(3086),
        ..Default::default()
    };
    vec![
        seed,
        bp_1,
        bp_2,
        snark_coordinator,
        snark_worker_1,
        archive_node,
    ]
}

/// If the network exists, its directory is deleted, corresponding docker
/// images are removed, and it is created anew.
/// If the network doesn't exist, the directory structure is created.
fn check_setup_network(
    docker: &DockerManager,
    directory_manager: &DirectoryManager,
    network_id: &str,
) -> Result<()> {
    if directory_manager.network_path_exists(network_id) {
        warn!("Network '{network_id}' already exists. Overwriting!");
        docker.compose_down(None, false, false)?;
        directory_manager.delete_network_directory(network_id)?;
    }

    // create directory structure for network
    info!("Creating network '{network_id}'.");
    if let Err(e) = directory_manager.generate_dir_structure(network_id) {
        return exit_with(format!(
            "Failed to set up network directory structure for '{network_id}' with error: {e}"
        ));
    }

    Ok(())
}

/// Check that the network exists and overwrites genesis ledger if needed
fn check_network_exists(network_id: &str) -> Result<()> {
    let directory_manager = DirectoryManager::new();
    if directory_manager.network_path_exists(network_id) {
        Ok(())
    } else {
        let error_message = format!(
            "Network directory '{}' does not exist, therefore network '{network_id}' does not exist too.",
            directory_manager.network_path(network_id).display()
        );
        exit_with(error_message)
    }
}

/// Handles `network_id`'s genesis ledger
///
/// If no genesis ledger is provided, a default ledger will be generated
fn handle_genesis_ledger(
    cmd: &cli::CreateNetworkArgs,
    directory_manager: &DirectoryManager,
    network_id: &str,
    bp_keys_opt: &mut Option<HashMap<String, NodeKey>>,
    libp2p_keys_opt: &mut Option<HashMap<String, NodeKey>>,
    mode: &ExecutionMode,
    bin_path: &Path,
) -> Result<()> {
    let network_path = directory_manager.network_path(network_id);

    match &cmd.genesis_ledger {
        Some(genesis_ledger_path) => {
            if cmd.topology.is_none() {
                directory_manager.delete_network_directory(network_id)?;
                return exit_with(
                    "Must provide a topology file with a genesis ledger, keys will be incompatible otherwise.".to_string(),
                );
            }

            info!(
                "Copying genesis ledger from '{}' to network directory.",
                genesis_ledger_path.display()
            );

            directory_manager.copy_genesis_ledger(network_id, genesis_ledger_path)?;
            directory_manager.overwrite_genesis_timestamp(network_id, genesis_ledger_path)
        }
        None => generate_default_genesis_ledger(
            bp_keys_opt,
            libp2p_keys_opt,
            &network_path,
            DEFAULT_DAEMON_DOCKER_IMAGE,
            mode,
            bin_path,
        ),
    }
}

/// Creates the list of docker service configs from the topology file at `topology_path`
/// using the seed nodes as the list of network peers (at least 1 seed node must be declared)
///
/// Logs and error and exits with code 1 if the topology file can't be parsed
fn create_services(
    directory_manager: &DirectoryManager,
    topology_path: &Path,
    network_id: &str,
) -> Result<Vec<ServiceConfig>> {
    match topology::Topology::new(topology_path) {
        Ok(topology) => {
            let peer_list_file = directory_manager.peer_list_file(network_id);
            let services = topology.services(&peer_list_file);
            let peers: Vec<&ServiceConfig> = ServiceConfig::get_seeds(&services);
            directory_manager.create_peer_list_file(network_id, &peers)?;

            if let Some(uptime_service_backend) =
                ServiceConfig::get_uptime_service_backend(&services)
            {
                match directory_manager
                    .copy_uptime_service_config(network_id, uptime_service_backend)
                {
                    Ok(_) => info!("Successfully copied uptime service config."),
                    Err(e) => {
                        let error_message = format!("Failed to copy uptime service config: {e}");
                        exit_with(error_message)?;
                    }
                }
            }

            if peers.is_empty() {
                error!("There are no seed nodes declared in this network. You must include seed nodes.");
                exit(1);
            }

            Ok(services)
        }
        Err(err) => {
            error!(
                "Error occured while parsing the topology file:\n\
                 path: {}\n\
                 error: {err}",
                topology_path.display()
            );
            exit(1)
        }
    }
}

/// Creates service configs for the nodes specified in the topology file of the given `cmd`
fn handle_topology(
    cmd: &cli::CreateNetworkArgs,
    directory_manager: &DirectoryManager,
    network_id: &str,
    bp_keys: Option<HashMap<String, NodeKey>>,
    libp2p_keys: Option<HashMap<String, NodeKey>>,
) -> Result<Vec<ServiceConfig>> {
    match &cmd.topology {
        Some(topology_path) => {
            if cmd.genesis_ledger.is_none() {
                error!(
                    "Must provide a genesis ledger with a topology file, \
                     keys will be incompatible otherwise."
                );

                directory_manager.delete_network_directory(network_id)?;
                exit(1);
            }

            info!(
                "Generating docker-compose based on provided topology '{}'.",
                topology_path.display()
            );

            let network_topology_path = directory_manager.topology_file_path(network_id);
            std::fs::copy(topology_path, network_topology_path)?;
            create_services(directory_manager, topology_path, network_id)
        }
        None => {
            info!("Topology not provided. Generating docker-compose based on default topology.");

            if let (Some(bp_keys), Some(libp2p_keys)) = (&bp_keys.as_ref(), &libp2p_keys.as_ref()) {
                Ok(generate_default_topology(
                    bp_keys,
                    libp2p_keys,
                    DEFAULT_DAEMON_DOCKER_IMAGE,
                    DEFAULT_ARCHIVE_DOCKER_IMAGE,
                    network_id,
                ))
            } else {
                let err = "Failed to generate docker-compose.yaml. Keys not generated.";
                error!("{err}");
                Err(Error::new(ErrorKind::InvalidData, err))
            }
        }
    }
}

fn check_execution_environment(mode: &ExecutionMode, bin_path: &Path) -> Result<()> {
    match mode {
        ExecutionMode::Docker => {
            let compose_version = DockerManager::compose_version();
            match compose_version {
                Some(version) => {
                    if version.as_str() < LEAST_COMPOSE_VERSION {
                        error!(
                            "Docker compose version '{version}' is less than \
                                the least supported version '{LEAST_COMPOSE_VERSION}'."
                        );

                        return Err(Error::new(
                            ErrorKind::InvalidInput,
                            "docker compose needs to be updated",
                        ));
                    }

                    Ok(())
                }
                None => {
                    error!(
                        "It seems that docker not installed! Please install docker and try again."
                    );
                    Err(Error::new(ErrorKind::NotFound, "docker is missing"))
                }
            }
        }
        ExecutionMode::Native => {
            let mina_bin = bin_path.join("mina");
            if !mina_bin.exists() {
                error!(
                    "Mina binary not found at '{}'. Please install mina or use --bin-path.",
                    mina_bin.display()
                );
                return Err(Error::new(
                    ErrorKind::NotFound,
                    format!("mina binary not found at '{}'", mina_bin.display()),
                ));
            }
            Ok(())
        }
    }
}

fn create_network_native(
    native: &NativeManager,
    directory_manager: &DirectoryManager,
    network_id: &str,
    services: &[ServiceConfig],
) -> Result<()> {
    // For native mode, create is a no-op (processes start on 'network start')
    native.create(None)?;
    info!("Successfully prepared native network '{network_id}'!");

    // Handle archive node setup with local postgres
    if let Some(archive_node) = ServiceConfig::get_archive_node(services) {
        default::LedgerGenerator::generate_replayer_input(
            &directory_manager.network_path(network_id),
        )?;

        // Create database using local psql
        info!("Creating archive database using local postgres...");
        let createdb_out = std::process::Command::new("createdb")
            .args(["-U", "postgres", "archive"])
            .output()?;

        if !createdb_out.status.success() {
            warn!(
                "createdb may have failed (database might already exist): {}",
                String::from_utf8_lossy(&createdb_out.stderr)
            );
        }

        // Apply schema scripts directly via psql
        if let Some(scripts) = &archive_node.archive_schema_files {
            let network_path = directory_manager.network_path(network_id);
            for script in scripts {
                let file_path = fetch_schema(script, network_path.clone()).unwrap();
                info!("Applying schema script: {}", file_path.display());
                let psql_out = std::process::Command::new("psql")
                    .args(["-U", "postgres", "-d", "archive", "-f"])
                    .arg(&file_path)
                    .output()?;

                if !psql_out.status.success() {
                    warn!(
                        "psql schema application may have failed: {}",
                        String::from_utf8_lossy(&psql_out.stderr)
                    );
                }
            }
        }
    }

    // generate network.json and services.json
    if let Err(e) = directory_manager.save_network_info(network_id, services) {
        error!("Error generating network.json: {e}")
    }

    if let Err(e) = directory_manager.save_services_info(network_id, services) {
        error!("Error generating services.json: {e}")
    }

    println!("{}", output::generate_network_info(services, network_id));
    Ok(())
}

fn exit_with(error_message: String) -> Result<()> {
    error!("{error_message}");
    println!("{}", output::Error { error_message });
    exit(1);
}

fn handle_stop_error(node_id: &str, error: impl ToString) -> Result<()> {
    let error_message = format!("Failed to stop node '{node_id}': {}", error.to_string());
    exit_with(error_message)
}

fn handle_start_error(node_id: &str, error: impl ToString) -> Result<()> {
    let error_message = format!("Failed to start node '{node_id}': {}", error.to_string());
    exit_with(error_message)
}

fn is_node_uptime_service(services: Vec<ServiceConfig>, node_id: &str) -> bool {
    if let Some(uptime) = ServiceConfig::get_uptime_service_backend(&services) {
        if uptime.service_name == node_id {
            return true;
        }
    }
    false
}

fn is_node_archive(services: Vec<ServiceConfig>, node_id: &str) -> bool {
    if let Some(archive) = ServiceConfig::get_archive_node(&services) {
        if archive.service_name == node_id {
            return true;
        }
    }
    false
}

fn import_all_accounts(
    docker: &DockerManager,
    directory_manager: &DirectoryManager,
    node_id: &str,
    network_id: &str,
) -> Result<()> {
    let account_files = directory_manager.get_network_keypair_files(network_id)?;
    for account_file in account_files {
        let out = docker.compose_import_account(node_id, network_id, &account_file);
        match out {
            Ok(output) => {
                if output.status.success() {
                    info!(
                        "Successfully imported account from file '{account_file}' \
                        for node '{node_id}' on network '{network_id}'",
                    );
                } else {
                    let error_message = format!(
                        "Failed to import account from file '{account_file}' \
                        for node '{node_id}' on network '{network_id}': {}",
                        String::from_utf8_lossy(&output.stderr),
                    );
                    return exit_with(error_message);
                }
            }
            Err(e) => {
                let error_message = format!(
                    "Failed to import account from file '{account_file}' \
                    for node '{node_id}' on network '{network_id}': {e}",
                );
                return exit_with(error_message);
            }
        }
    }
    Ok(())
}
