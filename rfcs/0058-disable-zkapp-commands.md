## Summary
*Soft* and *hard* limits for zkApp commands have already been implemented (see `rfcs/0054-limit-zkapp-cmds-per-block.md` and `0057-hardcap-zkapp-commands.md`). However, both of these changes still permit the inclusion of zkApp commands into the Mina node's mempool, and their dissemination via gossiping. If we wish to truly disable zkApp commands in the network then a more exhaustive exclusion is required.

## Detailed design
The change should sit behind a compile-time flag (similar to the ITN `itn_features`). Changing [this code](https://github.com/MinaProtocol/mina/blob/03c403e2c1e57a36de4e5b92f75856c825cb7e7e/src/lib/mina_base/user_command.ml#L405) so that all zkApp commands are treated as malformed will prevent them from being added to the mempool.

## Testing
The change can be tested by switching on the flag and firing zkApp commands at a node. The node should not accept any of the zkApp commands, nor should any be gossiped to other nodes in the network, which can be checked by querying the GraphQL endpoints.
