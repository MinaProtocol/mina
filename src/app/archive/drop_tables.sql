/* delete all relations and types from the archive database

   it is not necessary to explicitly drop indexes, they're removed when dropping the relation
    containing the indexed column
*/

DROP TABLE blocks_internal_commands;

DROP TABLE blocks_user_commands;

DROP TABLE blocks_zkapp_commands;

DROP TABLE zkapp_party_failures;

DROP TABLE accounts_accessed;

DROP TABLE accounts_created;

DROP TABLE blocks;

DROP TYPE chain_status_type;

DROP TABLE epoch_data;

DROP TABLE internal_commands;

DROP TYPE internal_command_type;

DROP TABLE user_commands;

DROP TYPE user_command_type;

DROP TYPE user_command_status;

DROP TABLE zkapp_commands;

DROP TABLE zkapp_other_party;

DROP TABLE zkapp_fee_payers;

DROP TABLE zkapp_fee_payer_body;

DROP TABLE zkapp_other_party_body;

DROP TYPE call_type_type;

DROP TABLE zkapp_updates;

DROP TABLE zkapp_protocol_state_precondition;

DROP TABLE zkapp_account_precondition;

DROP TABLE zkapp_precondition_accounts;

DROP TABLE zkapp_accounts;

DROP TABLE zkapp_epoch_data;

DROP TABLE zkapp_epoch_ledger;

DROP TABLE zkapp_permissions;

DROP TABLE zkapp_state_data_array;

DROP TABLE zkapp_states;

DROP TABLE zkapp_state_data;

DROP TABLE zkapp_timing_info;

DROP TABLE zkapp_verification_keys;

DROP TABLE zkapp_amount_bounds;

DROP TABLE zkapp_balance_bounds;

DROP TABLE zkapp_length_bounds;

DROP TABLE zkapp_global_slot_bounds;

DROP TABLE zkapp_nonce_bounds;

DROP TABLE zkapp_timestamp_bounds;

DROP TABLE zkapp_token_id_bounds;

DROP TYPE zkapp_auth_required_type;

DROP TYPE zkapp_authorization_kind_type;

DROP TYPE zkapp_precondition_type;

DROP TABLE snarked_ledger_hashes;

DROP TABLE timing_info;

DROP TABLE account_identifiers;

DROP TABLE zkapp_sequence_states;

DROP TABLE zkapp_uris;

DROP TABLE tokens;

DROP TABLE public_keys;

DROP TABLE zkapp_events;

DROP TABLE token_symbols;

DROP TABLE voting_for;
