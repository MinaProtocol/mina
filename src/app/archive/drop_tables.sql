/* delete all relations and types from the archive database

   it is not necessary to explicitly drop indexes, they're removed when dropping the relation
    containing the indexed column
*/

DROP TABLE blocks_internal_commands;

DROP TABLE blocks_user_commands;

DROP TABLE blocks_zkapp_commands;

DROP TABLE zkapp_account_update_failures;

DROP TABLE accounts_accessed;

DROP TABLE accounts_created;

DROP TABLE blocks;

DROP TABLE protocol_versions;

DROP TYPE chain_status_type;

DROP TABLE epoch_data;

DROP TABLE internal_commands;

DROP TYPE internal_command_type;

DROP TABLE user_commands;

DROP TYPE user_command_type;

DROP TYPE transaction_status;

DROP TABLE zkapp_commands;

DROP TABLE zkapp_fee_payer_body;

DROP TABLE zkapp_account_update;

DROP TABLE zkapp_account_update_body;

DROP TYPE may_use_token;

DROP TYPE authorization_kind_type;

DROP TABLE zkapp_updates;

DROP TABLE zkapp_network_precondition;

DROP TABLE zkapp_account_precondition;

DROP TABLE zkapp_accounts;

DROP TABLE zkapp_epoch_data;

DROP TABLE zkapp_epoch_ledger;

DROP TABLE zkapp_permissions;

DROP TABLE zkapp_field_array;

DROP TABLE zkapp_states_nullable;

DROP TABLE zkapp_states;

DROP TABLE zkapp_field;

DROP TABLE zkapp_timing_info;

DROP TABLE zkapp_verification_keys;

DROP TABLE zkapp_amount_bounds;

DROP TABLE zkapp_balance_bounds;

DROP TABLE zkapp_length_bounds;

DROP TABLE zkapp_global_slot_bounds;

DROP TABLE zkapp_nonce_bounds;

DROP TABLE zkapp_token_id_bounds;

DROP TYPE zkapp_auth_required_type;

DROP TABLE snarked_ledger_hashes;

DROP TABLE timing_info;

DROP TABLE account_identifiers;

DROP TABLE zkapp_action_states;

DROP TABLE zkapp_uris;

DROP TABLE tokens;

DROP TABLE public_keys;

DROP TABLE zkapp_events;

DROP TABLE token_symbols;

DROP TABLE voting_for;

DROP TABLE zkapp_field;

DROP TABLE zkapp_verification_key_hashes;
