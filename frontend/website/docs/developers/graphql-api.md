# GraphQL API

!!! warning
    - Coda APIs are still under construction, so these endpoints may change
    - By default, the GraphQL port is bound to localhost, but if you for some reason decide to expose it to the internet, be careful! Someone with access to this api can send coda from your wallets.

### Basic setup:

1. Start your daemon as usual. By default an http server is available at port 3085 (configurable with `-rest-port`).
2. Connect your GraphQL client to `http://localhost:3085/graphql`.
3. [Optional] If you want to use an existing keypair with GraphQL, first import from the command line it using the following: `coda advanced import -privkey-path <keyfile>`.
4. Open your web browser to `http://localhost:3085/graphql` to play with the api using [GraphiQL](https://github.com/graphql/graphiql)
5. Look at the <a href="/docs/graphql/" target="_blank">GraphQL schema docs</a>
