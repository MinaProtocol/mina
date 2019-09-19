CREATE TYPE user_command_type AS ENUM (
  'payment',
  'delegation'
);

CREATE TABLE public_keys (
  id serial PRIMARY KEY,
  value text NOT NULL
);

CREATE TABLE blocks (
  id serial PRIMARY KEY,
  state_hash text,
  creator int NOT NULL,
  staged_ledger_hash text NOT NULL,
  ledger_hash text NOT NULL,
  epoch int NOT NULL,
  slot int NOT NULL,
  ledger_proof_nonce int NOT NULL,
  status int NOT NULL,
  block_length int NOT NULL,
  block_time bit(64) NOT NULL,
  FOREIGN KEY (creator) REFERENCES public_keys (id)
);

CREATE UNIQUE INDEX state_hash ON blocks (state_hash);

CREATE INDEX block_compare ON blocks (block_length, epoch, slot);

CREATE INDEX block_time ON blocks (block_time);

CREATE TABLE receipt_chain_hashes (
  id serial PRIMARY KEY,
  parent_id int,
  hash text NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES receipt_chain_hashes (id)
);

CREATE UNIQUE INDEX receipt_chain_hash_id ON receipt_chain_hashes (hash);

CREATE TABLE user_commands (
  id serial PRIMARY KEY,
  hash text NOT NULL,
  typ user_command_type NOT NULL,
  nonce bit(32) NOT NULL,
  sender int NOT NULL,
  receiver int NOT NULL,
  amount bit(64) NOT NULL,
  fee bit(64) NOT NULL,
  memo text NOT NULL,
  first_seen bit(64),
  FOREIGN KEY (sender) REFERENCES public_keys (id),
  FOREIGN KEY (receiver) REFERENCES public_keys (id)
);

CREATE UNIQUE INDEX user_command_hash ON user_commands (hash);

CREATE INDEX fast_user_command_sender_pagination ON user_commands (sender, first_seen);

CREATE INDEX fast_user_command_receiver_pagination ON user_commands (receiver, first_seen);

CREATE TABLE fee_transfers (
  id serial PRIMARY KEY,
  hash text,
  fee bit(64) NOT NULL,
  receiver int NOT NULL,
  first_seen bit(64),
  FOREIGN KEY (receiver) REFERENCES public_keys (id)
);

CREATE UNIQUE INDEX fee_transfer_hash ON fee_transfers (hash);

CREATE INDEX fee_transfer_receiver ON fee_transfers (receiver, first_seen);

CREATE TABLE blocks_user_commands (
  block_id int NOT NULL,
  user_command_id int NOT NULL,
  receipt_chain_hash_id int,
  FOREIGN KEY (block_id) REFERENCES blocks (id),
  FOREIGN KEY (user_command_id) REFERENCES user_commands (id),
  FOREIGN KEY (receipt_chain_hash_id) REFERENCES receipt_chain_hashes(id)
);

CREATE INDEX blocks_user_command__block_id ON blocks_user_commands (block_id);

CREATE INDEX blocks_user_command__user_command_id ON blocks_user_commands (user_command_id);

CREATE TABLE blocks_fee_transfers (
  block_id int NOT NULL,
  fee_transfer_id int NOT NULL,
  FOREIGN KEY (block_id) REFERENCES blocks (id),
  FOREIGN KEY (fee_transfer_id) REFERENCES fee_transfers (id)
);

CREATE INDEX blocks_fee_transfers__block_id ON blocks_fee_transfers (block_id);

CREATE INDEX blocks_fee_transfers__fee_transfer_id ON blocks_fee_transfers (fee_transfer_id);

CREATE TABLE snark_jobs (
  id serial PRIMARY KEY,
  prover int NOT NULL,
  fee int NOT NULL,
  job1 int,
  job2 int
);

CREATE UNIQUE INDEX snark_job ON snark_jobs (job1, job2);

CREATE TABLE blocks_snark_jobs (
  block_id int NOT NULL,
  snark_job_id int NOT NULL,
  FOREIGN KEY (block_id) REFERENCES blocks (id),
  FOREIGN KEY (snark_job_id) REFERENCES snark_jobs (id)
);
