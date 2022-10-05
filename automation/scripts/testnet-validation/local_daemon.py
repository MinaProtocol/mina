import docker
from kubernetes import client, config
import os
import subprocess
import click
import glob
import json
import random
import re
import sys
from pathlib import Path

# This script is designed to fetch relevant parameters from a running testnet
# and run a daemon locally that is correctly configured to connect to that testnet.
# Example Invocation:
# python3 scripts/testnet-validation/local_daemon.py run --working-directory ~/Desktop/config --coda-docker-image codaprotocol/coda-daemon:0.0.12-beta-rosetta-dockerfile-aec5631

SCRIPT_DIR = Path(__file__).parent.absolute()
config.load_kube_config()



@click.group()
@click.option('--debug/--no-debug', default=False)
def cli(debug):
    pass


def fetch_peers(namespace="default", v1=client.CoreV1Api()):
  # Load K8s config
  ret = v1.list_namespaced_pod(namespace=namespace)
  random.shuffle(ret.items)
  peers = ret.items[:3]

  peer_addresses = []
  for i in peers:
    # Run mina client status and get output
    command = f"kubectl exec --namespace={namespace} -c coda {i.metadata.name} mina client status"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()
    if error:
      print(error)
      sys.exit(1)
    if output:
      status_output = output.decode('utf8')

    # grep for:
    #   IP Address
    #   Gossip Port
    #   LibP2P Peer ID
    IP_Pattern = r"External IP:\s+(\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b)"
    gossip_port_pattern = r"Libp2p port:\s+(\b\d+\b)"
    libp2p_peerid_pattern = r"Libp2p PeerID:\s+(\b\w+\b)"

    ip_matches = re.search(IP_Pattern, status_output)
    port_matches = re.search(gossip_port_pattern, status_output)
    peerid_matches = re.search(libp2p_peerid_pattern, status_output)

    try:
      ip_address = ip_matches.groups()[0]
      gossip_port = port_matches.groups()[0]
      peerid = peerid_matches.groups()[0]
      peer_addresses.append(f"/ip4/{ip_address}/tcp/{gossip_port}/ipfs/{peerid}")
    except IndexError:
      print("The 'mina client status' output can't be parsed... \n\nSomething is Funky.")
      sys.exit(1)
  return peer_addresses


def fetch_daemon_json(working_directory, namespace="default", v1=client.CoreV1Api()):
  config_name = "seed-node-daemon-config"
  ret = v1.list_namespaced_config_map(namespace)
  for config in ret.items:
    if config.metadata.name == config_name:
      outpath = (working_directory / "daemon.json").absolute()
      outfile = open(outpath, "w")
      outfile.write(config.data["daemon.json"])
      print(f"Wrote daemon.json to {outpath}")


def run_docker(daemon_image, gossip_port, working_directory, peers):
  command = f"""
daemon \
  -external-port {gossip_port} \
  -generate-genesis-proof true \
  -config-dir /root/.mina-config \
  -config-file /tmp/daemon.json \
  -peer {peers[0]} \
  -peer {peers[2]} \
  -peer {peers[1]}
  """
  print(command)
  dClient = docker.from_env()
  container = dClient.containers.run(
    daemon_image,
    # entrypoint="bash -c",
    command=command,
    ports={f"{gossip_port}/tcp": gossip_port},
    volumes={working_directory.absolute(): {'bind': '/tmp', 'mode': 'rw'}},
    detach=True
  )
  print(container.logs())

@cli.command()
@click.option("--namespace", default="regeneration", help="The name of the testnet you'd like to connect to.")
@click.option("--gossip-port", default=10000, help="The port to expose on the Coda Daemon Docker Container.")
@click.option("--docker-image", default="codaprotocol/coda-daemon:latest", help="The Coda Daemon Docker Image to use.")
@click.option("--working-directory", default=".", help="The location to download temporary files to, namely the daemon.json")
def run(namespace, gossip_port, docker_image, working_directory):
  if working_directory == ".":
    working_directory = SCRIPT_DIR
  else:
    working_directory = Path(working_directory)

  addresses = fetch_peers(namespace)
  fetch_daemon_json(working_directory, namespace)

  run_docker(docker_image, gossip_port, working_directory, peers=addresses)




if __name__ == "__main__":
    cli()