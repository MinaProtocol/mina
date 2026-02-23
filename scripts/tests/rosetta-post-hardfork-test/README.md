# Rosetta Post-Hardfork Test

Validates Mina's [Rosetta API](https://docs.cdp.coinbase.com/mesh/docs/welcome/) implementation after a hardfork using the `rosetta-cli` tool. Runs three checks in sequence: **spec**, **data integrity**, and **construction** (payments, delegations, account creation).

> **Note:** The repository already contains Rosetta validation tests (see `src/app/rosetta/test-agent`). This test suite is specifically tailored for **post-hardfork validation** -- it uses a different `rosetta-cli` Docker image (`gcr.io/o1labs-192920/rosetta-cli:mesa-hardfork-testing`) built to handle hardfork-specific scenarios and is meant to be run against a freshly upgraded network before it is declared ready.

## Prerequisites

- Docker
- `jq`
- Node.js (for the key conversion helper)
- `mina` CLI (to extract the secret key hash)
- A funded Mina account (secret key + public address)

## Obtaining the Funded Account Key

The prefunded block-producer keys are stored in **GCP Secret Manager**. The secret names correspond to variables defined in the gitops values file:

<https://github.com/o1-labs/gitops-infrastructure/blob/mesa-migration/platform/o1labs-hetzner-networks/mina-standard-pre-mesa-auto/values/values.yaml.gotmpl#L432>

Substitute the variable to find the matching secret name, then download it:

```bash
# Example: download the secret from GCP
gcloud secrets versions access latest --secret="<SECRET_NAME>" > secret/secret.sk
```

### Set correct permissions

The key file **and** its parent directory must be locked down (mina enforces this):

```bash
mkdir -p secret
chmod 0600 secret
chmod 0600 secret/secret.sk
```

### Extract the Base58 private key

```bash
mina advanced dump-keypair --privkey-path secret/secret.sk
```

This prints the Base58-encoded private key (starts with `EK...`).

### Convert to hex

The rosetta-cli construction check expects the private key in **hex** format, not Base58. Use the bundled helper:

```bash
npm install            # one-time: installs bs58check
node convert-pvk-to-hex.js <BASE58_PRIVATE_KEY>
```

This outputs a 64-character hex string to pass as the `-k` argument.

## Rosetta Endpoint

The Rosetta API is exposed on port **3087** of the Rosetta container. For the pre-mesa hardfork testing network the public URL is:

```
https://rosetta.hetzner-pre-mesa-1.gcp.o1test.net
```

(This forwards to port 3087 on the container.)

## Usage

```bash
./runner.sh \
  -n <network> \
  -o <online_url> \
  -k <hex_privkey> \
  -a <public_address> \
  [-f <offline_url>] \
  [-i <docker_image>]
```

| Flag | Description | Required |
|------|-------------|----------|
| `-n, --network` | Network name (e.g. `mainnet`, `devnet`) | Yes |
| `-o, --online-url` | Rosetta online API URL | Yes (or `-f`) |
| `-f, --offline-url` | Rosetta offline API URL (defaults to online URL) | No |
| `-k, --privkey` | Hex-encoded private key (output of `convert-pvk-to-hex.js`) | Yes |
| `-a, --address` | Mina public key address (B62q...) | Yes |
| `-i, --image` | Docker image for rosetta-cli | No (default: `gcr.io/o1labs-192920/rosetta-cli:mesa-hardfork-testing`) |

### Example

```bash
./runner.sh \
  -n mainnet \
  -o https://rosetta.hetzner-pre-mesa-1.gcp.o1test.net \
  -k abc123def456... \
  -a B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk
```

## What the Runner Does

1. **Generates config** -- Fills `config_template.json` with the provided network, URLs, key, and address.
2. **Processes `mina.ros`** -- Injects the network identifier and prefunded address into the Rosetta DSL file.
3. **Step 1/3 -- Spec check** (`check:spec`) -- Validates the Rosetta API conforms to the specification.
4. **Step 2/3 -- Data check** (`check:data`) -- Verifies blockchain data integrity and reconciliation.
5. **Step 3/3 -- Construction check** (`check:construction`) -- Submits real transactions (payments, delegations, account creations) to validate the construction flow end-to-end. Requires the network to be running and the account to be funded.

## Files

| File | Purpose |
|------|---------|
| `runner.sh` | Main test orchestrator |
| `config_template.json` | Rosetta-cli config template with placeholders |
| `mina.ros` | Rosetta DSL defining construction workflows (payment, delegation, account creation, return funds) |
| `convert-pvk-to-hex.js` | Converts Mina Base58Check private key to hex |
| `package.json` | Node.js dependencies for the key converter |
