CREATE TABLE public_keys
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_public_keys_value ON public_keys(value);

CREATE TABLE snarked_ledger_hashes
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE INDEX idx_snarked_ledger_hashes_value ON snarked_ledger_hashes(value);

CREATE TYPE user_command_type AS ENUM ('payment', 'delegation');

CREATE TABLE user_commands
( id             serial            PRIMARY KEY
, type           user_command_type NOT NULL
, sender_id      int               NOT NULL REFERENCES public_keys(id)
, receiver_id    int               NOT NULL REFERENCES public_keys(id)
, nonce          bigint            NOT NULL
, amount         bigint            NOT NULL
, fee            bigint            NOT NULL
, memo           text              NOT NULL
, transaction_id int               NOT NULL UNIQUE
);

CREATE TYPE internal_command_type AS ENUM ('fee_transfer', 'coinbase');

CREATE TABLE internal_commands
( id          serial                PRIMARY KEY
, type        internal_command_type NOT NULL
, receiver_id int                   NOT NULL REFERENCES public_keys(id)
, fee         bigint                NOT NULL
, transaction_id      int    NOT NULL UNIQUE
);

CREATE TABLE transactions
( id                  serial PRIMARY KEY
, hash                text   NOT NULL UNIQUE
, user_command_id     int    REFERENCES user_commands(id)
, internal_command_id int    REFERENCES internal_commands(id)
);

CREATE INDEX idx_transactions_hash ON transactions(hash);

ALTER TABLE user_commands     ADD FOREIGN KEY (transaction_id) REFERENCES transactions(id);
ALTER TABLE internal_commands ADD FOREIGN KEY (transaction_id) REFERENCES transactions(id);

CREATE TABLE blocks
( id                     serial PRIMARY KEY
, state_hash             text   NOT NULL UNIQUE
, parent_id              int    NOT NULL        REFERENCES blocks(id)
, creator_id             int    NOT NULL        REFERENCES public_keys(id)
, snarked_ledger_hash_id int    NOT NULL        REFERENCES snarked_ledger_hashes(id)
, ledger_hash            text   NOT NULL
, height                 bigint NOT NULL
, timestamp              bigint NOT NULL
, coinbase_id            int    NOT NULL UNIQUE REFERENCES internal_commands(id)
);

CREATE INDEX idx_blocks_state_hash ON blocks(state_hash);
CREATE INDEX idx_blocks_create_id  ON blocks(creator_id);
CREATE INDEX idx_blocks_height     ON blocks(height);

CREATE TABLE blocks_transactions
( block_id       int NOT NULL REFERENCES blocks(id)
, transaction_id int NOT NULL REFERENCES transactions(id)
, PRIMARY KEY (block_id, transaction_id)
);
