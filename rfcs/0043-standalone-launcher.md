## Summary

[summary]: #summary

This RFC proposes a new system to launch Mina node along with its processes.

This new system indends to replace the way we currently launch the Mina node,
proposing a new standalone script (launcher), which launches Daemon, Prover, Verifier(s),
Libp2p helper and any other process that is or will be a part of Mina node.

## Motivation

[motivation]: #motivation

Daemon process is the single most complex part of Mina node, carying burden of maintaining the
node's view of the blockchain and largely orchestrating the other processes of Mina node.

Launching processes is a task that can be easily handled by a separate executable ("launcher") with all the logic
of launching, monitoring and configuring the processes to be made a part of this launcher executable.

## Design

[design]: #design

Launcher takes a single parameter `--config config.json` with configuration of the node.

TODO describe config format

Launcher launches each of the Mina node's processes, monitors their status and restarts them when necessary.

## Additional options

[options]: #options

If it's required for Launcher to be able to dynamically add and remove processes (as proposed e.g. in discussion [#9542](https://github.com/MinaProtocol/mina/discussions/9542)),
launcher may expose a simple HTTP API.

Instead of JSON config, a YAML config importing some subconfigs might be considered as a more flexible option.
