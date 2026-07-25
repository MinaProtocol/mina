//! Docker backend: units are bollard-managed containers on a supervisor-owned
//! docker network (replaces `docker compose`).

use std::collections::HashMap;
use std::io;
use std::path::Path;

use bollard::container::{
    Config, CreateContainerOptions, LogsOptions, NetworkingConfig, RemoveContainerOptions,
    StopContainerOptions, WaitContainerOptions,
};
use bollard::exec::{CreateExecOptions, StartExecResults};
use bollard::image::CreateImageOptions;
use bollard::network::CreateNetworkOptions;
use bollard::secret::{EndpointSettings, HostConfig, PortBinding};
use bollard::Docker;
use futures_util::StreamExt;
use log::{info, warn};

use crate::archive::{self, PgConfig};
use crate::directory_manager::{CONFIG_DIRECTORY, NETWORK_KEYPAIRS};
use crate::genesis_ledger::REPLAYER_INPUT_JSON;

use super::backend::Backend;
use super::plan::{BackendSpec, DockerBackendSpec, DockerNodeSpec};
use super::run_backend;

/// The docker backend owns the network-level resources: the daemon connection
/// and the docker network (+ DNS aliases) every container attaches to.
pub struct DockerBackend {
    docker: Docker,
    network_name: String,
    network_id: String,
}

/// A container handle: everything needed to wait on *or* kill a container via
/// the daemon. Unlike the native backend, waiting needs no exclusive resource,
/// so the same cloneable type serves as both unit and kill handle.
#[derive(Clone)]
pub struct ContainerHandle {
    docker: Docker,
    name: String,
}

impl BackendSpec for DockerBackendSpec {
    fn run<'a>(
        &'a self,
        network_id: &'a str,
        socket_path: &'a std::path::Path,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = io::Result<()>> + Send + 'a>> {
        Box::pin(run_backend::<DockerBackend>(self, network_id, socket_path))
    }
}

impl Backend for DockerBackend {
    type Spec = DockerBackendSpec;
    type NodeSpec = DockerNodeSpec;
    type Unit = ContainerHandle;
    type Killer = ContainerHandle;

    /// Connect to the docker daemon and create the network (labelled for
    /// grouping).
    async fn setup(spec: &DockerBackendSpec, network_id: &str) -> io::Result<Self> {
        let network_name = &spec.network_name;
        let docker = Docker::connect_with_local_defaults()
            .map_err(|e| io::Error::other(format!("docker connect failed: {e}")))?;
        let mut labels = HashMap::new();
        labels.insert("minimina.network".to_string(), network_id.to_string());
        if let Err(e) = docker
            .create_network(CreateNetworkOptions {
                name: network_name.to_string(),
                labels,
                ..Default::default()
            })
            .await
        {
            // A leftover network from a crashed run answers 409; reuse it.
            // Anything else (daemon down, permissions, bad name) is fatal.
            match e {
                bollard::errors::Error::DockerResponseServerError {
                    status_code: 409, ..
                } => info!("supervisor: network '{network_name}' already exists, reusing"),
                e => {
                    return Err(io::Error::other(format!(
                        "create_network '{network_name}' failed: {e}"
                    )))
                }
            }
        }
        Ok(DockerBackend {
            docker,
            network_name: network_name.to_string(),
            network_id: network_id.to_string(),
        })
    }

    fn nodes(spec: &DockerBackendSpec) -> &[DockerNodeSpec] {
        &spec.nodes
    }

    /// Pull the image, create + start the container.
    async fn launch(
        &self,
        node: &DockerNodeSpec,
    ) -> io::Result<(ContainerHandle, ContainerHandle, Option<u32>)> {
        // Pull (cached if already present).
        let mut pull = self.docker.create_image(
            Some(CreateImageOptions {
                from_image: node.image.clone(),
                ..Default::default()
            }),
            None,
            None,
        );
        while let Some(item) = pull.next().await {
            item.map_err(|e| io::Error::other(format!("pull '{}' failed: {e}", node.image)))?;
        }

        // Port bindings + exposed ports.
        let mut port_bindings = HashMap::new();
        let mut exposed = HashMap::new();
        for (host, container) in &node.ports {
            let key = format!("{container}/tcp");
            port_bindings.insert(
                key.clone(),
                Some(vec![PortBinding {
                    host_ip: Some("0.0.0.0".to_string()),
                    host_port: Some(host.to_string()),
                }]),
            );
            exposed.insert(key, HashMap::new());
        }

        let binds: Vec<String> = node
            .mounts
            .iter()
            .map(|m| {
                if m.read_only {
                    format!("{}:{}:ro", m.host, m.container)
                } else {
                    format!("{}:{}", m.host, m.container)
                }
            })
            .collect();

        let mut endpoints = HashMap::new();
        endpoints.insert(
            self.network_name.clone(),
            EndpointSettings {
                aliases: Some(node.aliases.clone()),
                ..Default::default()
            },
        );

        let mut labels = HashMap::new();
        labels.insert("minimina.network".to_string(), self.network_id.clone());

        let host_config = HostConfig {
            binds: if binds.is_empty() { None } else { Some(binds) },
            port_bindings: if port_bindings.is_empty() {
                None
            } else {
                Some(port_bindings)
            },
            ..Default::default()
        };

        // Best-effort: remove any container that already holds this name — a
        // self-exited unit being relaunched by `node_start`, or a leftover from
        // a crashed prior run — so `create_container` won't 409 on the name.
        let _ = self
            .docker
            .remove_container(
                &node.container_name,
                Some(RemoveContainerOptions {
                    force: true,
                    ..Default::default()
                }),
            )
            .await;

        self.docker
            .create_container(
                Some(CreateContainerOptions {
                    name: node.container_name.clone(),
                    platform: None,
                }),
                Config {
                    image: Some(node.image.clone()),
                    entrypoint: node.entrypoint.clone(),
                    cmd: if node.cmd.is_empty() {
                        None
                    } else {
                        Some(node.cmd.clone())
                    },
                    env: Some(node.env.iter().map(|(k, v)| format!("{k}={v}")).collect()),
                    exposed_ports: if exposed.is_empty() {
                        None
                    } else {
                        Some(exposed)
                    },
                    labels: Some(labels),
                    host_config: Some(host_config),
                    networking_config: Some(NetworkingConfig {
                        endpoints_config: endpoints,
                    }),
                    ..Default::default()
                },
            )
            .await
            .map_err(|e| {
                io::Error::other(format!(
                    "create_container '{}' failed: {e}",
                    node.container_name
                ))
            })?;

        self.docker
            .start_container(
                &node.container_name,
                None::<bollard::container::StartContainerOptions<String>>,
            )
            .await
            .map_err(|e| {
                io::Error::other(format!(
                    "start_container '{}' failed: {e}",
                    node.container_name
                ))
            })?;

        let pid = self
            .docker
            .inspect_container(&node.container_name, None)
            .await
            .ok()
            .and_then(|i| i.state)
            .and_then(|s| s.pid)
            .map(|p| p as u32);

        let handle = ContainerHandle {
            docker: self.docker.clone(),
            name: node.container_name.clone(),
        };
        Ok((handle.clone(), handle, pid))
    }

    async fn wait(unit: &mut ContainerHandle) -> Option<i32> {
        let mut stream = unit
            .docker
            .wait_container(&unit.name, None::<WaitContainerOptions<String>>);
        match stream.next().await {
            Some(Ok(r)) => Some(r.status_code as i32),
            Some(Err(e)) => {
                warn!("supervisor: wait_container '{}' failed: {e}", unit.name);
                None
            }
            None => None,
        }
    }

    async fn terminate(killer: &ContainerHandle) {
        let _ = killer
            .docker
            .stop_container(&killer.name, Some(StopContainerOptions { t: 2 }))
            .await;
    }

    async fn force_kill(killer: &ContainerHandle) {
        let _ = killer
            .docker
            .remove_container(
                &killer.name,
                Some(RemoveContainerOptions {
                    force: true,
                    ..Default::default()
                }),
            )
            .await;
    }

    async fn logs(&self, node: &DockerNodeSpec, tail: Option<u64>) -> io::Result<String> {
        let opts = LogsOptions::<String> {
            stdout: true,
            stderr: true,
            tail: tail
                .map(|t| t.to_string())
                .unwrap_or_else(|| "all".to_string()),
            ..Default::default()
        };
        let mut stream = self.docker.logs(&node.container_name, Some(opts));
        let mut out = String::new();
        while let Some(item) = stream.next().await {
            match item {
                Ok(chunk) => out.push_str(&String::from_utf8_lossy(&chunk.into_bytes())),
                Err(e) => {
                    return Err(io::Error::other(format!(
                        "logs '{}' failed: {e}",
                        node.container_name
                    )))
                }
            }
        }
        Ok(out)
    }

    async fn import_accounts(
        &self,
        node: &DockerNodeSpec,
        _network_path: &Path,
        files: &[String],
    ) -> io::Result<u64> {
        // Paths are container-internal: the network dir is bind-mounted at
        // `/local-network` and the config dir at `/config-directory`.
        let mut imported = 0;
        for file in files {
            let cmd = vec![
                "mina".to_string(),
                "accounts".to_string(),
                "import".to_string(),
                "--privkey-path".to_string(),
                format!("/local-network/{NETWORK_KEYPAIRS}/{file}"),
                "--config-directory".to_string(),
                format!("/{CONFIG_DIRECTORY}"),
            ];
            self.container_exec(&node.container_name, &cmd)
                .await
                .map_err(|e| io::Error::other(format!("import '{file}': {e}")))?;
            imported += 1;
        }
        Ok(imported)
    }

    async fn dump_archive_data(&self, network_id: &str) -> io::Result<String> {
        let pg = PgConfig::default();
        let cmd = vec![
            "pg_dump".to_string(),
            "--insert".to_string(),
            "-U".to_string(),
            pg.user.to_string(),
            pg.db.to_string(),
        ];
        self.container_exec(&archive::postgres_container_name(network_id), &cmd)
            .await
            .map_err(|e| io::Error::other(format!("pg_dump: {e}")))
    }

    async fn run_replayer(
        &self,
        svc: &DockerNodeSpec,
        _network_path: &Path,
        network_id: &str,
    ) -> io::Result<String> {
        let cmd = vec![
            "mina-replayer".to_string(),
            "--continue-on-error".to_string(),
            "--input-file".to_string(),
            format!("/local-network/{REPLAYER_INPUT_JSON}"),
            "--archive-uri".to_string(),
            PgConfig::default().uri(&archive::postgres_container_name(network_id)),
            "--output-file".to_string(),
            "/dev/null".to_string(),
        ];
        self.container_exec(&svc.container_name, &cmd)
            .await
            .map_err(|e| io::Error::other(format!("replayer: {e}")))
    }

    async fn teardown(&self) {
        if let Err(e) = self.docker.remove_network(&self.network_name).await {
            warn!("supervisor: remove_network '{}': {e}", self.network_name);
        }
    }
}

impl DockerBackend {
    /// `exec` a command in `container` and return its combined stdout+stderr. A
    /// nonzero exec exit is an error (with the captured output) — never returned
    /// as if it were valid output; stream errors propagate too.
    async fn container_exec(&self, container: &str, cmd: &[String]) -> io::Result<String> {
        let exec = self
            .docker
            .create_exec(
                container,
                CreateExecOptions {
                    cmd: Some(cmd.iter().map(|s| s.as_str()).collect()),
                    attach_stdout: Some(true),
                    attach_stderr: Some(true),
                    ..Default::default()
                },
            )
            .await
            .map_err(|e| io::Error::other(format!("create_exec '{container}': {e}")))?;
        let mut out = String::new();
        if let StartExecResults::Attached { mut output, .. } = self
            .docker
            .start_exec(&exec.id, None)
            .await
            .map_err(|e| io::Error::other(format!("start_exec '{container}': {e}")))?
        {
            while let Some(item) = output.next().await {
                match item {
                    Ok(chunk) => out.push_str(&String::from_utf8_lossy(&chunk.into_bytes())),
                    Err(e) => {
                        return Err(io::Error::other(format!("exec '{container}' stream: {e}")))
                    }
                }
            }
        }
        // A failed command (bad import, pg_dump error, …) must not masquerade as
        // valid output, so surface a nonzero exit code as an error.
        let code = self
            .docker
            .inspect_exec(&exec.id)
            .await
            .map_err(|e| io::Error::other(format!("inspect_exec '{container}': {e}")))?
            .exit_code;
        match code {
            Some(0) | None => Ok(out),
            Some(c) => Err(io::Error::other(format!(
                "exec '{container}' exited with {c}: {}",
                out.trim()
            ))),
        }
    }
}
