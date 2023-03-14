# Openmina Testnet

This repository contains scripts and value files for deployning Openmina testnet
from Helm charts.

The Helm charts that are used are modified versions of the [Mina Helm
charts](https://github.com/Minaprotocol/mina/tree/develop/helm).

Testnet deployment consists of seed nodes, block producing nodes, snark worker
nodes, and plain nodes. Also it includes Openmina frontend application. All
resources are created in a namespace. Also for the frontend a specific node port
should be allocated.

Currently the following testnets are used:
- **Public testnet** uses the `testnet` namespace and shouldn't be
  modified/stopped unless approved by Juraj. It is accessible via port `31308`
  (e.g. http://1.k8.openmina.com:31308).
- **Bitswap testnet** uses the `bit-catchup-testnet` namespace and runs Mina
  node with new bitswap implementation. It is accessible via port `31310` (e.g.
  http://1.k8.openmina.com:31310).
- **Unoptimized testnet** uses the `unoptimized-testnet` namespace and runs Mina
  node with our optimizating modifications turned off. It is accessible via port
  `31311` (e.g. http://1.k8.openmina.com:31311).

It is also possible to deploy another testnets, using another namespace, and
choosing another (unique) node port.

## Deployment

You can use [deploy.sh] script to deploy/redeploy a testnet. You need to specify
what kinds of Mina nodes will be installed, using `--seeds`, `--producers`,
`--snark-workers` and `--nodes` options. Use `--frontend` to also install/update
frontend application. If the `--all` option is specified, it acts as all above
options are specified.

This will install a full testnet using `testnet-unoptimized` namespace:
``` sh
$ ./deploy deploy --all
```

To install/update optimized testnet, use the following:

``` sh
$ ./deploy deploy --all --optimized
```


To install a testnet in a different namespace (e.g. for testing purposes), use
the `--namespace` option. For the frontend application, you also need to specify
`--node-port` option:

``` sh
$ ./deploy deploy --all --namespace=my-testnet --node-port=31399
```

Note that the node port should be free (or used by the frontend deployed the
specified namespace).

Also, before the first deployment, the namespace should be configured by adding
needed `ConfigMap` and `Secret` resources (see #namespace-configuration).


## Linting

Before deploying an updated Helm chart, it is good to have it linted. This can
be done using this command:

``` sh
$ ./deploy.sh lint --all
```

## Namespace configuration

Before the testnet can be installed into an empty namespace, it should be
configured by creating some resources that are used by it.

There is a script [create-namespace.sh] that can be used to configure a new
namespace with common data. It will also ask you for a one-line description for
this namespace.

``` sh
$ ./create-namespace.sh <NAMESPACE> <NODE-PORT>
```

E.g. 

``` sh
$ ./create-namespace.sh testnet-my-testnet 31398
Please enter description for the new namespace, followed by ENTER:
Testnet for testing namespace creation

configmap/scripts created
secret/seed1-libp2p-secret created
secret/prod1-privkey-secret created
secret/prod2-privkey-secret created
secret/prod3-privkey-secret created
```

`

### Secrets

To specify peer ID for seed nodes, and private keys for block producers,
`Secret` resources are used. To create secrets from existing privkey files,
[create-secrets.sh] script can be used. For existing setup, the following
secrets should be created:

``` sh
$ ./create-secrets.sh --namespace=<namespace> \
   seed1-libp2p-secret=resources/seed1 \
   prod1-privkey-secret=resources/key-01 \
   prod2-privkey-secret=resources/key-02 \
   prod3-privkey-secret=resources/key-03
```

### Scripts

In the current testnet, a wrapper script is used, to unset unneeded environment
variables before launching Mina daemon. This script is populated to pods using
`ConfigMap` resource. To create it, run the following command: 

``` sh
$ kubectl --namespace=<namespace> create configmap scripts --from-file=scripts
```

This will create a `ConfigMap` resource `scripts` with key/value pairs for each
name/content of files containing in the directory `scripts`.
