Rosetta CLI
===========

[Rosetta CLI](https://www.rosetta-api.org/docs/rosetta_cli.html) is
a tool developed by Coinbase in order to help test implementations of
the Rosetta API. It's written in Go, but binaries ready for use can
be downloaded from the Internet (see the documentation linked above
for more details). It is also available in the various nix shells of the project.

Running those tests against a Mina node requires some prior setup,
which will be outlined in this instruction. Note that each of the
elements of the setup described below runs as a separate process,
either in the background or in a separate terminal window.

Sandbox node
------------

Although it's possible to run `rosetta-cli` against any node, running
it against most testing nodes will fail. The reason for this is that
the tool expect the node to have full historic data on the network's
past. This is an obvious requirements for most blockchains, but Mina
is different in that the complete ledger history is *not* required to
validate future operations. Therefore in practice most nodes do *not*
have complete history and therefore will fail to comply with
`rosetta-cli`'s requests. Another reason to use a sandbox node is that
it creates a more predictable/reproducible testing environment. Check
`README-sandbox.md` for instructions on how to set up a sandbox node.

To run `rosetta-cli` we will also require an archive node, so when
running the sandbox node, we need to add `--archive-address 3086`
option, specifying the port on which the archive will listen
(we will set it up in a moment).

Archive node
------------

Archive node stores history of the ledger in a PostgreSQL database, so
we need to provide such a database for it to run. It can be installed
natively, using a method appropriate for the underlying OS, or an
[official Postgres Docker image](https://hub.docker.com/_/postgres)
may be used. For instance:

```shell
$ docker run -d -p 5432:5432 \
    -e "POSTGRES_DB=archive" \
    -e "POSTGRES_HOST_AUTH_METHOD=trust" \
    -e "POSTGRES_USER=pguser" \
    --name mina-archive-db
    postgres
```

The environment variables `POSTGRES_DB` and `POSTGRES_USER` should
contain names of the database itself and the postgres user allowed
to access it. These names will reappear later when configuring the
archive itself.

Next the database schema must be put in place:

```shell
$ psql -h localhost archive -f src/app/archive/create_schema.sql
```

Note: the database name `archive` should be identical to
`POSTGRES_DB` above. Finally we can start the archive itself:

```shell
$ "_build/default/src/app/archive/archive.exe" run \
    --postgres-uri "postgres://localhost:5432/archive" \
    --server-port 3086
```
Note that the `--server-port` param should be equal to the one we set
previously for the node. As the node starts producing blocks, we
should see those blocks appear in archive's logs too.

Also note that archive can only know about the blocks that were
produced when it was running. This limitation also applies to
archive nodes on real networks. Once a block falls off the running
frontier, it is never sent over the network again, so archive nodes
have no way of filling gaps in their history. This poses a problem
for `rosetta-cli`, which expects to fetch the full blockchain's
history from the Rosetta API and will fail if it encounters such a
gap.

Rosetta server
--------------

Rosetta server can be started with the following command:

```shell
$ "$BUILD/rosetta/rosetta.exe" \
    --archive-uri "postgres://pguser:pguser@localhost:5432/archive" \
    --graphql-uri http://localhost:3085/graphql \
    --port 3087 \
    --log-level debug 
```

Note that the Rosetta server does not really communicate with the
archive, although it does communicate with the main node. Instead,
it reads archive database directly. The `--archive-uri` argument
which specifies the address of the database has the following form:
`--archive-uri postgres://<username>:<password>@<host>:<port>/<dbname>`.
Note that since we set up the database to *trust* its connections,
the `<password>` part is not really necessary and the connection will
succeed even if the password is wrong.

Rosetta CLI tool
----------------

Aside from downloading the `rosetta-cli` binary, before it can be run,
a suitable configuration file needs to be provided. An example of such
a file can be found in `src/app/rosetta/rosetta-cli-config/config.json`.
This configuration is tailored so that it lets the most users run the
tests on their local machines, so it might need tweaking for some
particular setups.

Additionally another file is necessary in order to run Construction
API tests. These tests are blockchain-specific and therefore must be
written by the user. We will include our tests in
`src/app/rosetta/rosetta-cli-config/mina.ros`. Note that this file
is required for `rosetta-cli` to run even if `check:construction`
test is not invoked. For the moment we have a working stub in there,
which tests nothing.

Also note that `config.json` includes a path where Construction API
tests' results should be output. This path **has to** be absolute,
which makes it impossible to find a reasonable default. For this
reason user must update this path manually before running Construction
API tests.

There are 3 main tests to choose from: `check:spec`, `check:data` and
already mentioned `check:construction`. The first tests if the server
is conforms with the specification released by Coinbase. It calls
various endpoints and verifies responses against the schema.

`check:data` analyses the contents of the blockchain. It goes block-
by-block from genesis until it finds a specified number of
transactions, accounts creations etc. It verifies the integrity of
data presented by the server. Because of the extensive nature of
this verification this test may take a long time to complete.

Finally `check:construction` tests the construction API, which allows
developers to interact with the blockchain (e.g. order transactions,
create accounts etc.). This is the most complex part of the API
and that is why it requires additional blockchain-specific
configuration.

The tests can be run with the following command:

```shell
$ rosetta-cli --configuration-file config.json check:data
```

This command investigates block after block checks:
1. whether Rosetta returns well formed information about
   each block;
2. tracks balances of all the accounts it can discover
   and compares them to the balances returned by Rosetta;
   fails in case of finding a discrepancy.
   
**NOTE**: this check will never stop unless `"end_conditions"` field
is specified in the `config.json`, in `data` section (see the
example mentioned above). For example an end condition:
`"index": 50` will make `rosetta-cli to check first 50 blocks. 
