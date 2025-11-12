# Test Signer CLI

Command-line helper for drafting, signing, and broadcasting Mina payments via the public GraphQL API. It wraps the `mina-signer` library so you can submit transactions without wiring up a full wallet or SDK.

## Getting Started
- **Prerequisites:** Node.js 18+ (for native `fetch`) and npm.
- **Install dependencies:** `npm install`
- **Quick run:** `node mina-test-signer.js <private_key> <recipient_address> [graphql_url] [nonce]`

The optional `graphql_url` flag lets you override the default target defined in `config.js`.

## Workflow
1. `mina-test-signer.js` parses CLI arguments and wires the supporting services.
2. `payment-service.js` derives the sender public key, composes a payment payload, and signs it with `mina-signer`.
3. `graphql-client.js` sends the signed payload to the Mina daemon and can check whether the transaction reached the pool.
4. `utils.js` provides small helpers for GraphQL string construction and CLI validation.
5. `config.js` centralises network defaults and usage messaging.

- `mina-test-signer.js` – CLI entry point orchestrating validation, signing, submission, and pool verification.
- `payment-service.js` – Thin wrapper around `mina-signer` with sensible defaults for MINA amounts and fees.
- `graphql-client.js` – Minimal fetch-based GraphQL transport for sending payments and querying pooled commands.
- `utils.js` – GraphQL stringification helpers plus basic CLI argument validation/parsing.
- `config.js` – Configuration constants and usage text surfaced by the CLI.
- `key/` – Sample key material for experimentation; do not use in production environments.

Check the console output for a transaction id; you can re-run the pool check or the `getPooledUserCommands` helper to confirm inclusion.
Provide a `nonce` argument when you need to synchronise with on-chain account state manually.
The CLI prints emoji-enhanced step logs and a summary table so you can spot successes and failures at a glance.
GraphQL errors (including malformed responses) cause the CLI to exit with a non-zero status so they can be surfaced in scripts and CI.

## Customisation Tips
- Update `CONFIG.DEFAULT_GRAPHQL_URL` in `config.js` to point at your daemon or a hosted GraphQL endpoint.
- Tweak `CONFIG.MINA_UNITS.DEFAULT_AMOUNT_MULTIPLIER` and `DEFAULT_FEE_MULTIPLIER` to adjust the default transaction values.
- Extend `GraphQLClient` with additional queries (e.g. account state, balances) if you need richer diagnostics.

## Private key format

For clarity, private key is in output format of:

```
  mina advanced dump-keypair --privkey-path ...
```

## Safety Notes
- Treat private keys in plain text with care. Prefer environment variables or a secure secrets manager for real deployments.
- The example keys under `key/` are for local testing only; they are publicly known and should never hold funds.
