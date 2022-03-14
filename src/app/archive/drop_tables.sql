/* delete all relations and types from the archive database

   it is not necessary to explicitly drop indexes, they're removed when dropping the relation
    containing the indexed column
*/

DROP TABLE blocks_internal_commands;

DROP TABLE blocks_user_commands;

DROP TABLE blocks_snapp_commands;

DROP TABLE snapp_party_balances;

DROP TABLE balances;

DROP TABLE blocks;

DROP TABLE epoch_data;

DROP TABLE internal_commands;

DROP TYPE internal_command_type;

DROP TABLE user_commands;

DROP TYPE user_command_type;

DROP TYPE user_command_status;

DROP TABLE snapp_commands;

DROP TABLE snapp_party;

DROP TABLE snapp_fee_payers;

DROP TABLE snapp_party_body;

DROP TABLE snapp_updates;

DROP TABLE snapp_predicate_protocol_states;

DROP TABLE snapp_predicate;

DROP TABLE snapp_account;

DROP TABLE snapp_epoch_data;

DROP TABLE snapp_epoch_ledger;

DROP TABLE snapp_permissions;

DROP TABLE snapp_state_data_array;

DROP TABLE snapp_states;

DROP TABLE snapp_state_data;

DROP TABLE snapp_timing_info;

DROP TABLE snapp_verification_keys;

DROP TABLE snapp_amount_bounds;

DROP TABLE snapp_balance_bounds;

DROP TABLE snapp_length_bounds;

DROP TABLE snapp_global_slot_bounds;

DROP TABLE snapp_nonce_bounds;

DROP TABLE snapp_timestamp_bounds;

DROP TABLE snapp_token_id_bounds;

DROP TYPE snapp_auth_required_type;

DROP TYPE snapp_authorization_kind_type;

DROP TYPE snapp_predicate_type;

DROP TABLE snarked_ledger_hashes;

DROP TABLE timing_info;

DROP TABLE public_keys;
