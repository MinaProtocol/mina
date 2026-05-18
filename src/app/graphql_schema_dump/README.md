GraphQL Schema Dump
=================

The `graphql_schema_dump` utility is a specialized tool for generating a
complete introspection dump of the Mina daemon's GraphQL API schema. This is
essential for developers building client applications that need to interact with
the Mina daemon via GraphQL.

Features
--------

- Generates a complete JSON representation of the GraphQL schema using introspection
- Includes all types, fields, queries, mutations, and subscriptions
- Contains descriptions, deprecation notices, and argument specifications
- Produces output in a format compatible with GraphQL tooling

Purpose
-------

GraphQL schemas can be introspected at runtime, but having a static schema file
is valuable for:

1. Client code generation without a running daemon
2. Documentation and exploration of the API
3. Schema version tracking in source control
4. Compatibility checking for client applications
5. Integration with GraphQL development tools

This utility automatically generates this schema JSON file in a deterministic way
directly from the code, without needing a running daemon.

Prerequisites
------------

No special prerequisites are needed to run this tool, as it generates the schema
directly from the API definitions in the code rather than contacting a running
instance.

Compilation
----------

To compile the `graphql_schema_dump` executable, run:

```shell
$ dune build src/app/graphql_schema_dump/graphql_schema_dump.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/graphql_schema_dump/graphql_schema_dump.exe`

Usage
-----

The tool is straightforward to use as it doesn't require any command-line
arguments:

```shell
$ graphql_schema_dump > schema.json
```

This will generate the complete GraphQL schema and save it to `schema.json`.

It's common to redirect the output to a file as shown above, as the schema is
typically quite large.

Schema Format
------------

The output is a JSON document that conforms to the GraphQL Introspection Query
specification. It includes the following key components:

- **Types**: All object types, input types, enums, interfaces, and unions
- **Queries**: Available read operations with their parameters and return types
- **Mutations**: Available write operations with their parameters and return types
- **Subscriptions**: Available long-lived subscription operations
- **Directives**: Special annotations that can modify execution behavior

Each type and field includes its description, deprecation status, and any
arguments it accepts.

Examples
--------

Save the schema to a file for use with GraphQL tooling:

```shell
$ graphql_schema_dump > graphql_schema.json
```

Use with JavaScript GraphQL clients like Apollo:

```shell
$ graphql_schema_dump > client/src/graphql/schema.json
```

Check for changes in the schema:

```shell
$ graphql_schema_dump > new_schema.json
$ diff graphql_schema.json new_schema.json
```

Generate TypeScript types for client applications:

```shell
$ graphql_schema_dump > schema.json
$ npx graphql-codegen --schema schema.json --generates ./src/types.ts
```

Integration with CI/CD
--------------------

This tool is commonly used in continuous integration workflows to ensure the
GraphQL schema is up-to-date. For example, you might have a CI job that:

1. Runs `graphql_schema_dump` to generate the latest schema
2. Compares it with the committed schema file
3. Fails if there are changes not reflected in the committed schema

This helps ensure that API changes are deliberate and documented.

Technical Notes
--------------

- The tool uses the standard GraphQL introspection query to extract the schema.
- It directly imports the Mina GraphQL schema module rather than connecting to a
  running daemon.
- The output is formatted as pretty-printed JSON for readability.
- The implementation uses a "fake" Mina library instance since it only needs the
  type information, not actual data.

Related Files
------------

- `graphql_schema.json`: The primary output file in the repository root
- `src/lib/mina_graphql`: The directory containing the GraphQL schema definitions

Related Commands
--------------

- `./scripts/check-graphql-schema.sh`: A script that may be used in CI to
  verify the schema hasn't changed unexpectedly
- `mina client graphql`: Command to interact with a running daemon's GraphQL API