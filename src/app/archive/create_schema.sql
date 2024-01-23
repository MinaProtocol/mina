CREATE TABLE public_keys
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_public_keys_id ON public_keys(id);
CREATE INDEX idx_public_keys_value ON public_keys(value);

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

CREATE TABLE epoch_data
( id             serial PRIMARY KEY
, seed           text   NOT NULL
, ledger_hash_id int    NOT NULL REFERENCES snarked_ledger_hashes(id)
);

CREATE TYPE chain_status_type AS ENUM ('canonical', 'orphaned', 'pending');

CREATE TABLE blocks
( id                         serial PRIMARY KEY
, state_hash                 text   NOT NULL UNIQUE
, parent_id                  int                    REFERENCES blocks(id)
, parent_hash                text   NOT NULL
, creator_id                 int    NOT NULL        REFERENCES public_keys(id)
, block_winner_id            int    NOT NULL        REFERENCES public_keys(id)
, snarked_ledger_hash_id     int    NOT NULL        REFERENCES snarked_ledger_hashes(id)
, staking_epoch_data_id      int    NOT NULL        REFERENCES epoch_data(id)
, next_epoch_data_id         int    NOT NULL        REFERENCES epoch_data(id)
, ledger_hash                text   NOT NULL
, height                     bigint NOT NULL
, global_slot                bigint NOT NULL
, global_slot_since_genesis  bigint NOT NULL
, timestamp                  bigint NOT NULL
, chain_status               chain_status_type NOT NULL
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
, created_token     bigint
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
