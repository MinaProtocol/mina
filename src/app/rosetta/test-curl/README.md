For now a collection of shell scripts that hit different endpoints for manual verification. This may evolve into proper [gold master testing](https://en.wikipedia.org/wiki/Characterization_test) at some point (see #5306)


# rosetta-cli construction tests

Using the `mina.ros` file from the parent folder, in the local sandbox:
- [x] the `rosetta-cli` tool successfully creates accounts.
- [x] some funds need to be added to them manually, to make the `request_funds` step pass.
- [x] the `transfer` test now works with some manual funding of some account.
- [x] this tests all the endpoints of the construction api.
- [ ] the manual funding of the accounts may be replaced by the use of rosetta `prefunded_accounts` which should simplify the test setup.
- [ ] testing transactions representing `delegations` remains to be done.
- [ ] The following issue should be fixed on the rosetta-cli side:
  The default value for the `validUntil` field (present in the signed payload) seems different on the two sides.
  - https://github.com/coinbase/rosetta-sdk-go/blob/master/keys/signer_pallas.go#L195
  - https://github.com/MinaProtocol/mina/blob/develop/src/lib/mina_base/signed_command_payload.ml#L310

- [ ] in the meantime it may be possible to only generate tests where this field is present to work around this problem.

# tmp

Most of these tests need to be fixed at the moment, but the `rosetta-cli` tools already tests all theses endpoints.

## `con_metadata.sh`

- The option objects now needs a receiver field in the query.
- It seems that if no transaction happenned in a while the `fees` Array can be empty [here](https://github.com/MinaProtocol/mina/blob/develop/src/app/rosetta/lib/construction.ml#L280) which provoques a failure.

## `con_derive.sh`

This seems to work if we use the recently added `pallas` curve type (see [here](https://github.com/coinbase/rosetta-sdk-go/blob/master/keys/signer_pallas.go)).

## `con_preprocess.sh`

The script uses `1` as `token_id`, but it now should be a `base58-encoded-field-element`.

If the `token_id` is invalid, [This call](https://github.com/MinaProtocol/mina/blob/develop/src/lib/rosetta_lib/amount_of.ml#L17) now returns a `Base58_check.Invalid_base58_check_length` instead of a `Failure` one, that should also be caught here.

## `con_combine.sh`
`createToken`,`createTokenAccount`, and `mintTokens` fields are obsolte.

## `con_parse.sh`
failing: TODO
## `con_parse_signed.sh`
failing: TODO
## `con_payloads.sh`
Same `token_id` issue as `con_preprocess.sh`
## `con_submit.sh`
failing: TODO


