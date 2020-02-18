# Local Coda Demo

If all you need is a running daemon and some blocks, the
`codaprotocol/coda-demo` container has everything you need! It uses the same
configuration as the testnet, but instead of the community participants ledger
it uses a simple ledger with a single demo account.

The public key of the demo account is `4vsRCVMNTrCx4NpN6kKTkFKLcFN4vXUP5RB9PqSZe1qsyDs4AW5XeNgAf16WUPRBCakaPiXcxjp6JUpGNQ6fdU977x5LntvxrSg11xrmK6ZDaGSMEGj12dkeEpyKcEpkzcKwYWZ2Yf2vpwQP`, with the following private key file (the password is the empty string):

```
{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"7S1YA5PinXhnLgLJ3xemVnVPWdJdhKZ9RSNQbns","pwsalt":"AzDoECCYyJL8KuoB2vrsVc9Wg3xJ","pwdiff":[134217728,6],"ciphertext":"5UQuiQVbXPmR63ikri792dWR6Dz5dYZm8dLzwDyqWovdP5CzrLY6Fjw3QTHXA9J3PDkPZpvhrQfGkgU81kr9184dfoJDhn5EXxJMCAM44SZdmBYVszEQaSQnyy4BwsbRXmfjBMSW9ooGu2a5dFi5KHX5na6fr62VUB"}
```

This account has 100% of the stake.

The demo container will run a block producer and a snark worker. You need to
make sure the `--publish` at least the GraphQL port, for example `docker run
--publish 3085:3085 -it codaprotocol/coda-demo`. Any additional arguments will
be passed to the daemon.
