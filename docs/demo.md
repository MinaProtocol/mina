# Local Coda Demo

If all you need is a running daemon and some blocks, the
`codaprotocol/coda-demo` container has everything you need! It uses the same
configuration as the testnet, but instead of the community participants ledger
it uses a simple ledger with a single demo account.

The public key of the demo account is `B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g`, with the following private key file (the password is the empty string):

```
{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"}
```

This account has 100% of the stake.

The demo container will run a block producer and a snark worker. You need to
make sure the `--publish` at least the GraphQL port, for example `docker run
--publish 3085:3085 -it codaprotocol/coda-demo`. Any additional arguments will
be passed to the daemon.
