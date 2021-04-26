# Delegation compliance

Block producers that receive delegations from the Mina Foundation or
O(1) have specific obligations to the delegating accounts, as
described at https://docs.minaprotocol.com/en/advanced/foundation-delegation-program.
The app here checks whether those obligations are met.

In particular, the app identifies two kinds of deliquencies:

 - when a block producer has not made any payment to the delegating
    account for a given, when it has a nonzero payment obligation

 - when a block producer has not paid in full its reward for a given
    epoch to the delegating account by block 3500 of the following
    epoch

The log output of the app contains the word `DELINQUENCY` for both
these cases, with support information.

The input to the app is a file containing a genesis ledger and a state
hash for a block, the block through which to check compliance. The
file `input.json` contains the Mina genesis ledger, and an example
target state hash. The code here is based on the replayer app, and
like it, verifies ledger hashes and account balances after each
transactions. If the archive database contains gaps or errors, the
tool will not run successfully.

In the future, we may extend the tool to allow providing a staking
epoch ledger, rather than the genesis ledger, so that only recent
epochs need to be checked, which will save time.
