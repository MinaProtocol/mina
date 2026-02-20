# dump_account_hashes

A standalone CLI tool to dump important account hash constants used in the Mina protocol.

## Purpose

This tool prints important account hash constants used in the Mina protocol in JSON format, matching the format used in ledger JSON implementations. This is useful for:

- Understanding the default hash value used when an account's `zkapp` field is `None`
- Getting the dummy verification key hash used in zkApp accounts
- Getting the non-preimage hash for zkApp URIs
- Debugging ledger hash computations
- Verifying consistency across different ledger implementations

## Output Format

The tool outputs a JSON object with the following structure:

```json
{
  "default_zkapp_account_digest": "<field_element_string>",
  "dummy_vk_hash": "<field_element_string>",
  "zkapp_uri_non_preimage_hash": "<field_element_string>"
}
```

### Hash Descriptions

**default_zkapp_account_digest**: The hash computed from the default zkApp account structure which contains:
- **app_state**: Vector of 8 zero field elements
- **verification_key**: `None`
- **zkapp_version**: `0`
- **action_state**: 5 copies of `Actions.empty_state_element`
- **last_action_slot**: `0`
- **proved_state**: `false`
- **zkapp_uri**: `""` (empty string)

This value is used in account hash computation when `zkapp = None`.

**dummy_vk_hash**: The hash of the dummy side-loaded verification key, used as a placeholder value in zkApp account hashes when no verification key is set.

**zkapp_uri_non_preimage_hash**: A special non-preimage hash for zkApp URIs, used when `zkapp_uri = None`. This hash is constructed to be unattainable by any actual string (due to a trailing `true` bit added during hashing), preventing hash collisions with empty strings or strings with trailing null bytes.

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
- `Mina_base.Zkapp_account.default_digest` to get the lazy-evaluated default zkApp account digest
- `Mina_base.Verification_key_wire.dummy_vk_hash` to get the dummy verification key hash
- `Mina_base.Zkapp_account.zkapp_uri_non_preimage_hash` to get the zkApp URI non-preimage hash
- `Snark_params.Tick.Field.to_string` to convert field elements to string format
- `Yojson.Basic.pretty_to_string` to format the output as pretty JSON

This matches the format used in `genesis_ledger_helper.ml` for ledger hash computations.
