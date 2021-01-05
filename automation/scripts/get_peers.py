
import os
import sys

def main():
  namespace = sys.argv[1]
  pods = exec_shell('kubectl get pods -n ' + namespace)

  pods = [ p for p in pods.split('\n') if 'whale' in p or 'seed' in p or 'fish' in p ]
  pods = [ p.split(' ')[0] for p in pods ]

  statuses = [ get_status(namespace, pod) for pod in pods ]

  statuses = [ s for s in statuses if len(s) > 0 ]

  select = lambda status, prop: [ s for s in status.split('\n') if prop in s ][0].split(':')[1].strip()

  ports = [ select(status, 'Libp2p port') for status in statuses ]
  ips = [ select(status, 'External IP') for status in statuses ]
  peerIDs = [ select(status, 'Libp2p PeerID') for status in statuses ]

  peers = [ '/ip4/' + ip + '/tcp/' + port + '/p2p/' + peer_id for (ip,port,peer_id) in zip(ips, ports, peerIDs) ]

  with open('terraform/testnets/' + namespace + '/peers.txt', 'w') as f:
    f.write('\n'.join(peers))

def get_status(namespace, pod):
  if 'seed' in pod:
    return exec_shell('kubectl exec -n ' + namespace + ' -c seed -i ' + pod + ' -- coda client status')
  else:
    return exec_shell('kubectl exec -n ' + namespace + ' -c coda -i ' + pod + ' -- coda client status')


def exec_shell(cmd):
  stream = os.popen(cmd)
  output = stream.read()
  return output

main()
