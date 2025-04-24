Batch Transaction Tool
=====================

The `batch_txn_tool` is a utility for generating and executing batches of
transactions in the Mina network. It helps with testing network throughput,
performance, stress testing, or simulating network activity by creating and
submitting multiple transactions in a controlled manner.

Features
--------

The tool provides three main commands:

1. **gen-keys**: Generate a specified number of public keys.
2. **gen-txns**: Generate shell commands to send transactions from one account to
   multiple generated accounts.
3. **gen-there-and-back-txns**: Generate and execute transactions from a main
   account to a secondary account and then back again, with configurable rate
   limiting.

Prerequisites
------------

Before using `batch_txn_tool`, you need:

1. Access to a running Mina node with GraphQL API enabled (default port 3085).

2. For the `gen-there-and-back-txns` command, you need:
   - A funded Mina account to use as the origin/sender account
   - Private key file for the sender account
   - A second account with its private key file (the returner account)

Compilation
----------

To compile the `batch_txn_tool` executable, run:

```shell
$ dune build src/app/batch_txn_tool/batch_txn_tool.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/batch_txn_tool/batch_txn_tool.exe`

Usage
-----

### Generate Public Keys

Generate a specified number of public keys and output them to stdout:

```shell
$ batch_txn_tool gen-keys --count NUM
```

Parameters:
- `--count NUM`: Number of keys to generate

### Generate Transaction Commands

Generate shell commands to send payments from a specified sender to multiple
generated recipients:

```shell
$ batch_txn_tool gen-txns --count NUM --sender-pk PUBLIC_KEY [OPTIONS]
```

Required Parameters:
- `--count NUM`: Number of keys to generate as recipients
- `--sender-pk PUBLIC_KEY`: Public key to send the transactions from

Optional Parameters:
- `--txn-capacity-per-block NUM`: Transaction capacity per block for rate
  limiting (default: 128)
- `--slot-time NUM_MILLISECONDS`: Slot duration in milliseconds (default: 180000)
- `--fill-rate FILL_RATE`: Fill rate (default: 0.75)
- `--apply-rate-limit TRUE/FALSE`: Whether to emit sleep commands between
  transactions (default: true)
- `--rate-limit-level NUM`: Number of transactions that can be sent in a time
  interval before hitting the rate limit (default: 200)
- `--rate-limit-interval NUM_MILLISECONDS`: Interval that the rate-limiter is
  applied over (default: 300000)

### Generate and Execute "There and Back Again" Transactions

Send funds from an origin account to a returner account, and then send them back
in multiple transactions:

```shell
$ batch_txn_tool gen-there-and-back-txns --num-txn-per-acct NUM \
    --origin-sender-sk-path PATH --returner-sk-path PATH [OPTIONS]
```

Required Parameters:
- `--num-txn-per-acct NUM`: Number of transactions to run for each generated key
- `--origin-sender-sk-path PATH`: Path to private key file of the origin sender
- `--returner-sk-path PATH`: Path to private key file of the returner account

Optional Parameters:
- `--txn-capacity-per-block NUM`: Transaction capacity per block (default: 128)
- `--txn-fee FEE_AMOUNT`: Transaction fee (default: minimum fee)
- `--slot-time NUM_MILLISECONDS`: Slot duration in milliseconds (default: 180000)
- `--fill-rate FILL_RATE`: Average rate of blocks per slot (default: 0.75)
- `--apply-rate-limit TRUE/FALSE`: Whether to apply rate limiting (default: true)
- `--rate-limit-level NUM`: Maximum transactions in a time interval (default: 200)
- `--rate-limit-interval NUM_MILLISECONDS`: Rate limit interval (default: 300000)
- `--origin-sender-sk-pw PASSWORD`: Password for origin sender's private key
- `--returner-sk-pw PASSWORD`: Password for returner's private key
- `--graphql-target-node URL`: GraphQL node to send commands to
  (default: 127.0.0.1:3085)
- `--fee FEE`: Transaction fee (default: network minimum)

Examples
--------

Generate 10 public keys:

```shell
$ batch_txn_tool gen-keys --count 10
```

Generate transaction commands to send funds to 100 accounts:

```shell
$ batch_txn_tool gen-txns --count 100 \
    --sender-pk B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV
```

Execute a transaction burst between two accounts:

```shell
$ batch_txn_tool gen-there-and-back-txns --num-txn-per-acct 50 \
    --origin-sender-sk-path /path/to/sender.key \
    --returner-sk-path /path/to/returner.key \
    --txn-fee 0.1 \
    --graphql-target-node 127.0.0.1:3085
```

Technical Notes
--------------

- The tool implements rate limiting based on transaction capacity, slot time, and
  fill rate parameters, ensuring the network isn't overwhelmed with transactions.

- For the "there and back again" transactions, the tool first sends funds from
  the origin account to the returner account, then uses those funds to send
  multiple transactions back to the origin account.

- The tool monitors transaction success and provides logging information about
  transaction status.

- Private key passwords can be provided either as command-line parameters or
  through the `MINA_PRIVKEY_PASS` environment variable.