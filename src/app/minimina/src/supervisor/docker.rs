//! Docker backend: units are bollard-managed containers on a supervisor-owned
//! docker network (replaces `docker compose`).

use std::collections::HashMap;
use std::io;

use bollard::container::{
    Config, CreateContainerOptions, NetworkingConfig, RemoveContainerOptions, StopContainerOptions,
    WaitContainerOptions,
};
use bollard::exec::{CreateExecOptions, StartExecOptions};
use bollard::image::CreateImageOptions;
use bollard::network::CreateNetworkOptions;
use bollard::secret::{EndpointSettings, HostConfig, PortBinding};
use bollard::Docker;
use futures_util::StreamExt;
use log::{info, warn};

use super::backend::Backend;
use super::plan::{BackendSpec, DockerBackendSpec, DockerNodeSpec, Readiness};
use super::run_backend;

/// How long a single readiness exec is given to finish before the attempt is
/// abandoned (the caller polls again).
const EXEC_POLLS: u32 = 20;
const EXEC_POLL_INTERVAL: std::time::Duration = std::time::Duration::from_millis(50);

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

impl DockerBackend {
    /// Run `cmd` inside `container` and report whether it exited 0.
    ///
    /// Runs the exec **detached** and polls for its exit rather than attaching
    /// to its output. An attached exec hijacks the HTTP connection into a
    /// bidirectional stream, and that stream does not reliably end while the
    /// same client is holding a long-lived `wait_container` open for this very
    /// container — which it always is, since the unit's waiter task starts
    /// first. Detached execs stay ordinary requests, and we only need the exit
    /// status anyway.
    ///
    /// Anything unexpected (transport error, still running) is reported as "not
    /// ready" rather than an error: the caller polls, so the next attempt gets
    /// a fresh exec.
    async fn exec_succeeds(&self, container: &str, cmd: &[String]) -> bool {
        let exec = match self
            .docker
            .create_exec(
                container,
                CreateExecOptions {
                    cmd: Some(cmd.to_vec()),
                    ..Default::default()
                },
            )
            .await
        {
            Ok(exec) => exec,
            Err(e) => {
                warn!("supervisor: create_exec on '{container}' failed: {e}");
                return false;
            }
        };

        if let Err(e) = self
            .docker
            .start_exec(
                &exec.id,
                Some(StartExecOptions {
                    detach: true,
                    ..Default::default()
                }),
            )
            .await
        {
            warn!("supervisor: start_exec on '{container}' failed: {e}");
            return false;
        }

        // Readiness commands are quick; give this one a moment to finish and
        // otherwise let the caller's next poll take over.
        for _ in 0..EXEC_POLLS {
            match self.docker.inspect_exec(&exec.id).await {
                Ok(r) if r.running != Some(true) => return r.exit_code == Some(0),
                Ok(_) => {}
                Err(e) => {
                    warn!("supervisor: inspect_exec on '{container}' failed: {e}");
                    return false;
                }
            }
            tokio::time::sleep(EXEC_POLL_INTERVAL).await;
        }
        false
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

        self.docker
            .create_container(
                Some(CreateContainerOptions {
                    name: node.name.clone(),
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
                io::Error::other(format!("create_container '{}' failed: {e}", node.name))
            })?;

        self.docker
            .start_container(
                &node.name,
                None::<bollard::container::StartContainerOptions<String>>,
            )
            .await
            .map_err(|e| {
                io::Error::other(format!("start_container '{}' failed: {e}", node.name))
            })?;

        let pid = self
            .docker
            .inspect_container(&node.name, None)
            .await
            .ok()
            .and_then(|i| i.state)
            .and_then(|s| s.pid)
            .map(|p| p as u32);

        let handle = ContainerHandle {
            docker: self.docker.clone(),
            name: node.name.clone(),
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

    /// `TcpPort` connects from the host (so it only reaches published ports);
    /// `Command` runs inside the container via exec, which is how an
    /// internal-only unit gets probed at all.
    async fn probe(&self, node: &DockerNodeSpec, readiness: &Readiness) -> bool {
        match readiness {
            Readiness::TcpPort(port) => tokio::net::TcpStream::connect(("127.0.0.1", *port))
                .await
                .is_ok(),
            Readiness::Command(cmd) => self.exec_succeeds(&node.name, cmd).await,
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

    async fn teardown(&self) {
        if let Err(e) = self.docker.remove_network(&self.network_name).await {
            warn!("supervisor: remove_network '{}': {e}", self.network_name);
        }
    }
}
