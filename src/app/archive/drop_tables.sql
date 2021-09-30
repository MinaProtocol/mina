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

drop type internal_command_type;

DROP TABLE user_commands;

drop type user_command_type;

drop type user_command_status;

DROP TABLE snapp_commands;

DROP TABLE snapp_other_parties;

DROP TABLE snapp_party;

DROP TABLE snapp_fee_payers;

DROP TABLE snapp_party_predicated;

DROP TABLE snapp_party_body;

DROP TABLE snapp_updates;

DROP TABLE snapp_protocol_states;

DROP TABLE snapp_predicate;

DROP TABLE snapp_predicate_account;

DROP TABLE snapp_epoch_data;

DROP TABLE snapp_epoch_ledger;

DROP TABLE snapp_events;

DROP TABLE snapp_permissions;

DROP TABLE snapp_state_array;

DROP TABLE snapp_states;

DROP TABLE snapp_state_data;

DROP TABLE snapp_timing_info;

DROP TABLE snapp_verification_keys;

DROP TABLE snapp_bounded_amount;

DROP TABLE snapp_bounded_balance;

DROP TABLE snapp_bounded_blockchain_length;

DROP TABLE snapp_bounded_global_slot;

DROP TABLE snapp_bounded_nonce;

DROP TABLE snapp_bounded_timestamp;

DROP TABLE snapp_bounded_token_id;

drop type snapp_auth_required_type;

drop type snapp_authorization_kind_type;

drop type snapp_predicate_type;

DROP TABLE snarked_ledger_hashes;

DROP TABLE timing_info;

DROP TABLE public_keys;
