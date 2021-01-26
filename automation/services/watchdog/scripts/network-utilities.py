#!/usr/bin/env python3

import datetime
import timedelta
import json
import re
import subprocess

from kubernetes import client, config
import click


@click.group()
@click.option('--debug/--no-debug', default=False)
def cli(debug):
    pass


@cli.group()
def janitor():
    pass


@cli.group()
def watchdog():
    pass

###
# Commands for Testnet kubernetes resource cleanup
###


DEFAULT_K8S_CONFIG_PATH = "kube-config"
DEFAULT_CLEANUP_THRESHOLD = (60 * 60 * 24 * 7)  # 7 days

DEFAULT_CLEANUP_PATTERNS = []
DEFAULT_K8S_CONTEXTS = []


@janitor.command()
@click.option('--namespace-pattern',
              multiple=True,
              default=DEFAULT_CLEANUP_PATTERNS,
              help='regular expression expressing a list of namespace patterns to include in the cleanup operation')
@click.option('--cleanup-older-than',
              default=DEFAULT_CLEANUP_THRESHOLD,
              help='threshold in seconds over which to include discovered namespaces in cleanup')
@click.option('--k8s-context',
              multiple=True,
              default=DEFAULT_K8S_CONTEXTS,
              help='Kubernetes cluster context to scan for namespaces to cleanup')
@click.option('--kube-config-file',
              default=DEFAULT_K8S_CONFIG_PATH,
              help='Path to load Kubernetes config from')
def cleanup_namespace_resources(namespace_pattern, cleanup_older_than, k8s_context, kube_config_file):
    """Delete resources within target namespaces which have exceeded some AGE threshold."""

    for ctx in k8s_context:
        print("Processing Kubernetes context {context}...".format(context=ctx))

        config.load_kube_config(context=ctx, config_file=kube_config_file)
        v1 = client.CoreV1Api()
        response = v1.list_namespace()
        for pattern in namespace_pattern:
            print(
                "Checking cluster namespaces against pattern: {p}".format(p=pattern))

            regexp = re.compile(pattern)
            for ns in response.items:
                print("Namespace: {namespace}, creation_time: {createdAt}".format(
                    namespace=ns.metadata.name, createdAt=ns.metadata.creation_timestamp))

                # cleanup all namespace resources which match pattern and whose creation time is older than threshold
                if regexp.search(ns.metadata.name) and (ns.metadata.creation_timestamp <= now-timedelta(seconds=cleanup_older_than)):
                    print("Namespace [{namespace}] exceeds age of {age} seconds. Cleaning up resources...".format(
                        namespace=ns.metadata.name, age=cleanup_older_than))

                    command = "kubectl delete all --all -n {namespace}".format(
                        namespace=ns)
                    process = subprocess.Popen(
                        command.split(), stdout=subprocess.PIPE)
                    output, error = process.communicate()
                    if error:
                        print(error)
                    if output:
                        print(output)
                else:
                    print("Skipping Namespace {namespace}.".format(
                        namespace=ns.metadata.name))


if __name__ == "__main__":
    cli()
