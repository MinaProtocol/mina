Archive
=======

The Mina daemon does not remember the entire history of the blockchain.
On the contrary, it only remembers a couple of blocks backwards, called
the *transition frontier*. If storing historic transaction data is
desired, this Archive needs to be set up next to the daemon itself.

Prerequisites
-------------

The Archive stores its data in a PostgreSQL database, so its necessary
to set one up before proceeding to run the Archive. The way one
installs Postgres software depends the operating system. However, in
some setups it might be more convenient to use the [official Postgres
Docker image](https://hub.docker.com/_/postgres) instead. In that case
the following command will set the database up:

```shell
$ docker run -d --name pg-mina-archive \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD='*******' \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -e POSTGRES_DB=mina_archive \
    -e POSTGRES_USER=pguser \
    postgres:latest
```

Note that setting the authentication method to `trust` is very unsafe,
because it allows anyone to connect without giving a password. While
convenient and acceptable in development settings, this option should
never be used in production. Also note that even with authentication
method set to `trust``, its still necessary to provide a password for
the database user.

The Docker container creates the database with the given name automatically.
In case a native database installation was chosen, the database must be
created manually:

```shell
$ createdb mina_archive
```

When set up, the database needs to be initialised. The following command
will put the schema in place:

```shell
$ psql -h localhost -d mina_archive -f src/app/archive/create_schema.sql
```

Note that the database should be dropped and recreated when a new
blockchain is to be used (for instance when restarting a sandbox blockchain).

When started, the archive will try to pull the blocks from the
*transition frontier* from nodes on the network. It won't, however, as
discused above, be able to get the entire history of blocks produced
prior to that. For this reason, when joining an existing network, it
might be desirable to load its history from a database dump
instead.

Additionally, when running the Mina daemon (see the main `README.md` for
exact instructions on how to do it), it is necessary to pass an additional
option to it: `--archive-address 3086`. The daemon will the try to feed
blocks it receives to the Archive for storage.

Running the Archive
-------------------

When the setup described above is complete, it is possible to start the
archive:

```shell
$ "_build/default/src/app/archive/archive.exe" run \
    --config-file daemon.json \
    --postgres-uri "postgres://localhost:5432/mina_archive" \
    --server-port 3086
```

Note that `--config-file` parameter should be identical to the one passed
to the daemon itself. Also `--server-port` should be the same as
`--archive-address` passed to the daemon. The `--postgres-uri` should have
the form:
`--archive-uri postgres://<username>:<password>@<host>:<port>/<dbname>`.

The Archive does not have its own interface for retrieving its data – for
that one can use Rosetta (see `src/app/rosetta`) or query the Postgres
database directly.
