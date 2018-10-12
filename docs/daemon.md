# care and feeding of your Coda daemon

Right now the default config directory is hardcoded to `~/.current-config`. 
This will be fixed eventually. In the meantime, you can pass `-config-directory`
to the daemon to look there.

## How ports are used

## CLI args

The daemon has many options. If you run `coda daemon -h`, it will explain what
they are.

## Config file

The daemon will look for a `$CONF_DIR/daemon.json` on startup. That file should
be a single JSON object. These settings are overridden by their corresponding
command-line flags. These flags are supported in the config file:

- `external-port` int
- `client-port` int
- `propose` bool
- `txn-capacity` int
- `rest-port` int
- `peers` string list. this does not get overridden by `-peer` arguments.
  instead, `-peer` arguments are added to this list. this is only used for
  initial connection bootstrap.
