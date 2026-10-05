Validate Keypair
==============

The `validate_keypair` utility is a security-focused tool that verifies the
integrity and functionality of a Mina cryptographic keypair. It performs several
checks to ensure that a keypair is valid and usable for signing transactions on
the Mina network.

Features
--------

- Validates that a private key file can be successfully decrypted
- Verifies that the public key stored on disk matches the one derived from the
  private key
- Tests the keypair by signing and verifying a dummy transaction
- Provides clear error messages for any issues detected during validation

Prerequisites
------------

Before using this tool, you need:

1. An existing keypair generated using the `generate_keypair` tool or imported
   into the Mina wallet
2. Access to both the private key file and its corresponding public key file
   (with the .pub extension)

Compilation
----------

To compile the `validate_keypair` executable, run:

```shell
$ dune build src/app/validate_keypair/validate_keypair.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/validate_keypair/validate_keypair.exe`

Usage
-----

The basic syntax for running `validate_keypair` is:

```shell
$ validate_keypair --privkey-path FILEPATH
```

### Required Parameters

- `--privkey-path FILEPATH`: Specifies the path to the encrypted private key
  file. The tool automatically looks for the corresponding public key file at
  `FILEPATH.pub`.

### Password Entry

When running the command, you will be prompted to enter the password used to
encrypt the private key:

```
Enter password:
```

Unlike the `generate_keypair` tool, `validate_keypair` does not support using
the `MINA_PRIVKEY_PASS` environment variable for password entry.

### Validation Steps

The tool performs the following validations:

1. **Private Key Decryption**: Attempts to decrypt the private key file using the
   provided password
2. **Public Key Consistency**: Checks if the public key derived from the private
   key matches the one stored in the .pub file
3. **Transaction Signing**: Creates and validates a dummy transaction using the
   keypair to verify full signing functionality

### Output Messages

The following output messages indicate successful validation:

```
Public key on-disk is derivable from private key
Verified a transaction using specified keypair
```

If any validation step fails, the tool will display a detailed error message and
exit with a non-zero status code.

Examples
--------

Validate a keypair with correct password:

```shell
$ validate_keypair --privkey-path ~/.mina-keys/my-wallet
Enter password: 
Public key on-disk is derivable from private key
Verified a transaction using specified keypair
```

Validate a keypair with incorrect password:

```shell
$ validate_keypair --privkey-path ~/.mina-keys/my-wallet
Enter password: 
Could not read the specified keypair: The password is incorrect
```

Validate a keypair with mismatched public key:

```shell
$ validate_keypair --privkey-path ~/.mina-keys/my-wallet
Enter password: 
Public key read from disk B62qjXXX... different than public key B62qkYYY... derived from private key
```

Common Issues and Solutions
--------------------------

1. **Incorrect Password**: If you receive the error "The password is incorrect,"
   you're using the wrong password to decrypt the private key. Try to remember the
   correct password or use a backup of the keypair if available.

2. **Mismatched Public Key**: If the public key on disk doesn't match the one
   derived from the private key, your keypair files might have been corrupted or
   tampered with. Consider generating a new keypair.

3. **File Not Found**: If you see "Could not read public key file," ensure that
   both the private key file and the corresponding .pub file exist in the same
   directory.

4. **Transaction Verification Failure**: If the transaction verification step
   fails, this could indicate a problem with the cryptographic algorithms or a
   corrupted private key. This is a rare issue that might require generating a
   new keypair.

Technical Notes
--------------

- The tool uses the same cryptographic primitives as the core Mina protocol to
  test the keypair.

- For validation purposes, it creates a dummy transaction payload rather than an
  actual blockchain transaction.

- The validation ensures that the keypair can successfully sign data using the
  Schnorr signature scheme employed by Mina.

- This is a completely offline utility - it doesn't connect to the network or
  broadcast any information.

Related Tools
------------

- `generate_keypair`: A utility for creating new keypairs.

- `mina client import-key`: Command in the main Mina client that imports an
  existing keypair into the daemon's keystore.