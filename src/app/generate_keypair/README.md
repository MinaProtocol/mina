Generate Keypair
===============

The `generate_keypair` utility is a simple, focused tool for creating Mina
cryptographic keypairs. It generates a new public and private key pair that can
be used for transactions, staking, and other operations on the Mina network.

Features
--------

- Creates a cryptographically secure Ed25519 keypair
- Encrypts private key with a password for secure storage
- Outputs the public key in base58 format (standard Mina format)
- Also provides the raw public key format used by the Rosetta API

Prerequisites
------------

No special prerequisites are needed to run this tool, as it generates keys
without requiring any existing blockchain data or network connectivity.

Compilation
----------

To compile the `generate_keypair` executable, run:

```shell
$ dune build src/app/generate_keypair/generate_keypair.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/generate_keypair/generate_keypair.exe`

Usage
-----

The basic syntax for running `generate_keypair` is:

```shell
$ generate_keypair --privkey-path FILEPATH
```

### Required Parameters

- `--privkey-path FILEPATH`: Specifies the file path where the encrypted private
  key will be saved. The public key will be saved at the same location with a
  ".pub" extension added.

### Password Protection

When running the command, you will be prompted to enter a password to encrypt the
private key. Alternatively, you can set the password using the `MINA_PRIVKEY_PASS`
environment variable:

```shell
$ export MINA_PRIVKEY_PASS="your_secure_password"
$ generate_keypair --privkey-path my_keys/key1
```

If the environment variable is set, the tool will use that password instead of
prompting. It will print a message indicating that the password was taken from
the environment variable.

### Output Files

The command generates two files:

1. **Private key file**: Located at the specified path (`FILEPATH`). This is an
   encrypted file containing the private key.

2. **Public key file**: Located at `FILEPATH.pub`. This is a text file containing
   the public key in base58 format.

### Command Output

After successful key generation, the command will print:

```
Keypair generated
Public key: B62qjUXD...  (base58-encoded public key)
Raw public key: 99d0e5...  (hex-encoded public key for Rosetta API)
```

Examples
--------

Generate a keypair and save it to the default location:

```shell
$ generate_keypair --privkey-path ~/.mina-keys/my-wallet
Enter password to encrypt private key file:
Verifying, enter the same password again:
Keypair generated
Public key: B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
Raw public key: 99d0e533b57bed9d8220b63b16e68e3ddd2d4e8ecca3676ef7dc9a9ec63a361a
```

Use with environment variable for password:

```shell
$ export MINA_PRIVKEY_PASS="very_secure_password"
$ generate_keypair --privkey-path ./staking_key
Using password from environment variable MINA_PRIVKEY_PASS
Keypair generated
Public key: B62qrYrs7Zima5ePrLKJ3qM4NyQX5PaEJCjqvthmaTBTHiTEq9mP8WG
Raw public key: 7dfb705f1279dbb556c4dcb2f57abe6e77e16e6dac3ba5463f53d1d2510f0bb9
```

Technical Notes
--------------

- The keypair generated uses the Ed25519 elliptic curve cryptography as the basis
  for the Schnorr signature scheme used in Mina.

- The private key is encrypted using libsodium's secretbox encryption with a
  password-derived key.

- The public key is provided in two formats:
  - Base58 format with a "B62" prefix (standard Mina format)
  - Raw hex format (used by the Rosetta API integration)

- This tool is separate from the main Mina daemon for security reasons, allowing
  key generation on isolated or offline systems.

Related Tools
------------

- `validate_keypair`: A companion utility that validates an existing keypair by
  checking that the private key correctly corresponds to the public key and can
  successfully sign transactions.

- `mina client import-key`: Command in the main Mina client that imports an
  existing keypair into the daemon's keystore.