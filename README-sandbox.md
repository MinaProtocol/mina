Setting up a sandbox network
=============================

This instruction explains step by step, how to go about setting up a
private Mina network. It may be done for many purposes from testing the
code on `develop` branch, through creating reproducible environments to
run tests in to testing the capabilities of the system in the privacy
of one's own house. Most of these steps need to be done just once and
then many blockchains can be created using the same input data.

Note that before you begin ensure you have the `mina.exe` set up as an alias
or a PATH variable.

Generating keys
---------------

Our network needs users to hold and transfer assets as well as to run
node(s). In this file we describe a single-node network for the sake of
simplicity, but adding more nodes to the network shouldn't be that
difficult.

To run the network we'll need at least 3 key pairs. One of them will
identify and authenticate the daemon in the p2p network. The other two
will be used for Mina accounts of the block producer and of the SNARK
worker. Let's put them in `keys` directory:

```shell
$ mkdir -p keys
```

Before creating the keys it makes sense to set up some environment
variables:

```shell
$ export MINA_LIBP2P_PASS=
$ export MINA_PRIVKEY_PASS=
```

These variables hold passwords protecting private keys. If they are
not set, the node will ask for those passwords before creating the
keys. It won't be able to access these keys without these variables
set. User is free to put any passwords there, however, in development
or testing setups it's not really necessary, as those networks don't
hold any real assets anyway. These settings are essential for the
security of mainnet nodes, though, and that's why they're mandatory.

```shell
$ mina libp2p generate-keypair --privkey-path keys/node.key
```

This command (which depends on environment variables set up by Nix)
creates a p2p key pair for the daemon, which will identify and
authenticate the node in the p2p network. In a single-network setup it
might not be the most relevant, but it's required nonetheless.

Then we need key pairs for the block producer(s) and SNARK worker(s):

```shell
$ mina advanced generate-keypair --privkey-path keys/block-producer.key
$ mina advanced generate-keypair --privkey-path keys/snark-producer.key
$ chmod -R 0700 keys
```

Don't forget to set key files' permissions to `0700` or else the
client will refuse to import them. Note that the command to generate
these keys is different. That's because these are not p2p keys, but
Mina account keys, which use a different format.

Additionally, the block producer's key should be copied to the `wallets`
directory in the node's config dir. This directory doesn't exist yet
probably, so one can create it by hand or use the following command to
set up the config directory. The filename should be identical to the
block producer's public key.

```shell
$ mina accounts import --privkey-path keys/block-producer.key --config-directory .mina-config
```

Of course we are free to produce more keys for regular users of the
network or if we wish to have more nodes/block producers/snarkers
etc. Note that we need to generate those keys before the next step if
we wish to give those accounts some initial balance. Otherwise we
might as well create them later.

The Genesis Ledger
--------------

A skeleton genesis ledger looks like this:

```genesis-ledger.json
{
  "genesis": {
    "genesis_state_timestamp": "2022-10-20T12:00:00Z"
  },
  "ledger": {
    "name": "sandbox",
    "accounts": [ ]
  }
}
```

Now we need to populate the `.ledger.accounts` section with users of
the network that we want to hold some initial balance. At the very
least we need to put block producer's account here so that he has a
stake necessary to produce blocks. Each account in the genesis ledger
is represented by an object with the following data:

```genesis-ledger.json
      {
        "pk": "<the public key>",
        "balance": "<the amount of mina as string with up to 9 decimal places>",
        "delegate": "<the pub key of the delegate or null>",
        "sk": null
      }
```

The public keys to put into the file may be taken from the output of
the `generate-keypair` command or, if we didn't save them, from `.pub`
file created next to each private key file.

Additionally, many other configuration options may be set in this file.
In particular it's possible to override the defaults compiled into the
binary using the `dune` profiles. Explaining these options is, however,
outside the scope of this instruction.

The `genesis_state_timestamp` should be within a few minutes of when you intend
to start the node.

Starting the node
-----------------

Before starting the node, it's useful to set up one more
environment variable, as it might be required in some setups:

```shell
$ export MINA_ROSETTA_MAX_DB_POOL_SIZE=128
```

Assuming `mina` CLI is in your path, run the following command, 
making sure that required environment variables are properly set
(by Nix shell or otherwise):

```shell
$ mina daemon \
    --libp2p-keypair keys/node.key \
    --config-directory ./.mina-config \
    --config-file genesis-ledger.json \
    --proof-level none \
    --block-producer-pubkey "$(cat keys/block-producer.key.pub)" \
    --run-snark-worker "$(cat keys/snark-producer.key.pub)" \
    --demo-mode \
    --seed
```

Note that we don't pass any peers list; instead we pass the `--seed`
option.  It tells the node not to shut down when it does not find any
peers to connect to, because its purpose is to create a fresh
blockchain.

`--config-directory` can be omitted, in which case it defaults to
`~/.mina-config`. You should pass it if you already have another
blockchain's data stored in there. In case the daemon fails, 
complaining about write access to this directory, try providing an
absolute path rather than relative one.

The consensus algorithm that Mina uses requires that blocks are being
produced constantly and if there's too long a delay, the chain will
halt. For that reason for every restart of the daemon, a new
blockchain should be started (because there are no other nodes to keep
it running while our node is out, as it would be the case in a normal
network). Therefore, when reusing the same config directory over and
over again, it's important to remove it before each restart. Otherwise
the daemon will try to pick up the old blockchain and will get stuck
on it.

`--demo-mode` option tells the daemon to assume it's already synced
with the network (because in this case *it is* the entire network).
Without this option the daemon will exit after approximately 30 minutes
of being unable to connect to other nodes.

If the block producer's key wasn't copied over to the wallet
previously, the following error will appear:

```log
Cannot open file: ./.mina-config/wallets/store/B62qqhZY2AsNuPEAHVnk8sn6dTW7Mpge5Xsn85EPii6hDPNVzJP437S. Error: No such file or directory
```

If this happens, simply copy the block producer's key to the given
location and restart the node.

At this point the node should start producing blocks every a
certain amount of time, which depends on the configuration. For
the `dev` profile the default is 2s. Note that the node will
produce blocks even if there are no transactions to include.
This is because regular block production is considered a measure
of the quality of the blockchain.

Before you transfer funds from an account, it must be imported
(see above) and activated first. The activation is performed with
the following command:

```shell
$ mina accounts unlock --public-key "<the public key>"
```

After that the unlocked account can start transferring their funds.
