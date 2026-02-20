# dump_account_hashes

A standalone CLI tool to dump important account hash constants used in the Mina protocol.

## Purpose

This tool prints the default zkApp account digest hash value in JSON format, matching the format used in ledger JSON implementations. This is useful for:

- Understanding the default hash value used when an account's `zkapp` field is `None`
- Debugging ledger hash computations
- Verifying consistency across different ledger implementations

## Output Format

The tool outputs a JSON object with the following structure:

```json
{
  "default_zkapp_account_digest": "<field_element_string>"
}
```

The hash is computed from the default zkApp account structure which contains:
- **app_state**: Vector of 8 zero field elements
- **verification_key**: `None`
- **zkapp_version**: `0`
- **action_state**: 5 copies of `Actions.empty_state_element`
- **last_action_slot**: `0`
- **proved_state**: `false`
- **zkapp_uri**: `""` (empty string)

## Building

```bash
dune build src/app/dump_account_hashes/dump_account_hashes.exe
```

## Running

```bash
./_build/default/src/app/dump_account_hashes/dump_account_hashes.exe
```

## Implementation Details

The tool uses:
- `Mina_base.Zkapp_account.default_digest` to get the lazy-evaluated default digest
- `Snark_params.Tick.Field.to_string` to convert the field element to string format
- `Yojson.Basic.pretty_to_string` to format the output as pretty JSON

This matches the format used in `genesis_ledger_helper.ml` for ledger hash computations.
