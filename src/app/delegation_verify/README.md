This PR implements the stateless verification tool that would be used to verify that data collected by the uptime service.

Usage:
```
./delegation-verify --block-dir <blockdir> <filepath1> <filepath2> ... <filepath{n}>
./delegation-verify --block-dir <blockdir> -
```
Where `<filepath{i}>` is a file path of the form `<basedir>/<submitted_at_date>/<submitted_at>-<submitter>.json`
containing JSON following the format described in [Cloud storage section of delegation backend spec](https://github.com/MinaProtocol/mina/blob/develop/src/app/delegation_backend/README.md#cloud-storage) (`<basedir>` is a place holder for some directory):

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


Parameter `--block-dir` specifies the path to the directory containing block for the submission. It is expected that blocks with `<block_hash>` exist under path `<blockdir>/<block_hash>.dat` for all of the filepaths provided.

When `-` symbol is used as the `filename1`, no other `filename{i}` are accepted and all filenames will be read from the `stdin`, one filename per line.

Utility `./delegation-verify` exits with the following exit codes:

- `0` if it was able to execute verification of all filepaths
    - Note that `0` is returned even when some of the payloads were marked as invalid
- `1` if one of `<filepath{i}>` files violated the naming convention
- `2` if the utility failed to read some of `<filepath{i}>` files
- `3` if the utility failed to read some of `<blockdir>/<block_hash>.dat` files
- `5` if the other error occurred

In case of non-zero exit code, some details of the error may be printed to `stderr`.

For each `<filename{i}>` parameter one line of output is printed to `stdout` :

- Valid payload at `<filename{i}>` :
    
    ```json
    { "state_hash": "<state hash of the block in base58 format>"
    , "height": "<blockchain height>"
    , "slot": "<global slot since genesis corresponding to the block>"
    }
    ```
    
- Invalid payload at `<filename{i}>` :
    
    ```json
    { "error": "<reason of rejection>" }
    ```
The stateless verification would check the protocol_state_proof in the block and the transaction_snark_proof in the snark_work.