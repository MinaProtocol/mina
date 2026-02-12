/* the Postgresql schema used by the Mina archive database */

/* Unsigned 64-bit values in OCaml are represented by text values in the database,
   and string values in the type `t`s in the modules below.

   Unsigned 32-bit values are represented by bigint values in the database, and
   int64 values in the `t`s
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
, account_identifier_id   int       NOT NULL REFERENCES account_identifiers(id)
, initial_minimum_balance text      NOT NULL
, cliff_time              bigint    NOT NULL
, cliff_amount            text      NOT NULL
, vesting_period          bigint    NOT NULL
, vesting_increment       text      NOT NULL
);

CREATE TABLE snarked_ledger_hashes
( id    serial PRIMARY KEY
, value text   NOT NULL UNIQUE
);

CREATE TYPE user_command_type AS ENUM ('payment', 'delegation');

CREATE TYPE transaction_status AS ENUM ('applied', 'failed');

CREATE TABLE user_commands
( id             serial              PRIMARY KEY
, command_type   user_command_type   NOT NULL
, fee_payer_id   int                 NOT NULL REFERENCES public_keys(id)
, source_id      int                 NOT NULL REFERENCES public_keys(id)
, receiver_id    int                 NOT NULL REFERENCES public_keys(id)
, nonce          bigint              NOT NULL
, amount         text
, fee            text                NOT NULL
, valid_until    bigint
, memo           text                NOT NULL
, hash           text                NOT NULL UNIQUE
);

CREATE TYPE internal_command_type AS ENUM ('fee_transfer_via_coinbase', 'fee_transfer', 'coinbase');

CREATE TABLE internal_commands
( id            serial                PRIMARY KEY
, command_type  internal_command_type NOT NULL
, receiver_id   int                   NOT NULL REFERENCES public_keys(id)
, fee           text                  NOT NULL
, hash          text                  NOT NULL
, UNIQUE (hash,command_type)
);

/* block state hashes mentioned in voting_for fields */
CREATE TABLE voting_for
( id          serial PRIMARY KEY
, value text  NOT NULL
);

CREATE INDEX idx_voting_for_value ON voting_for(value);

/* import supporting Zkapp-related tables */
/* Several of the tables below support the following convention, related
   to NULL values.

   In OCaml, some Zkapp-related types use the constructors Check, which takes a value,
   and Ignore, which is nullary. In columns following the convention, a NULL means Ignore, while
   non-NULL means Check.

   Similarly, in OCaml, there are the constructors Set, which takes a value, and
   Keep, which is nullary. NULL means Keep, and non-NULL means Set.

   The tables that follow this convention have a comment "NULL convention".
*/

/* the string representation of an algebraic field */
CREATE TABLE zkapp_field
( id                       serial           PRIMARY KEY
, field                    text             NOT NULL UNIQUE
);

/* Variable-width arrays of algebraic fields, given as
   id's from zkapp_field

   Postgresql does not allow enforcing that the array elements are
   foreign keys

   The elements of the array are NOT NULL (not enforced by Postgresql)

*/
CREATE TABLE zkapp_field_array
( id                       serial  PRIMARY KEY
, element_ids              int[]   NOT NULL UNIQUE
);

CREATE INDEX idx_zkapp_field_array_element_ids ON zkapp_field_array(element_ids);

/* Fixed-width arrays of algebraic fields, given as id's from
   zkapp_field

   Any element of the array may be NULL, per the NULL convention
*/
CREATE TABLE zkapp_states_nullable
( id                       serial           PRIMARY KEY
, element0                 int              REFERENCES zkapp_field(id)
, element1                 int		    REFERENCES zkapp_field(id)
, element2                 int		    REFERENCES zkapp_field(id)
, element3                 int		    REFERENCES zkapp_field(id)
, element4                 int		    REFERENCES zkapp_field(id)
, element5                 int		    REFERENCES zkapp_field(id)
, element6                 int		    REFERENCES zkapp_field(id)
, element7                 int		    REFERENCES zkapp_field(id)
, element8                 int		    REFERENCES zkapp_field(id)
, element9                 int		    REFERENCES zkapp_field(id)
, element10                 int		    REFERENCES zkapp_field(id)
, element11                 int		    REFERENCES zkapp_field(id)
, element12                 int		    REFERENCES zkapp_field(id)
, element13                 int		    REFERENCES zkapp_field(id)
, element14                 int		    REFERENCES zkapp_field(id)
, element15                 int		    REFERENCES zkapp_field(id)
, element16                 int		    REFERENCES zkapp_field(id)
, element17                 int		    REFERENCES zkapp_field(id)
, element18                 int		    REFERENCES zkapp_field(id)
, element19                 int		    REFERENCES zkapp_field(id)
, element20                 int		    REFERENCES zkapp_field(id)
, element21                 int		    REFERENCES zkapp_field(id)
, element22                 int		    REFERENCES zkapp_field(id)
, element23                 int		    REFERENCES zkapp_field(id)
, element24                 int		    REFERENCES zkapp_field(id)
, element25                 int		    REFERENCES zkapp_field(id)
, element26                 int		    REFERENCES zkapp_field(id)
, element27                 int		    REFERENCES zkapp_field(id)
, element28                 int		    REFERENCES zkapp_field(id)
, element29                 int		    REFERENCES zkapp_field(id)
, element30                 int		    REFERENCES zkapp_field(id)
, element31                 int		    REFERENCES zkapp_field(id)
);

/* like zkapp_states_nullable, but elements are not NULL */
CREATE TABLE zkapp_states
( id                       serial           PRIMARY KEY
, element0                 int              NOT NULL REFERENCES zkapp_field(id)
, element1                 int              NOT NULL REFERENCES zkapp_field(id)
, element2                 int              NOT NULL REFERENCES zkapp_field(id)
, element3                 int              NOT NULL REFERENCES zkapp_field(id)
, element4                 int              NOT NULL REFERENCES zkapp_field(id)
, element5                 int              NOT NULL REFERENCES zkapp_field(id)
, element6                 int              NOT NULL REFERENCES zkapp_field(id)
, element7                 int              NOT NULL REFERENCES zkapp_field(id)
, element8                 int              NOT NULL REFERENCES zkapp_field(id)
, element9                 int              NOT NULL REFERENCES zkapp_field(id)
, element10                 int              NOT NULL REFERENCES zkapp_field(id)
, element11                 int              NOT NULL REFERENCES zkapp_field(id)
, element12                 int              NOT NULL REFERENCES zkapp_field(id)
, element13                 int              NOT NULL REFERENCES zkapp_field(id)
, element14                 int              NOT NULL REFERENCES zkapp_field(id)
, element15                 int              NOT NULL REFERENCES zkapp_field(id)
, element16                 int              NOT NULL REFERENCES zkapp_field(id)
, element17                 int              NOT NULL REFERENCES zkapp_field(id)
, element18                 int              NOT NULL REFERENCES zkapp_field(id)
, element19                 int              NOT NULL REFERENCES zkapp_field(id)
, element20                 int              NOT NULL REFERENCES zkapp_field(id)
, element21                 int              NOT NULL REFERENCES zkapp_field(id)
, element22                 int              NOT NULL REFERENCES zkapp_field(id)
, element23                 int              NOT NULL REFERENCES zkapp_field(id)
, element24                 int              NOT NULL REFERENCES zkapp_field(id)
, element25                 int              NOT NULL REFERENCES zkapp_field(id)
, element26                 int              NOT NULL REFERENCES zkapp_field(id)
, element27                 int              NOT NULL REFERENCES zkapp_field(id)
, element28                 int              NOT NULL REFERENCES zkapp_field(id)
, element29                 int              NOT NULL REFERENCES zkapp_field(id)
, element30                 int              NOT NULL REFERENCES zkapp_field(id)
, element31                 int              NOT NULL REFERENCES zkapp_field(id)
);

/* like zkapp_states, but for action states */
CREATE TABLE zkapp_action_states
( id                       serial           PRIMARY KEY
, element0                 int              NOT NULL REFERENCES zkapp_field(id)
, element1                 int              NOT NULL REFERENCES zkapp_field(id)
, element2                 int              NOT NULL REFERENCES zkapp_field(id)
, element3                 int              NOT NULL REFERENCES zkapp_field(id)
, element4                 int              NOT NULL REFERENCES zkapp_field(id)
);

/* the element_ids are non-NULL, and refer to zkapp_field_array
   they represent a list of arrays of field elements
*/
CREATE TABLE zkapp_events
( id                       serial           PRIMARY KEY
, element_ids              int[]            NOT NULL UNIQUE
);

CREATE INDEX idx_zkapp_events_element_ids ON zkapp_events(element_ids);

/* field elements derived from verification keys */
CREATE TABLE zkapp_verification_key_hashes
( id                                    serial          PRIMARY KEY
, value                                 text            NOT NULL UNIQUE
);

CREATE TABLE zkapp_verification_keys
( id                       serial           PRIMARY KEY
, verification_key         text             NOT NULL UNIQUE
, hash_id                  int              NOT NULL UNIQUE REFERENCES zkapp_verification_key_hashes(id)
);

CREATE TYPE zkapp_auth_required_type AS ENUM ('none', 'either', 'proof', 'signature', 'both', 'impossible');

CREATE TABLE zkapp_permissions
( id                       serial                PRIMARY KEY
, edit_state                       zkapp_auth_required_type    NOT NULL
, send                             zkapp_auth_required_type    NOT NULL
, receive                          zkapp_auth_required_type    NOT NULL
, access                           zkapp_auth_required_type    NOT NULL
, set_delegate                     zkapp_auth_required_type    NOT NULL
, set_permissions                  zkapp_auth_required_type    NOT NULL
, set_verification_key_auth        zkapp_auth_required_type    NOT NULL
, set_verification_key_txn_version int                         NOT NULL
, set_zkapp_uri                    zkapp_auth_required_type    NOT NULL
, edit_action_state                zkapp_auth_required_type    NOT NULL
, set_token_symbol                 zkapp_auth_required_type    NOT NULL
, increment_nonce                  zkapp_auth_required_type    NOT NULL
, set_voting_for                   zkapp_auth_required_type    NOT NULL
, set_timing                       zkapp_auth_required_type    NOT NULL
);

CREATE TABLE zkapp_timing_info
( id                       serial  PRIMARY KEY
, initial_minimum_balance  text    NOT NULL
, cliff_time               bigint  NOT NULL
, cliff_amount             text    NOT NULL
, vesting_period           bigint  NOT NULL
, vesting_increment        text    NOT NULL
);

CREATE TABLE zkapp_uris
( id                 serial  PRIMARY KEY
, value              text    NOT NULL UNIQUE
);

/* NULL convention */
CREATE TABLE zkapp_updates
( id                       serial           PRIMARY KEY
, app_state_id             int              NOT NULL REFERENCES zkapp_states_nullable(id)
, delegate_id              int              REFERENCES public_keys(id)
, verification_key_id      int              REFERENCES zkapp_verification_keys(id)
, permissions_id           int              REFERENCES zkapp_permissions(id)
, zkapp_uri_id             int              REFERENCES zkapp_uris(id)
, token_symbol_id          int              REFERENCES token_symbols(id)
, timing_id                int              REFERENCES zkapp_timing_info(id)
, voting_for_id            int              REFERENCES voting_for(id)
);

CREATE TABLE zkapp_balance_bounds
( id                       serial           PRIMARY KEY
, balance_lower_bound      text             NOT NULL
, balance_upper_bound      text             NOT NULL
);

CREATE TABLE zkapp_nonce_bounds
( id                       serial           PRIMARY KEY
, nonce_lower_bound        bigint           NOT NULL
, nonce_upper_bound        bigint           NOT NULL
);

/* NULL convention */
CREATE TABLE zkapp_account_precondition
( id                       serial     PRIMARY KEY
, balance_id               int                     REFERENCES zkapp_balance_bounds(id)
, nonce_id                 int                     REFERENCES zkapp_nonce_bounds(id)
, receipt_chain_hash       text
, delegate_id              int                     REFERENCES public_keys(id)
, state_id                 int        NOT NULL     REFERENCES zkapp_states_nullable(id)
, action_state_id          int                     REFERENCES zkapp_field(id)
, proved_state             boolean
, is_new                   boolean
, UNIQUE(balance_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new, nonce_id)
);

CREATE TABLE zkapp_accounts
( id                   serial  PRIMARY KEY
, app_state_id         int     NOT NULL     REFERENCES zkapp_states(id)
, verification_key_id  int                  REFERENCES zkapp_verification_keys(id)
, zkapp_version        bigint  NOT NULL
, action_state_id      int     NOT NULL     REFERENCES zkapp_action_states(id)
, last_action_slot     bigint  NOT NULL
, proved_state         bool    NOT NULL
, zkapp_uri_id         int     NOT NULL     REFERENCES zkapp_uris(id)
);

CREATE TABLE zkapp_token_id_bounds
( id                       serial           PRIMARY KEY
, token_id_lower_bound     text             NOT NULL
, token_id_upper_bound     text             NOT NULL
);

CREATE TABLE zkapp_length_bounds
( id                       serial          PRIMARY KEY
, length_lower_bound       bigint          NOT NULL
, length_upper_bound       bigint          NOT NULL
);

CREATE TABLE zkapp_amount_bounds
( id                       serial          PRIMARY KEY
, amount_lower_bound       text            NOT NULL
, amount_upper_bound       text            NOT NULL
);

CREATE TABLE zkapp_global_slot_bounds
( id                       serial          PRIMARY KEY
, global_slot_lower_bound  bigint          NOT NULL
, global_slot_upper_bound  bigint          NOT NULL
);

/* NULL convention */
CREATE TABLE zkapp_epoch_ledger
( id                       serial          PRIMARY KEY
, hash_id                  int             REFERENCES snarked_ledger_hashes(id)
, total_currency_id        int             REFERENCES zkapp_amount_bounds(id)
);

/* NULL convention */
CREATE TABLE zkapp_epoch_data
( id                       serial          PRIMARY KEY
, epoch_ledger_id          int             REFERENCES zkapp_epoch_ledger(id)
, epoch_seed               text
, start_checkpoint         text
, lock_checkpoint          text
, epoch_length_id          int             REFERENCES zkapp_length_bounds(id)
);

/* NULL convention */
CREATE TABLE zkapp_network_precondition
( id                               serial                         NOT NULL PRIMARY KEY
, snarked_ledger_hash_id           int                            REFERENCES snarked_ledger_hashes(id)
, blockchain_length_id             int                            REFERENCES zkapp_length_bounds(id)
, min_window_density_id            int                            REFERENCES zkapp_length_bounds(id)
/* omitting 'last_vrf_output' for now, it's the unit value in OCaml */
, total_currency_id                int                            REFERENCES zkapp_amount_bounds(id)
, global_slot_since_genesis        int                            REFERENCES zkapp_global_slot_bounds(id)
, staking_epoch_data_id            int                            REFERENCES zkapp_epoch_data(id)
, next_epoch_data_id               int                            REFERENCES zkapp_epoch_data(id)
);

CREATE TABLE zkapp_fee_payer_body
( id                                    serial    PRIMARY KEY
, public_key_id                         int       NOT NULL REFERENCES public_keys(id)
, fee                                   text      NOT NULL
, valid_until                           bigint
, nonce                                 bigint    NOT NULL
);

CREATE TYPE may_use_token AS ENUM ('No', 'ParentsOwnToken', 'InheritFromParent');

CREATE TYPE authorization_kind_type AS ENUM ('None_given', 'Signature', 'Proof');

/* invariant: verification_key_hash_id is not NULL iff authorization_kind = Proof
   in OCaml, the verification key hash is stored with the Proof authorization kind
   here, they're kept separate so we can use an enum type
*/
CREATE TABLE zkapp_account_update_body
( id                                    serial          PRIMARY KEY
, account_identifier_id                 int             NOT NULL  REFERENCES account_identifiers(id)
, update_id                             int             NOT NULL  REFERENCES zkapp_updates(id)
, balance_change                        text            NOT NULL
, increment_nonce                       boolean         NOT NULL
, events_id                             int             NOT NULL  REFERENCES zkapp_events(id)
, actions_id                            int             NOT NULL  REFERENCES zkapp_events(id)
, call_data_id                          int             NOT NULL  REFERENCES zkapp_field(id)
, call_depth                            int             NOT NULL
, zkapp_network_precondition_id         int             NOT NULL  REFERENCES zkapp_network_precondition(id)
, zkapp_account_precondition_id         int             NOT NULL  REFERENCES zkapp_account_precondition(id)
, zkapp_valid_while_precondition_id     int                       REFERENCES zkapp_global_slot_bounds(id)
, use_full_commitment                   boolean         NOT NULL
, implicit_account_creation_fee         boolean         NOT NULL
, may_use_token                         may_use_token  NOT NULL
, authorization_kind                    authorization_kind_type NOT NULL
, verification_key_hash_id              int                       REFERENCES zkapp_verification_key_hashes(id)
);

/* possible future enhancement: add NULLable authorization column for proofs and signatures */
CREATE TABLE zkapp_account_update
( id                       serial                          PRIMARY KEY
, body_id                  int                             NOT NULL REFERENCES zkapp_account_update_body(id)
);

/* a list of of failures for an account update in a zkApp
   the index is the index into the `account_updates`
*/
CREATE TABLE zkapp_account_update_failures
( id       serial    PRIMARY KEY
, index    int       NOT NULL
, failures text[]    NOT NULL
);


/* in OCaml, there's a Fee_payer type, which contains a
   a signature and a reference to the fee payer body. Because
   we don't store a signature, the fee payer here refers
   directly to the fee payer body.

   zkapp_account_updates_ids refers to a list of ids in zkapp_account_update.
   The values in zkapp_account_updates_ids are unenforced foreign keys
   that reference zkapp_account_update_body(id), and not NULL.
*/
CREATE TABLE zkapp_commands
( id                                    serial         PRIMARY KEY
, zkapp_fee_payer_body_id               int            NOT NULL REFERENCES zkapp_fee_payer_body(id)
, zkapp_account_updates_ids             int[]          NOT NULL
, memo                                  text           NOT NULL
, hash                                  text           NOT NULL UNIQUE
);

CREATE TABLE epoch_data
( id               serial PRIMARY KEY
, seed             text   NOT NULL
, ledger_hash_id   int    NOT NULL REFERENCES snarked_ledger_hashes(id)
, total_currency   text   NOT NULL
, start_checkpoint text   NOT NULL
, lock_checkpoint  text   NOT NULL
, epoch_length     bigint NOT NULL
, UNIQUE (seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length)
);

CREATE TABLE protocol_versions
( id               serial PRIMARY KEY
, transaction      int    NOT NULL
, network          int    NOT NULL
, patch            int    NOT NULL
, UNIQUE (transaction,network,patch)
);

CREATE TYPE chain_status_type AS ENUM ('canonical', 'orphaned', 'pending');

/* last_vrf_output is a sequence of hex-digit pairs derived from a bitstring */
CREATE TABLE blocks
( id                           serial   PRIMARY KEY
, state_hash                   text     NOT NULL UNIQUE
, parent_id                    int                      REFERENCES blocks(id)
, parent_hash                  text     NOT NULL
, creator_id                   int      NOT NULL        REFERENCES public_keys(id)
, block_winner_id              int      NOT NULL        REFERENCES public_keys(id)
, last_vrf_output              text     NOT NULL
, snarked_ledger_hash_id       int      NOT NULL        REFERENCES snarked_ledger_hashes(id)
, staking_epoch_data_id        int      NOT NULL        REFERENCES epoch_data(id)
, next_epoch_data_id           int      NOT NULL        REFERENCES epoch_data(id)
, min_window_density           bigint   NOT NULL
, sub_window_densities         bigint[] NOT NULL
, total_currency               text     NOT NULL
, ledger_hash                  text     NOT NULL
, height                       bigint   NOT NULL
, global_slot_since_hard_fork  bigint   NOT NULL
, global_slot_since_genesis    bigint   NOT NULL
, protocol_version_id          int      NOT NULL        REFERENCES protocol_versions(id)
, proposed_protocol_version_id int                      REFERENCES protocol_versions(id)
, timestamp                    text     NOT NULL
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
, balance                 text    NOT NULL
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
, creation_fee            text    NOT NULL
, PRIMARY KEY (block_id,account_identifier_id)
);

CREATE INDEX idx_accounts_created_block_id ON accounts_created(block_id);
CREATE INDEX idx_accounts_created_block_account_identifier_id ON accounts_created(account_identifier_id);

CREATE TABLE blocks_user_commands
( block_id        int NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, user_command_id int NOT NULL REFERENCES user_commands(id) ON DELETE CASCADE
, sequence_no     int NOT NULL
, status          transaction_status NOT NULL
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
, status                transaction_status NOT NULL
, failure_reason        text
, PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no)
);

CREATE INDEX idx_blocks_internal_commands_block_id ON blocks_internal_commands(block_id);
CREATE INDEX idx_blocks_internal_commands_internal_command_id ON blocks_internal_commands(internal_command_id);
CREATE INDEX idx_blocks_internal_commands_sequence_no ON blocks_internal_commands(sequence_no);
CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON blocks_internal_commands(secondary_sequence_no);

/* a join table between blocks and zkapp_commands
   sequence_no gives the order within all transactions in the block

   The `failure_reasons` column is not NULL iff `status` is `failed`. The
   entries in the array are unenforced foreign key references to `zkapp_account_update_failures(id)`.
   Each element of the array refers to the failures for an account update in `account_updates`, and
   is not NULL.

   Blocks command convention
*/

CREATE TABLE blocks_zkapp_commands
( block_id                        int                 NOT NULL REFERENCES blocks(id) ON DELETE CASCADE
, zkapp_command_id                int                 NOT NULL REFERENCES zkapp_commands(id) ON DELETE CASCADE
, sequence_no                     int                 NOT NULL
, status                          transaction_status  NOT NULL
, failure_reasons_ids             int[]
, PRIMARY KEY (block_id, zkapp_command_id, sequence_no)
);

CREATE INDEX idx_blocks_zkapp_commands_block_id ON blocks_zkapp_commands(block_id);
CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON blocks_zkapp_commands(zkapp_command_id);
CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON blocks_zkapp_commands(sequence_no);
