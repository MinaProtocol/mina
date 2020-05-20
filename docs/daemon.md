# Care and feeding of your Coda daemon

Right now the default config directory is hardcoded to `~/.coda-config`.
This will be fixed eventually. In the meantime, you can pass `-config-directory`
to the daemon to look there.

## How ports are used

## CLI args

The daemon has many options. If you run `coda daemon -h`, it will explain what
they are.

## Config file

The daemon will look for a `$CONF_DIR/daemon.json` on startup. That file should
be a single JSON object containing the field `daemon: {...}`. These settings
are overridden by their corresponding command-line flags. See `coda daemon -h`
for more information about them.
These flags are supported in the `daemon` object of the config file:

- `client-port` int
- `libp2p-port` int
- `rest-port` int
- `block-producer-key` private-key-file
- `block-producer-pubkey` public-key-string
- `block-producer-password` string
- `coinbase-receiver` public-key-string
- `run-snark-worker` public-key-string
- `snark-worker-fee` int
- `peers` string list. This does not get overridden by `-peer` arguments.
  Instead, `-peer` arguments are added to this list.
- `work-selection` seq|rand Choose work sequentially (seq) or randomly (rand) \
            (default: seq)
- `work-reassignment-wait` int
- `log-received-blocks` bool
- `log-txn-pool-gossip` bool
- `log-snark-work-gossip` bool
- `log-block-creation` bool

## Environment variables

The daemon will read some environment variables on startup.

`CODA_CLIENT_TRUSTLIST` is a comma-separated list of CIDR masks, for example `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` would allow any client on an RFC1918 private network to control the daemon. This list can be edited with `coda advanced client-trustlist` commands.

There are other environment variables, but they aren't documented yet.
