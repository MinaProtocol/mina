/* the Postgresql schema used by the Mina archive database */

/* there are a number of values represented by a Postgresql bigint here, which is a 64-bit signed value,
   while in OCaml, the value is represented by a 64-bit unsigned value, so that overflow is
   possible

   while overflow is unlikely, because a bigint can be very large, it's possible in theory

   that describes almost all the bigint values below, except for those representing
   nonces and slots, which are unsigned 32-bit values in OCaml

*/

/* the tables below named `blocks_xxx_commands`, where xxx is `user`, `internal`, or `snapps`,
   contain columns `block_id` and `xxx_command_id`

   this naming convention must be followed for `find_command_ids_query` in `Replayer.Sql`
   to work properly

   the comment "Blocks command convention" indicates the use of this convention
*/

CREATE TABLE public_keys
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_public_keys_value ON public_keys(value);

/* the initial balance is the balance at genesis, whether the account is timed or not
   for untimed accounts, the fields other than id, public_key_id, and token are 0
*/
CREATE TABLE timing_info
( id                      serial    PRIMARY KEY
, public_key_id           int       NOT NULL REFERENCES public_keys(id)
, token                   bigint    NOT NULL
, initial_balance         bigint    NOT NULL
, initial_minimum_balance bigint    NOT NULL
, cliff_time              bigint    NOT NULL
, cliff_amount            bigint    NOT NULL
, vesting_period          bigint    NOT NULL
, vesting_increment       bigint    NOT NULL
);

CREATE INDEX idx_public_key_id ON timing_info(public_key_id);

CREATE TABLE snarked_ledger_hashes
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_snarked_ledger_hashes_value ON snarked_ledger_hashes(value);

CREATE TYPE user_command_type AS ENUM ('payment', 'delegation', 'create_token', 'create_account', 'mint_tokens');

CREATE TYPE user_command_status AS ENUM ('applied', 'failed');

CREATE TABLE user_commands
( id             serial              PRIMARY KEY
, type           user_command_type   NOT NULL
, fee_payer_id   int                 NOT NULL REFERENCES public_keys(id)
, source_id      int                 NOT NULL REFERENCES public_keys(id)
, receiver_id    int                 NOT NULL REFERENCES public_keys(id)
, fee_token      bigint              NOT NULL
, token          bigint              NOT NULL
, nonce          bigint              NOT NULL
, amount         bigint
, fee            bigint              NOT NULL
, valid_until    bigint
, memo           text                NOT NULL
, hash           text                NOT NULL UNIQUE
);

CREATE TYPE internal_command_type AS ENUM ('fee_transfer_via_coinbase', 'fee_transfer', 'coinbase');

CREATE TABLE internal_commands
( id          serial                PRIMARY KEY
, type        internal_command_type NOT NULL
, receiver_id int                   NOT NULL REFERENCES public_keys(id)
, fee         bigint                NOT NULL
, token       bigint                NOT NULL
, hash        text                  NOT NULL
, UNIQUE (hash,type)
);

/* import supporting Snapp-related tables */
\ir snapp_tables.sql

CREATE TABLE snapp_fee_payers
( id                       serial           PRIMARY KEY
, body_id                  int              NOT NULL REFERENCES snapp_party_body(id)
, nonce                    bigint           NOT NULL
);

/* NULL convention -- see comment at start of snapp_tables.sql */
CREATE TABLE snapp_predicate_protocol_states
( id                               serial                         NOT NULL PRIMARY KEY
, snarked_ledger_hash_id           int                            REFERENCES snarked_ledger_hashes(id)
, snarked_next_available_token_id  int                            REFERENCES snapp_token_id_bounds(id)
, timestamp_id                     int                            REFERENCES snapp_timestamp_bounds(id)
, blockchain_length_id             int                            REFERENCES snapp_length_bounds(id)
, min_window_density_id            int                            REFERENCES snapp_length_bounds(id)
/* omitting 'last_vrf_output' for now, it's the unit value in OCaml */
, total_currency_id                int                            REFERENCES snapp_amount_bounds(id)
, curr_global_slot_since_hard_fork int                            REFERENCES snapp_global_slot_bounds(id)
, global_slot_since_genesis        int                            REFERENCES snapp_global_slot_bounds(id)
, staking_epoch_data_id            int                            REFERENCES snapp_epoch_data(id)
, next_epoch_data                  int                            REFERENCES snapp_epoch_data(id)
);

/* snapp_other_parties_ids refers to a list of ids in snapp_party.
   The values in snapp_other_parties_ids are unenforced foreign keys, and
   not NULL. */
CREATE TABLE snapp_commands
( id                                    serial         PRIMARY KEY
, snapp_fee_payer_id                    int            NOT NULL REFERENCES snapp_fee_payers(id)
, snapp_other_parties_ids               int[]          NOT NULL
, snapp_predicate_protocol_state_id     int            NOT NULL REFERENCES snapp_predicate_protocol_states(id)
, hash                                  text           NOT NULL UNIQUE
);

CREATE TABLE epoch_data
( id             serial PRIMARY KEY
, seed           text   NOT NULL
, ledger_hash_id int    NOT NULL REFERENCES snarked_ledger_hashes(id)
);

CREATE TABLE blocks
( id                      serial PRIMARY KEY
, state_hash              text   NOT NULL UNIQUE
, parent_id               int                    REFERENCES blocks(id)
, parent_hash             text   NOT NULL
, creator_id              int    NOT NULL        REFERENCES public_keys(id)
, block_winner_id         int    NOT NULL        REFERENCES public_keys(id)
, snarked_ledger_hash_id  int    NOT NULL        REFERENCES snarked_ledger_hashes(id)
, staking_epoch_data_id   int    NOT NULL        REFERENCES epoch_data(id)
, next_epoch_data_id      int    NOT NULL        REFERENCES epoch_data(id)
, ledger_hash             text   NOT NULL
, height                  bigint NOT NULL
, global_slot             bigint NOT NULL
, global_slot_since_genesis bigint NOT NULL
, timestamp               bigint NOT NULL
);

CREATE INDEX idx_blocks_id ON blocks(id);
CREATE INDEX idx_blocks_parent_id ON blocks(parent_id);
CREATE INDEX idx_blocks_state_hash ON blocks(state_hash);
CREATE INDEX idx_blocks_creator_id ON blocks(creator_id);
CREATE INDEX idx_blocks_height     ON blocks(height);

/* a balance is associated with a public key after a particular transaction
   the token id is given by the transaction, but implicit in this table
*/
CREATE TABLE balances
( id            serial PRIMARY KEY
, public_key_id int    NOT NULL REFERENCES public_keys(id)
, balance       bigint NOT NULL
);

/* a join table between blocks and user_commands, with some additional information
   sequence_no gives the order within all transactions in the block

   Blocks command convention
*/
CREATE TABLE blocks_user_commands
( block_id        int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, user_command_id int NOT NULL REFERENCES user_commands(id) ON DELETE CASCADE
, sequence_no     int NOT NULL
, status          user_command_status NOT NULL
, failure_reason  text
, fee_payer_account_creation_fee_paid bigint
, receiver_account_creation_fee_paid bigint
, created_token     bigint
, fee_payer_balance int NOT NULL REFERENCES balances(id) ON DELETE CASCADE
, source_balance    int          REFERENCES balances(id) ON DELETE CASCADE
, receiver_balance  int          REFERENCES balances(id) ON DELETE CASCADE
, PRIMARY KEY (block_id, user_command_id, sequence_no)
);

CREATE INDEX idx_blocks_user_commands_block_id ON blocks_user_commands(block_id);
CREATE INDEX idx_blocks_user_commands_user_command_id ON blocks_user_commands(user_command_id);

/* a join table between blocks and internal_commands, with some additional information
   the pair sequence_no, secondary_sequence_no gives the order within all transactions in the block

   Blocks command convention
*/
CREATE TABLE blocks_internal_commands
( block_id              int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, internal_command_id   int NOT NULL REFERENCES internal_commands(id) ON DELETE CASCADE
, sequence_no           int NOT NULL
, secondary_sequence_no int NOT NULL
, receiver_account_creation_fee_paid bigint
, receiver_balance      int NOT NULL REFERENCES balances(id) ON DELETE CASCADE
, PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no)
);

CREATE INDEX idx_blocks_internal_commands_block_id ON blocks_internal_commands(block_id);
CREATE INDEX idx_blocks_internal_commands_internal_command_id ON blocks_internal_commands(internal_command_id);

/* in this file because reference to balances doesn't work if in snapp_tables.sql */
CREATE TABLE snapp_party_balances
( list_id                  int  NOT NULL
, list_index               int  NOT NULL
, balance_id               int  NOT NULL REFERENCES balances(id)
);

/* a join table between blocks and snapp_commands, with some additional information
   sequence_no gives the order within all transactions in the block

   other_parties_list_id refers to a list of balances in the same order as the other parties in the
   snapps_command; that is, the list_index for the balances is the same as the list_index for other_parties

   Blocks command convention
*/

CREATE TABLE blocks_snapp_commands
( block_id                        int  NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, snapp_command_id                int  NOT NULL REFERENCES snapp_commands(id) ON DELETE CASCADE
, sequence_no                     int  NOT NULL
, fee_payer_balance_id            int  NOT NULL REFERENCES balances(id)
, other_parties_balances_list_id  int  NOT NULL
, PRIMARY KEY (block_id, snapp_command_id, sequence_no)
);

CREATE INDEX idx_blocks_snapp_commands_block_id ON blocks_snapp_commands(block_id);
CREATE INDEX idx_blocks_snapp_commands_snapp_command_id ON blocks_snapp_commands(snapp_command_id);
CREATE INDEX idx_blocks_snapp_commands_sequence_no ON blocks_snapp_commands(sequence_no);
