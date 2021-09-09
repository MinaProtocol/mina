CREATE TABLE public_keys
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

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

CREATE INDEX idx_blocks_state_hash ON blocks(state_hash);
CREATE INDEX idx_blocks_creator_id ON blocks(creator_id);
CREATE INDEX idx_blocks_height     ON blocks(height);

CREATE TABLE balances
( id            serial PRIMARY KEY
, public_key_id int    NOT NULL REFERENCES public_keys(id)
, balance       bigint NOT NULL
);

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

CREATE TABLE blocks_internal_commands
( block_id              int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, internal_command_id   int NOT NULL REFERENCES internal_commands(id) ON DELETE CASCADE
, sequence_no           int NOT NULL
, secondary_sequence_no int NOT NULL
, receiver_balance      int NOT NULL REFERENCES balances(id) ON DELETE CASCADE
, PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no)
);
