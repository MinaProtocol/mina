# RFC: Archive Node API

# Context and Scope

## Goals

- Provide a performant and reliable GraphQL API to expose data related to events/actions for SnarkyJS/zkApps
- Data is retrieved from an existing Mina Archive Node (Postgres) but also allows support for other data sources (e.g. MongoDB)
- Allow architecture to be run in server-full and serverless infrastructure providers.
- Ensure easy integration with SnarkyJS library by following the interfaces SnarkyJS expects.
- Provide a flexible and extensible design that can be easily modified to accommodate future requirements.
- Allow for efficient and secure data access.

## Roadmap

This RFC currently addresses the first phase out of 3 planned phases. To be more transparent in what is being addressed, each phase will be outlined to give proper scope expectations in this RFC.

- **Phase 1**
  Build a **minimal GraphQL API** that an Archive Node operator can run **to expose the minimum set of data required currently by SnarkyJS/zkApps — i.e. events & actions, from a PostgreSQL archive node database**. This will run on traditional server infrastructure.
- **Phase 2**
  Support the ability to host this on **serverless infrastructure.** This would allow the Archive Node API to be run on serverless infra such as Cloudflare Functions for near 100% uptime, geo-distribution, ‘infinite’ scaling, and zero infra maintenance.
- **Phase 3**
  Update Archive Node API to **expose the full data set available** on an archive node.

As noted, this RFC addresses **Phase 1** from the current roadmap. Concretely, this includes building a GraphQL server that can connect to a Postgres DB and expose information related to events/actions to be ingested by SnarkyJS/zkApps. One important note is that this server is _not_ included as part of the Mina daemon client. The server will be a standalone TypeScript server that is run completely separately from the Mina daemon. The reasoning is to later support serverless environments where the Mina daemon cannot run. The server can be lightweight in its design and resources compared to adding additional functionality to the Mina daemon.

## Design and Architecture

### Server Technologies

The GraphQL server will be built on top of [GraphQL Yoga](https://the-guild.dev/graphql/yoga-server), a fully-featured GraphQL Server focusing on easy setup, performance and great developer experience. GraphQL Yoga is a high-speed server compared to other GraphQL servers in the ecosystem. Looking at the [collected](https://github.com/MartinMinkov/node-graphql-benchmarks) [benchmarks](https://github.com/graphql-crystal/benchmarks) of various GraphQL libraries, GraphQL Yoga stands as one of the highest-performing servers currently available for JavaScript. In addition to being one of the highest-performance servers, the documentation and user experience provided by GraphQL Yoga are regarded as very high quality. Many features come with GraphQL Yoga that we could take advantage of, such as caching, logging and debugging, batching, plugins, etc. Finally, it has easy integrations for serverless architectures like [Cloudflare workers](https://the-guild.dev/graphql/yoga-server/docs/integrations/integration-with-cloudflare-workers) and other serverless environments, which allows the server to scale easily. GraphQL Yoga is built around W3C Request/Response, supported in all significant serverless/worker/"server-full" JavaScript environments.

### Trade-offs between GraphQL Yoga and other GraphQL servers

- _Apollo Server:_ Apollo Server is another popular GraphQL server many large companies use. It offers many advanced features, such as caching and performance optimization. The issue with Apollo Server is that it needs a better story for deploying to serverless environments for our use case. There are existing libraries to deploy to AWS specifically, but other environments like Cloudflare workers have pushed aside and let the community sort it out. Additionally, there is a performance cost of choosing Apollo Server, as seen by the existing benchmarks.
- _Hasura:_ Hasura is a solution to build a GraphQL API on top of an existing data store such as Postgres, MongoDB, etc. The issue with Hasura in our use case is that our Archive Node schema is complicated and needs to follow the normal use case patterns we want to access. We can define a GraphQL schema to tailor for its use case instead of trying to work with an existing schema that might be harder to work with in the long term.
- _Other Express-based servers:_ Other GraphQL servers in the Express ecosystem offer simplicity and minimal configuration. However, when looking at the benchmarks above, GraphQL Yoga has a clear performance win, in addition to also having a minimal configuration as well.

### Trade-offs between using an ORM and pure SQL for Postgres (Archive Node)

ORMs like TypeORM and Prisma provide an abstraction layer on top of the database, making it easier to interact with the data and write complex queries. While this gives good developer experience for most use cases, the Archive Node SQL schema is rather complex. Having more control over the raw SQL being executed is likely more performant than the SQL produced by ORM tools. To get events and actions data, GraphQL resolvers likely have to make many complicated JOIN queries or call multiple SQL queries to stitch together data. Performance has not been measured for ORMs vs pure SQL, but it is easier to optimize raw SQL when performance problems arise. For these reasons, starting the project with raw SQL for the Archive Node is preferred. A separate argument could be made for different data stores and schemas (e.g. MongoDB) where it could be simpler to query. It should be left to the individual database adapter to choose whether an ORM-like tool would benefit from fetching from the data store. However, raw SQL should still be used for the Archive Node adapter.

### Trade-offs between using GraphQL vs REST

The decision to use GraphQL over REST has multiple reasons behind the decision.

1. The Mina daemon currently uses GraphQL, so sticking to a technology consistent with the rest of our tech stack makes sense from a knowledge base perspective amongst the internal team and external developers.
2. GraphQL offers a schema which clearly defines the data that is returned by the server. This makes the server easy to use as the schema is clearly defined in terms of functionality offered and is self-documenting. Alternatively, we would have to incorporate additional tools to create documentation for all endpoints if REST was adopted.
3. GraphQL lets developers consuming the API decide what data they want to be fetched. GraphQL can omit fields in the returned response if the developer consuming the API does not need them. This saves on bandwidth since the server is returning only necessary information.
4. GraphQL gives a typesafe way to communicate with the TypeScript server. Alternatively, REST returns some output that is not defined other than by documentation. GraphQL must adhere to the defined schema, which gives a contract of what data will be returned.

## GraphQL Schema

There are two main approaches for defining a GraphQL schema: the Schema Definition Language (SDL) and a code-first approach.

The SDL approach involves defining the schema using GraphQL's syntax as a string or file. This approach has the advantage of being self-documenting, as the schema definition is human-readable and easy to understand. It also allows for easy collaboration, as the schema can be version-controlled and reviewed by multiple parties. Additionally, the SDL approach allows easy integration with existing tools and libraries that work with GraphQL schemas, such as `[graphql-code-generator](https://github.com/dotansimha/graphql-code-generator)`, which generates types and resolvers based on the schema definition. This gives type safety in our GraphQL resolvers, which should reduce runtime bugs.

The code-first approach involves defining the schema using code, usually in the same language as the server implementation. This approach has the advantage of being more flexible and dynamic, as the schema can be generated programmatically, and the schema definition is closer to the actual implementation. The code-first approach also allows easy integration with existing codebases, as the schema definition can be automatically generated from existing classes, methods, and fields.

In summary, the SDL approach has advantages such as being self-documenting, easy to understand, and easy to collaborate. In contrast, the code-first approach has advantages such as being more flexible, dynamic, and easy to integrate with existing codebases. For a project where the schema is starting rather simply (just supporting queries for events and actions), and the more complicated parts are around operation and querying data stores, the schema should be defined in SDL format where readability and self-documentation are prioritized rather than customizability. A code-first approach can be adopted if the schema grows in complexity, but it will stay relatively simple in the current implementation.

The GraphQL schema should support whatever data that SnarkyJS needs to ingest. Given the current requirements of Phase 1 of the roadmap, it is only necessary to fetch events and actions from the archive node. Thus, our schema can have two queries, in the simplest case, `Events` and `Actions`. A prototype schema is shown below for Phase 1. As discussed below, the schema can grow in complexity if more features are added.

As for security, the server will only offer queries and no mutations to change state. This means that the server will be **\*\*\*\***\*\***\*\*\*\***read-only**\*\*\*\***\*\***\*\*\*\*** and have no potential to change the state of a database. In addition, a node operator can define a proxy to ensure that only queries that have been validated to be safe are forwarded to the server. The server itself will allow a node operator to specify a CORS header, allowing the node operator to deny requests from origins they do not allow. Optionally, they can allow all origins; it is up to the node operator and their preferred way of deployment.

As a final point, as the Archive Node API reaches the later stages to expose more information from the Archive Node, the schema should stay separate from the Archive Node SQL schema. The GraphQL schema should be defined to fit the use case and access patterns that SnarkyJS requires to ingest event and action data rather than being a mapping of the SQL data.

## Fetching Events & Actions

As background context, Ethereum events are logged as soon as a transaction calls the contract, and the transaction is mined into a block. Additionally, there are [multiple ways](https://web3js.readthedocs.io/en/v1.8.1/web3-eth-contract.html#getpastevents) to filter events to get a more precise dataset needed for applications. Indexes can filter events, block height ranges (greater than or equal to the height specified), earliest and latest blocks, and specific event data values. The data returned by Ethereum events contain helpful data, most notably the event data itself, transaction hash, block height and hash, address, etc.

Given the current ecosystem, it’s important that the Archive Node API can return similar sets of data to satisfy the expectations of developers from other blockchains. Thus, in addition to supporting fetching events & actions from the Archive Node, the GraphQL API should support returning additional data like the fields mentioned above if the client requests them.

The Postgres Archive Node stores all the data necessary to fulfill these expectations; it is only a matter of engineering effort to ensure that the GraphQL API can resolve all requested data. Additionally, other database adapters should mirror returning the same data. The GraphQL API should support filtering events by certain preconditions. These preconditions can be [filtered by index in the events object](https://github.com/o1-labs/snarkyjs/issues/248#issuecomment-1172474317), specific values, block height, and block status. Blocks in the Archive Node have an [enum](https://github.com/MinaProtocol/mina/blob/d0aac4d43eca7efcee99bb156f7420af3be04941/src/app/archive/create_schema.sql#L133) defined, indicating their status as `canonical`, `orphaned`, or `pending`. Blocks that are `pending` are turned into `canonical` status after 290 blocks are added, and there is a path from the tip through that block to a canonical block.

These features can be added incrementally if time is a constraint but should be added given this is the feature set that developers are used to with events from Ethereum.

One issue with this design is deciding how to return data from the tip of the network. At the tip of the network, each block producer submits their block to be included in the Mina network. Because Mina has weaker finality, it is difficult to know which block should be returned when querying for event/action data. The OCaml Mina daemon uses a selection algorithm to estimate the chain strength of each submitted block and then decides which block to move forward with. One solution could be porting over the selection algorithm to TypeScript and emulating the same algorithm to decide which block to return at the tip of the network. However, this does not work as the Archive Node database currently doesn’t store the data needed to run the selection algorithm that the Mina daemon has access to (mainly `last_vrf_output` and `sub_window_densities`).

Due to not knowing what block to return at the tip of the network, the Phase 1 implementation of the server will return _all_ blocks at the tip of the network. If all the blocks contain the same transaction data, there is a high probability that the event/action data will be persisted in the network. In the rare case where some blocks contain the event/action data and some do not, we let the developer using this API handle this case for themselves (e.g. wait for additional blocks to gain confidence in finality). This issue of deciding what to return at the tip of the network only happens at the maximum block height. All blocks below the height of the network will have one block returned and will avoid this issue. The need for this data has been raised to the current maintainers of the archive node, and we anticipate it will be possible for it to be added to the database schema in the future. Once the Archive Node includes `last_vrf_output` and `sub_window_densities` into its schema, the selection algorithm can be implemented later to solve this issue.

It’s important to note that this issue is present because of missing data in the Archive Node schema. If it is possible to get the best tip block from the client (if node operators can get this data in their deployments), the API should return that block instead.

## GraphQL Queries

Given the Phase 1 requirements, it is only necessary to construct two GraphQL queries, one to fetch events and the other to fetch actions. However, there is more complexity involved when it comes to returning data from the archive node. Given the discussion in **Fetching Events & Actions**, there should be additional features added to the GraphQL queries for returning more contextual data and filtering options.

The GraphQL schema should stay as simple as possible during Phase 1. Thus, there should still be only two queries implemented in the initial stage, but these queries should take input parameters for filter options. It is up to the resolvers to return the data requested by the input parameters.

```graphql
enum BlockStatusFilter {
  ALL
  PENDING
  CANONICAL
}

input EventFilterOptionsInput {
  address: String!
  tokenId: String
  status: BlockStatusFilter
  to: Int
  from: Int
}

type EventData {
  index: String!
  data: [String]!
}

type ActionData {
  data: String!
}

type BlockInfo {
  height: Int!
  stateHash: String!
  parentHash: String!
  ledgerHash: String!
  chainStatus: String!
  timestamp: String!
  globalSlotSinceHardfork: Int!
  globalSlotSinceGenesis: Int!
  distanceFromMaxBlockHeight: Int!
}

type TransactionInfo {
  status: String!
  hash: String!
  memo: String!
  authorizationKind: String!
}

type EventOutput {
  blockInfo: BlockInfo
  transactionInfo: TransactionInfo
  eventData: [EventData]
}

type ActionOutput {
  blockInfo: BlockInfo
  transactionInfo: TransactionInfo
  eventData: [ActionData]
}

type Query {
  events(input: EventFilterOptionsInput!): [EventOutput]!
  actions(input: EventFilterOptionsInput!): [ActionData]!
}
```

This defines an input type for getting events based on the address, block status, and block heights. These input parameters are optional, and the GraphQL resolvers are responsible for the filtering. The only required parameter should be the address field, and the default behaviour is fetching the latest events by a predefined limit. The address field is the address of the zkApp we want to query events for. The block status filter defines whether we want to get blocks that are in the canonical chain or are in the pending state (290 blocks behind the current tip). We also define to and from fields, allowing filters based on block ranges. The user can specify a range in terms of block heights.

Finally, this API is read-only, so mutations will not be defined.

## Database Adapters

Since node operators may be operating databases other than PostgreSQL (like MongoDB), there should be some thought on adding support for defining custom database adapters to define the fetching logic for events and actions.

One such method is defining an adapter database system for the GraphQL server and then passing the adapter to the GraphQL server. A database adapter should be defined as an interface that has methods/functions that define how to query the specific database. Then, a node developer can pass their database adapter into the server, and the server code does not have to change. Only the database adapter defines how the data should be fetched for the specific database.

For example, an interface can be defined as:

```tsx
export interface DatabaseAdapter {
  getEvents(input: EventFilterOptionsInput): Promise<Events>;
  getActions(input: EventFilterOptionsInput): Promise<Actions>;
}

class ArchiveNodeAdapter implements DatabaseAdapter {
    private client: postgres.Sql;

    constructor(connectionString: string | undefined) {
			...
		}

	  async getEvents(input: EventFilterOptionsInput): Promise<Events> {
			...
		}

    async getActions(input: EventFilterOptionsInput): Promise<Actions> {
			...
		}
}

class MongoDBAdapter implements DatabaseAdapter {
    private client: MongoClient;

    constructor(connectionString: string | undefined) {
			...
		}

	  async getEvents(input: EventFilterOptionsInput): Promise<Events> {
			...
		}

    async getActions(input: EventFilterOptionsInput): Promise<Actions> {
			...
		}
}

const server = new GraphQLServer({
    typeDefs,
    resolvers,
    context: {
        db_client: new ArchiveNodeAdapter() // Use the db binding in the GraphQL context as an agnostic way to fetch data.
    }
});
```

These database adapters could be defined as npm libraries, and a node operator has to import their custom-defined npm database adapter and plug it into the server. The only point of concern is that the node operator must ensure the implementation is correct when fetching events.

## Operation

This server implementation will be completely separate from the Mina daemon client. The implementation will consist of a standalone TypeScript server that runs a GraphQL framework, which connects to a running Postgres database. Implementing the server separately from the Mina daemon allows the operator to host it wherever they wish. For example, they can host it on a server(s) completely separate from the Postgres database (for example, for architectures offered for public consumption by zkApps with high requirements for availability and scaling) or could optionally run on the same server but on a separate process if the developer desired (for example, for their personal use where availability & scaling aren't their objectives, but the minimal cost is).

An additional benefit of creating a standalone server is minimizing the performance degradation of the Mina daemon client itself. The TypeScript server is lightweight, acting as a wrapper to orchestrate fetching data from the Postgres database. The server logic consists of parsing the user's GraphQL request, issuing a query to the Postgres database, reading the input and formatting it in such a way as to match the format of the defined GraphQL schema. In this way, the server itself does not take much computing power and is instead forwarding the complexity to the database engine to optimize computation.

To get a better estimation of increased hardware requirements for the server running the Postgres database, monitoring the number of requests and usage should be easy to do (see the logging section for a suggested solution). It is easier to estimate how much resource requirements will be taken up by seeing real-world usage. As an estimate, however, memory and CPU requirements for this API server are expected to be low due to the efficiency of the GraphQL library chosen. Instead, the performance bottleneck will be on the CPU of the server hosting the Postgres DB.

Suppose the Postgres database is being heavily utilized. In that case, a node operator can vertically scale their database by running on more powerful hardware or horizontally scaling by creating a cluster of read-only databases and specifying the TypeScript server to connect to the cluster to share query traffic.

Given the current scope for the API as Phase 1 of the specified roadmap, we will only be supporting “server-full” architectures, which means that the API is deployed on a server, rather than a functions as a service provider. Serverless can be adopted since GraphQL Yoga is compatible with many different environments. However, the challenge of using serverless infrastructure is expected to be related to the connection between serverless application servers and the Postgres database, given Postgres expects long-lived connections from the application server(s) and does not offer an HTTP(S) interface, such as more modern serverless-focused databases do for this reason.

In addition to the API server, there must be an Archive Node database or another database that the API can connect to fetch event and action data. The management of these services will be left up to the node operator as the architecture can vary heavily between preferred deployment methods. A node operator can introduce rate limiting and higher availability guarantees by sticking a load balancer in front of the GraphQL server, and the node operator can adopt many other techniques. One important feature that the Phase 1 server will support is connecting to multiple databases from the same server. This means that a node operator can point the server to a database cluster, allowing the architecture to be horizontally scaled.

## Logging

Logging in a GraphQL server is crucial to understand the behaviour and performance of the server, especially in production environments. This section outlines the recommended logging approach for the TypeScript GraphQL server, using [OpenTelemetry](https://opentelemetry.io/docs/concepts/what-is-opentelemetry/) and [Jaeger](https://github.com/jaegertracing/jaeger).

OpenTelemetry is open-source and provides a unified and vendor-neutral way to collect, process, and export telemetry data. Jaeger is a distributed tracing system that implements the OpenTelemetry API and is well-suited for microservice-based architectures.

The benefits of using Jaeger compared to other logging services are:

- Distributed tracing: Jaeger provides a comprehensive view of a request as it flows through the system. This makes it easier to diagnose issues and understand the dependencies between services. This is especially useful if node operators run multiple instances of the server. This means that they can configure the servers to send all logging to one Jaeger instance for centralized logging for easy monitoring.
- High performance: Jaeger is optimized for performance, with low overhead and efficient data storage. This makes it suitable for use in production environments where the performance of the logging system is critical.
- Open-source: Jaeger is open-source, which means it is free to use, customize, and integrate into other systems. Additionally, the large community of contributors helps ensure the project's continued development and maintenance. This was a high motivation factor for picking Jaeger.
- Integrations: Jaeger integrates with many other tools and services, including logging platforms, metric systems, and visualization tools, making it a versatile and flexible logging solution.
- HTTP-Based: Jaeger receives logs via HTTP by a specified endpoint, supporting serverless environments.

Jaeger will be _opt-in_ for operators. To enable Jaeger logging, a set of environment variables will be provided and will have to be set by the node operator if they wish to use the service. Documentation will be included in a README on how to set up Jaeger for node operators if they wish to do so. If Jaeger is not configured, all logging will be emitted to `stdout`, where the operator can do what they wish with the logs.

To start, the server will log only the GraphQL API calls. Specifically, this means the inputs and results of each API call will be logged to the server.

An example log can be seen below:

```graphql
{
  traceId: 'e2e55563bfa6ed65fef98347a522f5c8',
  parentId: undefined,
  name: 'getEvents',
  id: 'bce9282cefab0ceb',
  kind: 1,
  timestamp: 1675672108756132,
  duration: 55349,
  attributes: {
    'graphql.execute.operationName': 'getEvents',
    'graphql.execute.document': 'query getEvents {\n' +
      '  events(\n' +
      '    input: {address: "B62qpmAopz78WCvBRbC2pQRraRxwpu5CKiDm6D1xWqsgQ4jnDLD37Vg", to: "10000", from: "0", status: ALL}\n' +
      '  ) {\n' +
      '    blockInfo {\n' +
      '      height\n' +
      '      stateHash\n' +
      '      parentHash\n' +
      '      ledgerHash\n' +
      '      chainStatus\n' +
      '      timestamp\n' +
      '      globalSlotSinceGenesis\n' +
      '      globalSlotSinceHardfork\n' +
      '    }\n' +
      '    transactionInfo {\n' +
      '      hash\n' +
      '      memo\n' +
      '      status\n' +
      '      authorizationKind\n' +
      '    }\n' +
      '    eventData {\n' +
      '      index\n' +
      '      fields\n' +
      '    }\n' +
      '  }\n' +
      '}',
    'graphql.execute.variables': '{}',
    'graphql.execute.result': '{"data":{"events":[{"blockInfo":{"height":"7301","stateHash":"3NKCU21rejLe8ApkoWbRUvEzvnWhAEpqrfLPD2vLtYSboztQ3aYU","parentHash":"3NL3f8ECNXGk1PYzT95qDugBmfvQ2rSeSfuUvAESUtNTTL6MQfpD","ledgerHash":"jwY761maCnBeLbshb4v4957huFaTfGmWGudifKaZfAhqjar4gKh","chainStatus":"canonical","timestamp":"1673908381000","globalSlotSinceGenesis":"12481","globalSlotSinceHardfork":"12481"},"transactionInfo":{"hash":"CkpZB29F7xvmU4MXjieDJRKT3cWPKmZaKehERG8MrYo5xeoh4tfNK","memo":"E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH","status":"applied","authorizationKind":"Proof"},"eventData":[{"index":"0","fields":["1"]},{"index":"1","fields":["13609095204119302896499736459006739600712679465237287466276100695051029525692","0"]},{"index":"2","fields":["10"]}]},{"blockInfo":{"height":"7304","stateHash":"3NKRmnX2PNexhaQpDiadTwhLFu5BTPmce7ZDFPqRuwYKLpAx899J","parentHash":"3NKqNJie7T9D5gfWuoajJQ7qRWB99ZwGkwGfiMSpxAuCNGtk1a4Y","ledgerHash":"jxZQfumFqP2DBXwvaH75XhZ3hjK9zSCpN5qaULHYt3N4McArLb2","chainStatus":"canonical","timestamp":"1673909461000","globalSlotSinceGenesis":"12487","globalSlotSinceHardfork":"12487"},"transactionInfo":{"hash":"Ckpa26GJuZnysvdoZ8NtmtkqpfxfwUtGwJPvytUvSUmmiGHqJsVJ1","memo":"E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH","status":"applied","authorizationKind":"Proof"},"eventData":[{"index":"0","fields":["11"]},{"index":"1","fields":["13609095204119302896499736459006739600712679465237287466276100695051029525692","0"]},{"index":"2","fields":["10"]}]},{"blockInfo":{"height":"7315","stateHash":"3NKEMdEce81kazYT8oYVjc1X8FjF5PkzNdHi3d4DdYSigWSrT1yn","parentHash":"3NKGGf6dv3tYEFyrnsrbK2MmoP9ixVZ5QiwhUTpWXMwKDo12mjhT","ledgerHash":"jxAzH3fjLCi65qXEQybAKPAGLePfaKhi6brNrKHeEVymZpnr73T","chainStatus":"canonical","timestamp":"1673913781000","globalSlotSinceGenesis":"12511","globalSlotSinceHardfork":"12511"},"transactionInfo":{"hash":"CkpaBuhpgNLQVmwjrNC8bG543bHuMCYLfcEwF5h8ojuX2yDsQXbMB","memo":"E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH","status":"applied","authorizationKind":"Proof"},"eventData":[{"index":"0","fields":["21"]},{"index":"1","fields":["13609095204119302896499736459006739600712679465237287466276100695051029525692","0"]},{"index":"2","fields":["10"]}]}]}}'
  },
  status: { code: 0 },
  events: []
}
```

## Testing

Testing GraphQL APIs is a crucial part of ensuring that the API functions as intended, especially when the API interacts with a database like Postgres.

Because most of the complexity lies in how the server interacts with the Archive Node Postgres database, integration tests that verify that the GraphQL resolvers are working correctly by executing correct SQL are crucial.

We will need the following to be confident that the implementation is sufficiently tested:

**Unit Tests**

- Internal functions that process data from the SQL server behave as expected and do not throw errors.
- GraphQL schema validation. We should ensure that the schema can be validated with various queries for correctness.

**Integration Tests**

- Contract testing
  - Ensure that the expected GraphQL resolver produces the expected SQL for a specified input.
  - Ensure that expected SQL produces an expected data set from a database.

**End-to-End Tests**

- Ensure that the request pipeline works as expected. This means spinning up a GraphQL and Postgres server, issuing a GraphQL query and validating that the request is pipelined through the GraphQL and Postgres server and returns the expected output.

As an initial implementation, Unit and Integration tests should be prioritized as they are easy to include in CI. As the implementation matures, End-to-end tests can be adopted to ensure that the entire request pipeline works across different added changes.

## Conclusion

This RFC presents a design for a GraphQL server that will interact with a Postgres database and provide data to a library called SnarkyJS. The design is focused on providing a performant, reliable, and secure API while being easy to integrate and extensible. The implementation and testing of this design will ensure that the final product meets the requirements and provides a solid foundation for future development.
