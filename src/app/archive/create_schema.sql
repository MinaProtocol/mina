/* the Postgresql schema used by the Mina archive database */

/* there are a number of values represented by a Postgresql bigint here, which is a 64-bit signed value,
   while in OCaml, the value is represented by a 64-bit unsigned value, so that overflow is
   possible

   while overflow is unlikely, because a bigint can be very large, it's possible in theory

   that describes almost all the bigint values below, except for those representing
   nonces and slots, which are unsigned 32-bit values in OCaml

*/

/* the tables below named `blocks_xxx_commands`, where xxx is `user`, `internal`, or `zkapps`,
   contain columns `block_id` and `xxx_command_id`

   this naming convention must be followed for `find_command_ids_query` in `Replayer.Sql`
   to work properly

   the comment "Blocks command convention" indicates the use of this convention
*/

CREATE TABLE public_keys
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_public_keys_id ON public_keys(id);
CREATE INDEX idx_public_keys_value ON public_keys(value);

/* the initial balance is the balance at genesis, whether the account is timed or not
   for untimed accounts, the fields other than id, public_key_id, and token are 0
*/
CREATE TABLE timing_info
( id                      serial    PRIMARY KEY
, public_key_id           int       NOT NULL REFERENCES public_keys(id)
, token                   text      NOT NULL
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
, fee_token      text                NOT NULL
, token          text                NOT NULL
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
, token       text                  NOT NULL
, hash        text                  NOT NULL
, UNIQUE (hash,type)
);

/* import supporting Zkapp-related tables */
\ir zkapp_tables.sql

CREATE TABLE zkapp_fee_payers
( id                       serial           PRIMARY KEY
, body_id                  int              NOT NULL REFERENCES zkapp_party_body(id)
);

/* zkapp_other_parties_ids refers to a list of ids in zkapp_party.
   The values in zkapp_other_parties_ids are unenforced foreign keys, and
   not NULL. */
CREATE TABLE zkapp_commands
( id                                    serial         PRIMARY KEY
, zkapp_fee_payer_id                    int            NOT NULL REFERENCES zkapp_fee_payers(id)
, zkapp_other_parties_ids               int[]          NOT NULL
, hash                                  text           NOT NULL UNIQUE
);

CREATE TABLE epoch_data
( id               serial PRIMARY KEY
, seed             text   NOT NULL
, ledger_hash_id   int    NOT NULL REFERENCES snarked_ledger_hashes(id)
, total_currency   bigint NOT NULL
, start_checkpoint text   NOT NULL
, lock_checkpoint  text   NOT NULL
, epoch_length     int    NOT NULL
);

CREATE TYPE chain_status_type AS ENUM ('canonical', 'orphaned', 'pending');

CREATE TABLE blocks
( id                           serial PRIMARY KEY
, state_hash                   text   NOT NULL UNIQUE
, parent_id                    int                    REFERENCES blocks(id)
, parent_hash                  text   NOT NULL
, creator_id                   int    NOT NULL        REFERENCES public_keys(id)
, block_winner_id              int    NOT NULL        REFERENCES public_keys(id)
, snarked_ledger_hash_id       int    NOT NULL        REFERENCES snarked_ledger_hashes(id)
, staking_epoch_data_id        int    NOT NULL        REFERENCES epoch_data(id)
, next_epoch_data_id           int    NOT NULL        REFERENCES epoch_data(id)
, min_window_density           bigint NOT NULL
, total_currency               bigint NOT NULL
, ledger_hash                  text   NOT NULL
, height                       bigint NOT NULL
, global_slot_since_hard_fork  bigint NOT NULL
, global_slot_since_genesis    bigint NOT NULL
, timestamp                    bigint NOT NULL
, chain_status                 chain_status_type NOT NULL
);

CREATE INDEX idx_blocks_id ON blocks(id);
CREATE INDEX idx_blocks_parent_id ON blocks(parent_id);
CREATE INDEX idx_blocks_state_hash ON blocks(state_hash);
CREATE INDEX idx_blocks_creator_id ON blocks(creator_id);
CREATE INDEX idx_blocks_height     ON blocks(height);
CREATE INDEX idx_chain_status      ON blocks(chain_status);

/* the block_* columns refer to the block containing a user command or internal command that
    results in a balance
   for a balance resulting from a user command, the secondary sequence no is always 0
   these columns duplicate information available in the
    blocks_user_commands and blocks_internal_commands tables
   they are included here to allow Rosetta account queries to consume
    fewer Postgresql resources
   TODO: nonce column is NULLable until we can establish valid nonces for all rows
*/

CREATE TABLE balances
( id                           serial PRIMARY KEY
, public_key_id                int    NOT NULL REFERENCES public_keys(id)
, balance                      bigint NOT NULL
, block_id                     int    NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, block_height                 int    NOT NULL
, block_sequence_no            int    NOT NULL
, block_secondary_sequence_no  int    NOT NULL
, nonce                        bigint
, UNIQUE (public_key_id,balance,block_id,block_height,block_sequence_no,block_secondary_sequence_no)
);

CREATE INDEX idx_balances_id ON balances(id);
CREATE INDEX idx_balances_public_key_id ON balances(public_key_id);
CREATE INDEX idx_balances_height_seq_nos ON balances(block_height,block_sequence_no,block_secondary_sequence_no);

CREATE TABLE blocks_user_commands
( block_id        int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, user_command_id int NOT NULL REFERENCES user_commands(id) ON DELETE CASCADE
, sequence_no     int NOT NULL
, status          user_command_status NOT NULL
, failure_reason  text
, fee_payer_account_creation_fee_paid bigint
, receiver_account_creation_fee_paid bigint
, created_token     text
, fee_payer_balance int NOT NULL REFERENCES balances(id) ON DELETE CASCADE
, source_balance    int          REFERENCES balances(id) ON DELETE CASCADE
, receiver_balance  int          REFERENCES balances(id) ON DELETE CASCADE
, PRIMARY KEY (block_id, user_command_id, sequence_no)
);

CREATE INDEX idx_blocks_user_commands_block_id ON blocks_user_commands(block_id);
CREATE INDEX idx_blocks_user_commands_user_command_id ON blocks_user_commands(user_command_id);
CREATE INDEX idx_blocks_user_commands_fee_payer_balance ON blocks_user_commands(fee_payer_balance);
CREATE INDEX idx_blocks_user_commands_source_balance ON blocks_user_commands(source_balance);
CREATE INDEX idx_blocks_user_commands_receiver_balance ON blocks_user_commands(receiver_balance);

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
CREATE INDEX idx_blocks_internal_commands_receiver_balance ON blocks_internal_commands(receiver_balance);

/* in this file because reference to balances doesn't work if in zkapp_tables.sql */
CREATE TABLE zkapp_party_balances
( list_id                  int  NOT NULL
, list_index               int  NOT NULL
, balance_id               int  NOT NULL REFERENCES balances(id)
);

/* a join table between blocks and zkapp_commands, with some additional information
   sequence_no gives the order within all transactions in the block

   other_parties_list_id refers to a list of balances in the same order as the other parties in the
   zkapps_command; that is, the list_index for the balances is the same as the list_index for other_parties

   Blocks command convention
*/

CREATE TABLE blocks_zkapp_commands
( block_id                        int  NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, zkapp_command_id                int  NOT NULL REFERENCES zkapp_commands(id) ON DELETE CASCADE
, sequence_no                     int  NOT NULL
, fee_payer_balance_id            int  NOT NULL REFERENCES balances(id)
, other_parties_balances_list_id  int  NOT NULL
, PRIMARY KEY (block_id, zkapp_command_id, sequence_no)
);

CREATE INDEX idx_blocks_zkapp_commands_block_id ON blocks_zkapp_commands(block_id);
CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON blocks_zkapp_commands(zkapp_command_id);
CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON blocks_zkapp_commands(sequence_no);
