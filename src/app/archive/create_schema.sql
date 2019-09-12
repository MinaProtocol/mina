CREATE TABLE blocks (
  state_hash text PRIMARY KEY,
  creator text NOT NULL,
  staged_ledger_hash text NOT NULL,
  ledger_hash text NOT NULL,
  epoch int NOT NULL,
  slot int NOT NULL,
  ledger_proof_nonce int NOT NULL,
  status int NOT NULL,
  block_length int NOT NULL,
  block_time timestamp NOT NULL
);

CREATE INDEX block_compare ON blocks (block_length, epoch, slot);


CREATE INDEX block_time ON blocks (block_time);

CREATE TABLE user_commands (
  id text PRIMARY KEY,
  is_delegation bool NOT NULL,
  nonce bigint NOT NULL,
  sender text NOT NULL,
  receiver text NOT NULL,
  amount bigint NOT NULL,
  fee bigint NOT NULL,
  memo text NOT NULL,
  first_seen timestamp,
  transaction_pool_membership bool NOT NULL,
  is_added_manually bool NOT NULL
);

CREATE INDEX fast_pooled_user_command_sender ON user_commands (transaction_pool_membership, sender);

CREATE INDEX fast_pooled_user_command_receiver ON user_commands (transaction_pool_membership, receiver);

CREATE INDEX fast_sender_pagination ON user_commands (sender, first_seen);

CREATE INDEX fast_receiver_pagination ON user_commands (receiver, first_seen);

CREATE TABLE fee_transfers (
  id text PRIMARY KEY,
  fee bigint NOT NULL,
  receiver text NOT NULL,
  first_seen timestamp
);

CREATE TABLE blocks_user_commands (
  state_hash text NOT NULL,
  user_command_id text NOT NULL,
  sender text,
  receiver text NOT NULL,
  FOREIGN KEY (state_hash) REFERENCES blocks (state_hash)
);

CREATE INDEX blocks_user_command__state_hash ON blocks_user_commands (state_hash);

CREATE INDEX blocks_user_command__user_command_id ON blocks_user_commands (user_command_id);

CREATE INDEX blocks_user_command__receiver ON blocks_user_commands (receiver);

CREATE INDEX blocks_user_command__sender ON blocks_user_commands (sender);

CREATE TABLE blocks_fee_transfers (
  state_hash text NOT NULL,
  fee_transfer_id text NOT NULL,
  receiver text NOT NULL,
  FOREIGN KEY (state_hash) REFERENCES blocks (state_hash)
);

CREATE INDEX blocks_fee_transfers__state_hash ON blocks_fee_transfers (state_hash);

CREATE INDEX blocks_fee_transfers__fee_transfer_id ON blocks_fee_transfers (fee_transfer_id);

CREATE INDEX blocks_fee_transfers__receiver ON blocks_fee_transfers (receiver);

CREATE TABLE snark_jobs (
  prover int,
  fee int,
  work_id bigint,
  has_one_job bool,
  has_two_jobs bool
);

CREATE UNIQUE INDEX id ON snark_jobs (work_id, has_one_job, has_two_jobs);

CREATE TABLE blocks_snark_jobs (
  state_hash text NOT NULL,
  work_id bigint NOT NULL,
  has_one_job bool NOT NULL,
  has_two_jobs bool NOT NULL,
  FOREIGN KEY (work_id, has_one_job, has_two_jobs) REFERENCES snark_jobs (work_id, has_one_job, has_two_jobs),
  FOREIGN KEY (state_hash) REFERENCES blocks (state_hash)
);

CREATE INDEX ON blocks_snark_jobs (work_id, has_one_job, has_two_jobs);

CREATE TABLE receipt_chain_hashes (
  hash text PRIMARY KEY,
  previous_hash text,
  user_command_id text NOT NULL,
  FOREIGN KEY (user_command_id) REFERENCES user_commands (id)
);

CREATE INDEX ON receipt_chain_hashes (user_command_id);
