For now a collection of shell scripts that hit different endpoints for manual verification. This may evolve into proper [gold master testing](https://en.wikipedia.org/wiki/Characterization_test) at some point (see #5306)

# tmp

Most of these tests need to be fixed at the moment.

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



# rosetta-cli 

Using the `mina.ros` file from this folder, in the local sandbox:
- the `rosetta-cli` tool successfully creates accounts.
- some funds need to be added to them manually, to make the `request_funds` step pass.
- the `transfer` test now works with some manual funding of some account that may be replaced by the use of rosetta `prefunded_accounts`.
  this tests all the endpoints of the construction api.
- testing the `delegation` remains to be done.
 

Fixing this issue is required for the transfer test to succeed:
  The default value for the `validUntil` field (present in the signed payload) seems different on the two sides.
  - https://github.com/coinbase/rosetta-sdk-go/blob/master/keys/signer_pallas.go#L195
  - https://github.com/MinaProtocol/mina/blob/develop/src/lib/mina_base/signed_command_payload.ml#L310
