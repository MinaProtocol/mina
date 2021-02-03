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
import yaml
from pathlib import Path

# This script is designed to fetch relevant parameters from a running testnet
# and run a Coda helm chart against that testnet.
# Example Invocation:
# python3 scripts/testnet-validation/helm_deploy.py run --working-directory ~/Desktop/config --coda-docker-image codaprotocol/coda-daemon:0.0.12-beta-rosetta-dockerfile-aec5631

SCRIPT_DIR = Path(__file__).parent.absolute()
config.load_kube_config()



@click.group()
@click.option('--debug/--no-debug', default=False)
def cli(debug):
    pass


def fetch_peers(namespace="default", v1=client.CoreV1Api()):
  # Load K8s config
  ret = v1.list_namespaced_pod(namespace=namespace)
  filtered_pods = filter(lambda pod: "block-producer" in pod.metadata.name, ret.items)
  peers = random.sample(list(filtered_pods), 3)
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
    else:
      raise Exception("No Status Output...")

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

def fetch_helm_values(namespace="default", release_name=None):
  if not release_name:
    raise Exception("Please pass a release name.")

  # run helm get values <release_name> 
  command = f"helm get values --namespace {namespace} {release_name}"
  process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
  output, error = process.communicate()
  if error:
    print(error)
    sys.exit(1)
  if output:
    values_raw = output.decode('utf8')
    values = yaml.safe_load(values_raw)
    return values
  else:
    raise Exception("No values retrieved, something is wrong!")

    

  

def fetch_daemon_json(working_directory, namespace="default", v1=client.CoreV1Api()):
  config_name = "seed-node-daemon-config"
  ret = v1.list_namespaced_config_map(namespace)
  for config in ret.items:
    if config.metadata.name == config_name:
      outpath = (working_directory / "daemon.json").absolute()
      outfile = open(outpath, "w")
      outfile.write(config.data["daemon.json"])
      print(f"Wrote daemon.json to {outpath}")

def helm_install(namespace, overrides_file, chart_path, release_name):
  command = f"helm install --values {overrides_file} {release_name} {chart_path}"
  process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
  output, error = process.communicate()
  if error:
    print(error)
    sys.exit(1)
  if output:
    command_result = output.decode('utf8')
    return command_result
  else:
    raise Exception("No Command Output... Something is wrong.")


@cli.command()
@click.option("--namespace", default="regeneration", help="The name of the testnet you'd like to connect to.")
@click.option("--values-file", default=None, help="An Optional values.yaml, used to override chart defaults.")
@click.option("--release-name", default=None, help="The name of the release to pull values from.")
@click.option("--working-directory", default=".", help="The location to download temporary files to, namely the daemon.json")
def run(namespace, values_file, release_name, working_directory):
  if working_directory == ".":
    working_directory = SCRIPT_DIR
  else:
    working_directory = Path(working_directory)

  if not release_name:
    raise Exception("Please enter a release name when invoking this script.")

  # Fetch Peers
  addresses = fetch_peers(namespace)
  # Fetch Helm Release Values
  values = fetch_helm_values(namespace, release_name)
  # Parse out coda.runtimeGenesis and prep overrides
  overrides = {
    "coda":{
      "runtimeConfig": values["coda"]["runtimeConfig"],
      "seedPeers": addresses
    }
  }
  # Write overrides to file
  overrides_file = working_directory / "overrides.yaml"
  with open(overrides_file, "w") as outfile:
    yaml.dump(overrides, outfile)

  #run_docker(docker_image, gossip_port, working_directory, peers=addresses)

  # `helm install` with merged values.yaml to specified namespace
  chart_path = "/Users/connerswann/code/coda-automation/helm/archive-node"
  output = helm_install(namespace, overrides_file.absolute(), chart_path, "test-archive")


if __name__ == "__main__":
    cli()