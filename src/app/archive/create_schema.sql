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

/* for the default token only, owner_public_key_id and owner_token_id are NULL
   for other tokens, those columns are non-NULL
*/
CREATE TABLE tokens
( id                   serial  PRIMARY KEY
, value                text    NOT NULL  UNIQUE
, owner_public_key_id  int               REFERENCES public_keys(id) ON DELETE CASCADE
, owner_token_id       int               REFERENCES tokens(id)
);

CREATE TABLE token_symbols
( id          serial PRIMARY KEY
, value text  NOT NULL
);

CREATE INDEX idx_token_symbols_value ON token_symbols(value);

CREATE TABLE account_identifiers
( id                 serial  PRIMARY KEY
, public_key_id      int     NOT NULL     REFERENCES public_keys(id) ON DELETE CASCADE
, token_id           int     NOT NULL     REFERENCES tokens(id) ON DELETE CASCADE
, UNIQUE (public_key_id,token_id)
);

/* for untimed accounts, the fields other than id, account_identifier_id, and token are 0
*/
CREATE TABLE timing_info
( id                      serial    PRIMARY KEY
, account_identifier_id   int       NOT NULL UNIQUE REFERENCES account_identifiers(id)
, initial_minimum_balance bigint    NOT NULL
, cliff_time              bigint    NOT NULL
, cliff_amount            bigint    NOT NULL
, vesting_period          bigint    NOT NULL
, vesting_increment       bigint    NOT NULL
);

CREATE TABLE snarked_ledger_hashes
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE TYPE user_command_type AS ENUM ('payment', 'delegation');

CREATE TYPE user_command_status AS ENUM ('applied', 'failed');

CREATE TABLE user_commands
( id             serial              PRIMARY KEY
, typ            user_command_type   NOT NULL
, fee_payer_id   int                 NOT NULL REFERENCES account_identifiers(id)
, source_id      int                 NOT NULL REFERENCES account_identifiers(id)
, receiver_id    int                 NOT NULL REFERENCES account_identifiers(id)
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
, typ         internal_command_type NOT NULL
, receiver_id int                   NOT NULL REFERENCES account_identifiers(id)
, fee         bigint                NOT NULL
, hash        text                  NOT NULL
, UNIQUE (hash,typ)
);

/* block state hashes mentioned in voting_for fields */
CREATE TABLE voting_for
( id          serial PRIMARY KEY
, value text  NOT NULL
);

CREATE INDEX idx_voting_for_value ON voting_for(value);

/* import supporting Zkapp-related tables */
\ir zkapp_tables.sql

/* in OCaml, there's a Fee_payer type, which contains a
   a signature and a reference to the fee payer body. Because
   we don't store a signature, the fee payer here refers
   directly to the fee payer body.

   zkapp_other_parties_ids refers to a list of ids in zkapp_party.
   The values in zkapp_other_parties_ids are unenforced foreign keys
   that reference zkapp_party_body(id), and not NULL.
*/
CREATE TABLE zkapp_commands
( id                                    serial         PRIMARY KEY
, zkapp_fee_payer_body_id               int            NOT NULL REFERENCES zkapp_fee_payer_body(id)
, zkapp_other_parties_ids               int[]          NOT NULL
, memo                                  text           NOT NULL
, hash                                  text           NOT NULL UNIQUE
);

CREATE TABLE epoch_data
( id               serial PRIMARY KEY
, seed             text   NOT NULL
, ledger_hash_id   int    NOT NULL REFERENCES snarked_ledger_hashes(id)
, total_currency   bigint NOT NULL
, start_checkpoint text   NOT NULL
, lock_checkpoint  text   NOT NULL
, epoch_length     bigint NOT NULL
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

CREATE INDEX idx_blocks_parent_id  ON blocks(parent_id);
CREATE INDEX idx_blocks_creator_id ON blocks(creator_id);
CREATE INDEX idx_blocks_height     ON blocks(height);
CREATE INDEX idx_chain_status      ON blocks(chain_status);

/* accounts accessed in a block, representing the account
   state after all transactions in the block have been executed
*/
CREATE TABLE accounts_accessed
( ledger_index            int     NOT NULL
, block_id                int     NOT NULL  REFERENCES blocks(id)
, account_identifier_id   int     NOT NULL  REFERENCES account_identifiers(id)
, token_symbol_id         int     NOT NULL  REFERENCES token_symbols(id)
, balance                 bigint  NOT NULL
, nonce                   bigint  NOT NULL
, receipt_chain_hash      text    NOT NULL
, delegate_id             int               REFERENCES public_keys(id)
, voting_for_id           int     NOT NULL  REFERENCES voting_for(id)
, timing_id               int               REFERENCES timing_info(id)
, permissions_id          int     NOT NULL  REFERENCES zkapp_permissions(id)
, zkapp_id                int               REFERENCES zkapp_accounts(id)
, PRIMARY KEY (block_id,account_identifier_id)
);

CREATE INDEX idx_accounts_accessed_block_id ON accounts_accessed(block_id);
CREATE INDEX idx_accounts_accessed_block_account_identifier_id ON accounts_accessed(account_identifier_id);

/* accounts created in a block */
CREATE TABLE accounts_created
( block_id                int     NOT NULL  REFERENCES blocks(id)
, account_identifier_id   int     NOT NULL  REFERENCES account_identifiers(id)
, creation_fee            bigint  NOT NULL
, PRIMARY KEY (block_id,account_identifier_id)
);

CREATE INDEX idx_accounts_created_block_id ON accounts_created(block_id);
CREATE INDEX idx_accounts_created_block_account_identifier_id ON accounts_created(account_identifier_id);

CREATE TABLE blocks_user_commands
( block_id        int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, user_command_id int NOT NULL REFERENCES user_commands(id) ON DELETE CASCADE
, sequence_no     int NOT NULL
, status          user_command_status NOT NULL
, failure_reason  text
, PRIMARY KEY (block_id, user_command_id, sequence_no)
);

CREATE INDEX idx_blocks_user_commands_block_id ON blocks_user_commands(block_id);
CREATE INDEX idx_blocks_user_commands_user_command_id ON blocks_user_commands(user_command_id);
CREATE INDEX idx_blocks_user_commands_sequence_no ON blocks_user_commands(sequence_no);

/* a join table between blocks and internal_commands, with some additional information
   the pair sequence_no, secondary_sequence_no gives the order within all transactions in the block

   Blocks command convention
*/
CREATE TABLE blocks_internal_commands
( block_id              int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, internal_command_id   int NOT NULL REFERENCES internal_commands(id) ON DELETE CASCADE
, sequence_no           int NOT NULL
, secondary_sequence_no int NOT NULL
, PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no)
);

CREATE INDEX idx_blocks_internal_commands_block_id ON blocks_internal_commands(block_id);
CREATE INDEX idx_blocks_internal_commands_internal_command_id ON blocks_internal_commands(internal_command_id);
CREATE INDEX idx_blocks_internal_commands_sequence_no ON blocks_internal_commands(sequence_no);
CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON blocks_internal_commands(secondary_sequence_no);

/* a join table between blocks and zkapp_commands
   sequence_no gives the order within all transactions in the block

   The `failure_reasons` column is not NULL iff `status` is `failed`. The
   entries in the array are unenforced foreign key references to `zkapp_party_failures(id)`.
   Each element of the array refers to the failures for a party in `other_parties`, and
   is not NULL.

   Blocks command convention
*/

CREATE TABLE blocks_zkapp_commands
( block_id                        int                 NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, zkapp_command_id                int                 NOT NULL REFERENCES zkapp_commands(id) ON DELETE CASCADE
, sequence_no                     int                 NOT NULL
, status                          user_command_status NOT NULL
, failure_reasons_ids             int[]
, PRIMARY KEY (block_id, zkapp_command_id, sequence_no)
);

CREATE INDEX idx_blocks_zkapp_commands_block_id ON blocks_zkapp_commands(block_id);
CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON blocks_zkapp_commands(zkapp_command_id);
CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON blocks_zkapp_commands(sequence_no);
