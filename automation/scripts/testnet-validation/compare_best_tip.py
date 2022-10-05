#!/usr/bin/env python3

# script to find common best-tip prefix over a list of nodes using GraphQL query

import os
import sys
import json
import click
import subprocess
import requests
import time
import logging
import random
import backoff 

from graphviz import Digraph

from concurrent.futures import ThreadPoolExecutor

from kubernetes import client, config
from kubernetes.stream import stream

from best_tip_trie import Block, BestTipTrie

import CodaClient

import sys
sys.setrecursionlimit(1500)

@click.command()
@click.option('--namespace', default="regeneration", help='Namespace to Query.')
@click.option('--remote-graphql-port', default=3085, help='Remote GraphQL Port to Query.')
@click.option('--show-graph/--hide-graph', default=True, help='automatically open the graph image')
def check(namespace, remote_graphql_port, show_graph):
  '''
  A quick hack script to tunnel into all nodes in a Testnet and query their GraphQL Endpoints. 
  This would be better as a k8s job with direct access, but the GraphQL endpoints are unsafe. 
  '''
  logging.basicConfig(stream=sys.stdout, level=logging.INFO)
  logger = logging.getLogger()

  config.load_kube_config()

  best_tip_trie = BestTipTrie()

  v1 = client.CoreV1Api()
  pods = v1.list_namespaced_pod(namespace)
  items = pods.items
  random.shuffle(items)

  def process_pod(args):
    (i, pod) = args
    if pod.metadata.namespace == namespace and ('block-producer' in pod.metadata.name or 'snark-coordinator' in pod.metadata.name):
      logger.info("Processing {}".format(pod.metadata.name))
      # Set up Port Forward
      logger.debug("Setting up Port Forward")
      
      @backoff.on_exception(backoff.expo,
                      (requests.exceptions.Timeout,
                      requests.exceptions.ConnectionError),
                      max_tries=2)
      def doit():
        local_port = remote_graphql_port + i + 1
        command = "kubectl port-forward --namespace {} {} {}:{}".format(pod.metadata.namespace, pod.metadata.name, local_port, remote_graphql_port)
        logger.debug("Running Bash Command: {}".format(command))
        proc = subprocess.Popen(["bash", "-c", command],
                              stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT)
        
        time.sleep(5)

        try: 
          return get_best_chain(local_port)
        finally:
          terminate_process(proc)
        
      try:
        result = doit()
      except requests.exceptions.ConnectionError:
        logging.error("Error fetching chain for {}".format(pod.metadata.name))
        return

      if result['data']['bestChain'] == None: 
        logging.error("No Best Tip for {}".format(pod.metadata.name))
        return
      logger.info("Got Response from {}".format(pod.metadata.name))
      logger.debug("Contents of Response: {}".format(result))

      chain = list(map(lambda a: a["stateHash"], result['data']['bestChain']))

      return (chain, pod)
      
  with ThreadPoolExecutor(max_workers=12) as pool:
    for result in pool.map(process_pod, enumerate(items)):
      if result:
        chain, pod = result
        best_tip_trie.insert(chain, pod.metadata.name[:-16])

  forks = list((key, node.children) for (key, node) in best_tip_trie.forks())
  items = list(([hash[-8:] for hash in key], node.value) for (key, node) in best_tip_trie.items())
  prefix = best_tip_trie.prefix()
  trie_root = best_tip_trie.root
  print(trie_root)
  
  # print(prefix)
  # print("Items:")
  # for item in items:
  #   print(item)
  print("Processing Forks...")
  graph = Digraph(comment='The Round Table', format='png', strict=True)
  # Create graph root
  graph.node("root", "root", color="black")
  graph.edge_attr.update(dir="back")
  print(len(forks))
  
  render_fork(graph, trie_root)
  #Connect fork root to graph root
  graph.edge("root", trie_root.hash)
  #print(graph.source)
  graph.render(view=show_graph)

def render_fork(graph, root):
  color = "white"
  if len(root.labels) > 0:
    for label in root.labels:
      graph.node(label, label, color="blue")
      graph.edge(label, root.hash, color="blue")
    color = "blue"
  if root.hash == None:
    root.hash = "root"
  elif "\t"+root.hash not in graph.body:
    graph.node(root.hash, root.hash[-8:], color=color)
  for child in root.children.values():
    graph.node(child.hash, child.hash[-8:], color=color)
    graph.edge(root.hash, child.hash)
    render_fork(graph, child)
  

      

class CustomError(Exception):     
  pass

@backoff.on_exception(backoff.expo,
                      (requests.exceptions.Timeout,
                      requests.exceptions.ConnectionError),
                      max_tries=3)
def get_best_chain(port):
  coda = CodaClient.Client (graphql_host="localhost", graphql_port=port)
  result = coda._send_query (query="query bestChainQuery { bestChain { stateHash } }")
  return result


def terminate_process(proc):
  proc.terminate()
  try:
    outs, _ = proc.communicate(timeout=0.2)
    #print('== subprocess exited with rc =', proc.returncode)
    #print(outs.decode('utf-8'))
  except subprocess.TimeoutExpired:
    logger.error('subprocess did not terminate in time')
if __name__ == '__main__':
  check()
