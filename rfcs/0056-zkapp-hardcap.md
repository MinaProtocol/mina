## Summary
Blocks containing a large number of zkApp commands have caused memory issues in the ITN. A **soft** solution has already been released (see rfcs/0054-limit-zkapp-cmds-per-block.md) which causes a BP node to reject zkApp transactions from its block that exceed a preconfigured limit (set on either start-up or through an authenticated GraphQL endpoint). However, we wish for a **hard** solution that will cause a node to reject any incoming block that has zkApp commands which exceed the limit.

## Motivation
Previously, there was a zkApp Softcap Limit that could be configured either on start-up of the mina node, or through an authenticated GraphQL endpoint. However, this is not safe enough as any block-producer running a node could just recompile the code and change the configuration, circumventing the zkApp command limit. Furthermore, the limit is **soft** in the sense that a mina node will still accept blocks which exceed the configured zkApp command limit. Therefore, another mechanism is required to ensure that any block producers who attempt to bypass the limit will not have their blocks accepted.

## Detailed design


## Drawbacks

## Rationale and alternatives

## Prior art

## Unresolved questions

## Testing

