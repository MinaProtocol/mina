Stateless delegation verification
---------------------------------

This is the stateless verification tool that would be used to verify
that data collected by the uptime service. It verifies the snark work
proofs that can optionally be attached to each submission and also it
validates the blocks claimed to be heads of submitters' best chains at
the time of each submission.

The tool can work in two distinct modes:
* **file system mode**, where all submission and blocks should be
  stored in files on a local file system;
* **cassandra mode**, where all the data is stored in a Cassandra
  database.
  
Note that submission verification and block validation which this tool
performs closely depends on the version of Mina it was compiled with.
Therefore it is important to always use the verifier tool compiled from
the same revision of the code which produced block and submission one
wants to verify.

File system mode
----------------

Usage:
```
./delegation-verify fs --block-dir <blockdir> <filepath1> <filepath2> ... <filepath{n}>
./delegation-verify fs --block-dir <blockdir> -
```

Where `<filepath{i}>` is a file path of the form
`<basedir>/<submitted_at_date>/<submitted_at>-<submitter>.json`
containing JSON following the format described in
[Cloud storage section of delegation backend spec]
(https://github.com/MinaProtocol/mina/blob/develop/src/app/delegation_backend/README.md#cloud-storage)
(`<basedir>` is a place holder for some directory):

```json
{ "created_at": "server's timestamp (of the time of submission)"
, "remote_addr": "ip:port address from which request has come"
, "peer_id": "peer id (as in user's JSON submission)"
, "snark_work": "(optional) base64-encoded snark work blob"
, "block_hash": "base58check-encoded hash of a block"
, "submitter": "base58check-encoded submitter's public key"
}

```
File path content:
- `submitted_at_date` with server's date (of the time of submission) in format `YYYY-MM-DD`
- `submitted_at` with server's timestamp (of the time of submission) in RFC-3339
- `submitter` is base58check-encoded submitter's public key


Parameter `--block-dir` specifies the path to the directory containing
block for the submission. It is expected that blocks with
`<block_hash>` exist under path `<blockdir>/<block_hash>.dat` for all
of the filepaths provided.

When `-` symbol is used as the `filename1`, no other `filename{i}` are
accepted and all filenames will be read from the `stdin`, one filename
per line.

For each `<filename{i}>` parameter one line of output is printed to
`stdout` :

- Valid payload at `<filename{i}>` :

    ```json
    { "created_at": "<timestamp of the submission (for identification)>"
    , "submitter": "<submitter's public key (for identification)>"
    , "parent": "<hash of the parent block>"
    , "state_hash": "<state hash of the block in base58 format>"
    , "height": "<blockchain height>"
    , "slot": "<global slot since genesis corresponding to the block>"
    }
    ```

- Invalid payload at `<filename{i}>` :

    ```json
    { "error": "<reason of rejection>" }
    ```

The stateless verification would check the protocol_state_proof in the
block and the transaction_snark_proof in the snark_work.

Cassandra mode
--------------

This mode of operations depends on an external program, `cqlsh` being
installed. It is a Cassandra client written in Python, which
delegation verifier uses to access Cassandra database. This program
should be available in the system path. If it's not, a path to the
`cqlsh` executable can be passed either in `CQLSH` environment
variable or through a command-line option `--clqsh`. Without access
to `cqlsh`, the delegation verifier can only work in the file system
mode described above.

Additionally, the aforementioned Cassandra client requires some
configuration. In particular, an address and credentials to access
the right Cassandra server must be provided. They should be put in a
configuration file: `$HOME/.cassandra/cqlshrc`. The file can look
like this:

```
[authentication]
username = bpu-integration-test-at-673156464838
password = ************************************

[connection]
hostname = cassandra.us-west-2.amazonaws.com
port = 9142
ssl = true

[ssl]
certfile = /home/user/uptime-service-backend/database/cert/sf-class2-root.crt
```

Alternatively this configuration can be provided in environment variables:
* `CASSANDRA_HOST`
* `CASSANDRA_PORT`
* `CASSANDRA_USERNAME`
* `CASSANDRA_PASSWORD`
* `SSL_CERTFILE`
* `CASSANDRA_USE_SSL` – "1", "YES", "yes", "TRUE", "true" all mean yes,
  any other value means no.

Usage:
```
./delegation-verify cassandra --keyspace <keyspace-name> <start-timestamp> <end-timstamp>
```

Where:
* `keyspace` is the name of the Cassandra keyspace in the AWS cloud
* `start-timestamp` and `end-timestamp` define a time interval from which
  submissions will be taken into account. They should be passed in the
  format of the `submitted_at` field above (and in the database), that is:
  `YYYY-MM-DD HH:mm:ss.0+0000`, where the trailing zeros describe the
  timezone, which should be UTC.

Given this command, the verifier will download submissions from the
given period one by one and verify them. Blocks will also be
downloaded from Cassandra and validated. For each submission, a JSON
statement will be output as shown in the previous
section. Additionally, also appropriate submission records in
Cassandra will be updated with the data. Any errors will also be
logged in Cassandra and **will not** cause the verifier to exit
with a non-zero exit code.

Global options
--------------

Some command-line options work with both modes of operation:

* `--no-check` – given this option, the program will skip validation
  of blocks and snark work, and will immediately proceed to outputting
  state hashes and other metadata for each submission, whether it is
  valid or not.
  
* `--config-file` - a configuration file of the Mina network. It is
  necessary to provide it if the network which produced the blocks
  used configuration affecting block validation. In most cases it can
  be omitted.

Build
-----

The executable and docker image can be built with Nix. For further instructions, consult the Mina [Nix documentation](https://github.com/MinaProtocol/mina/tree/berkeley/nix) 
