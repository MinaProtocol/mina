## Summary
Blocks containing a large number of zkApp commands have caused memory issues in the ITN. A *soft* solution has already been released (see `rfcs/0054-limit-zkapp-cmds-per-block.md`) which causes a BP node to reject zkApp transactions from its block candidate that exceed a preconfigured limit (set on either start-up, or through an authenticated GraphQL endpoint). However, we wish for a *hard* solution that will cause a node to reject any incoming block that has zkApp commands which exceed the limit.

## Motivation
Previously, there was a zkApp Softcap Limit that could be configured either on start-up of the mina node, or through an authenticated GraphQL endpoint. However, this is not safe enough as any block-producer running a node could just recompile the code and change the configuration, circumventing the zkApp command limit. Furthermore, the limit is *soft* in the sense that a mina node will still accept blocks which exceed the configured zkApp command limit. Therefore, another mechanism is required to ensure that any block producers who attempt to bypass the limit will not have their blocks accepted.

## Detailed design
The limit should be specified in the runtime config for maintainability and ease of release. Unlike in the softcap case, the limit needs to be implemented at the block application level, rather than the block production level, as this change impacts non-BP mina nodes, as well. One candidate for the location is the `create_diff` function in the `staged_ledger.ml`. There is already a `Validate_and_apply_transactions` section in the function that could be co-opted.

## Testing
A simple test would be to run two nodes in a local network, with different configurations. Have the first node be a BP without this fix, and another be a non-BP node with this fix (set the limit to zero). Firing an excessive amout of zkApp command transactions at the BP node will cause it to produce a block which exceeds the zkApp command limit. Consequently, the non-BP node should stay constant at its initial block-height.
