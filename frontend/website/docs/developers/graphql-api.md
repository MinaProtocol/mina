# GraphQL API

!!! warning
    Coda APIs are still under construction, so these endpoints may change

### Basic setup:

1. Start your daemon with the `-rest-port <port>` flag. For example: `coda.exe daemon -rest-port 8000`
2. Connect your graphql client to `[localhost:<port>/graphql](http://localhost:8000/graphql)` (with `<port>` replaced with the port you used above.
3. [Optional] If you want to use an existing wallet with graphql, "import" it using the following: `coda.exe daemon -propose-key <port> -unsafe-track-propose-key`. Note: this is a temporary workaround that removes password protection from the private key file. You can always create a new wallet using the `addWallet` mutation. 
4. Look at the docs in the graphql schema [here](todo)

Warning: By default, the graphql port is bound to localhost, but if you for some reason decide to expose it to the internet, be careful! Someone with access to this api can send coda from your wallets.