/* delete all relations and types from the archive database

   it is not necessary to explicitly drop indexes, they're removed when dropping the relation
    containing the indexed column
*/

drop table blocks_internal_commands;

drop table blocks_user_commands;

drop table blocks_snapp_commands;

drop table snapp_party_balances;

drop table balances;

drop table blocks;

drop table epoch_data;

drop table internal_commands;

drop type internal_command_type;

drop table user_commands;

drop type user_command_type;

drop type user_command_status;

drop table snapp_commands;

drop table snapp_other_parties;

drop table snapp_party;

drop table snapp_fee_payers;

drop table snapp_party_predicated;

drop table snapp_party_body;

drop table snapp_updates;

drop table snapp_protocol_states;

drop table snapp_predicate;

drop table snapp_predicate_account;

drop table snapp_epoch_data;

drop table snapp_epoch_ledger;

drop table snapp_events;

drop table snapp_permissions;

drop table snapp_state_array;

drop table snapp_states;

drop table snapp_state_data;

drop table snapp_timing_info;

drop table snapp_verification_keys;

drop table snapp_bounded_amount;

drop table snapp_bounded_balance;

drop table snapp_bounded_blockchain_length;

drop table snapp_bounded_global_slot;

drop table snapp_bounded_nonce;

drop table snapp_bounded_timestamp;

drop table snapp_bounded_token_id;

drop type snapp_auth_required_type;

drop type snapp_authorization_kind_type;

drop type snapp_predicate_type;

drop table snarked_ledger_hashes;

drop table timing_info;

drop table public_keys;
