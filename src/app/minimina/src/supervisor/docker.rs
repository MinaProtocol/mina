//! Docker backend: units are bollard-managed containers on a supervisor-owned
//! docker network (replaces `docker compose`).

use std::collections::HashMap;
use std::io;

use bollard::container::{
    Config, CreateContainerOptions, NetworkingConfig, RemoveContainerOptions, StopContainerOptions,
    WaitContainerOptions,
};
use bollard::image::CreateImageOptions;
use bollard::network::CreateNetworkOptions;
use bollard::secret::{EndpointSettings, HostConfig, PortBinding};
use bollard::Docker;
use futures_util::StreamExt;
use log::warn;

use super::backend::{Backend, Killer, Unit};
use super::plan::DockerNodeSpec;

/// The docker backend owns the network-level resources: the daemon connection
/// and the docker network (+ DNS aliases) every container attaches to.
pub struct DockerBackend {
    docker: Docker,
    network_name: String,
    network_id: String,
}

impl DockerBackend {
    /// Connect to the docker daemon and create the network (labelled for
    /// grouping).
    pub async fn setup(network_name: &str, network_id: &str) -> io::Result<Self> {
        let docker = Docker::connect_with_local_defaults()
            .map_err(|e| io::Error::other(format!("docker connect failed: {e}")))?;
        let mut labels = HashMap::new();
        labels.insert("minimina.network".to_string(), network_id.to_string());
        // Best-effort: ignore "already exists" so re-runs don't hard-fail.
        if let Err(e) = docker
            .create_network(CreateNetworkOptions {
                name: network_name.to_string(),
                labels,
                ..Default::default()
            })
            .await
        {
            warn!("supervisor: create_network '{network_name}' (continuing): {e}");
        }
        Ok(DockerBackend {
            docker,
            network_name: network_name.to_string(),
            network_id: network_id.to_string(),
        })
    }
}

/// A supervisor-owned container, awaited via the daemon's wait stream.
pub struct DockerUnit {
    docker: Docker,
    name: String,
}

/// Kill handle for a docker unit: stop, then force-remove, via the daemon.
#[derive(Clone)]
pub struct DockerKiller {
    docker: Docker,
    name: String,
}

impl Backend for DockerBackend {
    type NodeSpec = DockerNodeSpec;
    type Unit = DockerUnit;
    type Killer = DockerKiller;

    /// Pull the image, create + start the container.
    async fn launch(
        &self,
        node: &DockerNodeSpec,
    ) -> io::Result<(DockerUnit, DockerKiller, Option<u32>)> {
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

        Ok((
            DockerUnit {
                docker: self.docker.clone(),
                name: node.name.clone(),
            },
            DockerKiller {
                docker: self.docker.clone(),
                name: node.name.clone(),
            },
            pid,
        ))
    }

    async fn teardown(&self) {
        if let Err(e) = self.docker.remove_network(&self.network_name).await {
            warn!("supervisor: remove_network '{}': {e}", self.network_name);
        }
    }
}

impl Unit for DockerUnit {
    async fn wait(&mut self) -> Option<i32> {
        let mut stream = self
            .docker
            .wait_container(&self.name, None::<WaitContainerOptions<String>>);
        match stream.next().await {
            Some(Ok(r)) => Some(r.status_code as i32),
            Some(Err(e)) => {
                warn!("supervisor: wait_container '{}' failed: {e}", self.name);
                None
            }
            None => None,
        }
    }
}

impl Killer for DockerKiller {
    async fn terminate(&self) {
        let _ = self
            .docker
            .stop_container(&self.name, Some(StopContainerOptions { t: 2 }))
            .await;
    }

    async fn force_kill(&self) {
        let _ = self
            .docker
            .remove_container(
                &self.name,
                Some(RemoveContainerOptions {
                    force: true,
                    ..Default::default()
                }),
            )
            .await;
    }
}
