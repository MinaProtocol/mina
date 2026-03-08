## Mina Protocol docs

The docs for the Mina Protocol website are published on [docs.minaprotocol.com](https://docs.minaprotocol.com/).

The docs repository is [https://github.com/o1-labs/docs2/](https://github.com/o1-labs/docs2/).

## Keeping the CLI Reference Up to Date

The [Mina CLI reference](https://docs.minaprotocol.com/node-operators/mina-cli-reference)
page is auto-generated from the `mina` binary's help output. When CLI commands
are added or removed, the CLI reference docs in the docs2 repository must be
regenerated.

To regenerate the CLI reference docs after changing the CLI:

1. Build the mina binary:
   ```shell
   dune build src/app/cli/src/mina.exe
   ```

2. Run the CLI reference generation script:
   ```shell
   ./scripts/generate-cli-reference.sh _build/default/src/app/cli/src/mina.exe /tmp/mina-cli-reference
   ```

3. Use the generated output to update the corresponding pages in the
   [docs2 repository](https://github.com/o1-labs/docs2/).

### Current CLI Commands (`mina client`)

The `mina client` subcommand currently supports:

- `get-balance` – Get the balance of an account
- `get-tokens` – Get the tokens for a public key
- `send-payment` – Send a payment
- `delegate-stake` – Delegate your stake to another public key
- `cancel-transaction` – Cancel a transaction
- `set-snark-worker` – Set the key you wish to do snark work with
- `set-snark-work-fee` – Set the fee you wish to receive for doing snark work
- `export-logs` – Export logs to a tar archive
- `export-local-logs` – Export logs locally
- `stop-daemon` – Stop the daemon
- `status` – Get the status of the daemon

> **Note**: The `set-staking` subcommand was removed. To run a block producer,
> restart the daemon with the `--block-producer-pubkey` flag instead.
