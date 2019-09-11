# GraphQL API

!!! warning
    - Coda APIs are still under construction, so these endpoints may change
    - By default, the GraphQL port is bound to localhost, but if you for some reason decide to expose it to the internet, be careful! Someone with access to this api can send coda from your wallets.

### Basic setup:

1. Start your daemon as usual. By default an http server is available at port 3085 (configurable with `-rest-port`).
2. Connect your GraphQL client to `http://localhost:3085/graphql` or open it in your browser to use [GraphiQL](https://github.com/graphql/graphiql)
3. [Optional] If you want to use an existing keypair with GraphQL, first import it from the command line using the following: `coda advanced import -privkey-path <keyfile>`.
4. Look at the <a href="/docs/graphql/" target="_blank">GraphQL schema docs</a>
