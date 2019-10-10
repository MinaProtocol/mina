CREATE TYPE user_command_type AS ENUM (
  'payment',
  'delegation'
);

CREATE TABLE public_keys (
  id serial PRIMARY KEY,
  value text NOT NULL
);

alter table public_keys add constraint public_keys_value_key unique (value);

CREATE INDEX public_keys_value_index ON public_keys (value);

CREATE TABLE state_hashes (
  id serial PRIMARY KEY,
  value text NOT NULL
);

CREATE INDEX state_hashes_value_index ON state_hashes (value);

alter table state_hashes add constraint state_hashes_value_key unique (value);

CREATE TABLE blocks (
  state_hash int NOT NULL,
  parent_hash int NOT NULL,
  creator int NOT NULL,
  ledger_hash text NOT NULL,
  global_slot int NOT NULL,
  ledger_proof_nonce int NOT NULL,
  status int NOT NULL,
  block_length bit(32) NOT NULL,
  block_time bit(64) NOT NULL,
  FOREIGN KEY (creator) REFERENCES public_keys (id),
  FOREIGN KEY (state_hash) REFERENCES state_hashes (id),
  FOREIGN KEY (parent_hash) REFERENCES state_hashes (id)
);

alter table blocks add constraint blocks_state_hash_key unique (state_hash);

CREATE INDEX blocks_state_hash_index ON blocks (state_hash);

CREATE INDEX block_compare ON blocks (block_length, global_slot);

CREATE INDEX block_time ON blocks (block_time);

CREATE TABLE receipt_chain_hashes (
  id serial PRIMARY KEY,
  parent_id int,
  hash text NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES receipt_chain_hashes (id)
);

alter table receipt_chain_hashes add constraint receipt_chain_hashes_hash_key unique (hash);

CREATE UNIQUE INDEX receipt_chain_hashes_hash_index ON receipt_chain_hashes (hash);

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

alter table user_commands add constraint user_commands_hash_key unique (hash);

CREATE INDEX user_commands_hash_index ON user_commands (hash);

CREATE INDEX fast_user_command_sender_pagination ON user_commands (sender, first_seen);

CREATE INDEX fast_user_command_receiver_pagination ON user_commands (receiver, first_seen);

CREATE TABLE fee_transfers (
  id serial PRIMARY KEY,
  hash text NOT NULL,
  fee bit(64) NOT NULL,
  receiver int NOT NULL,
  first_seen bit(64),
  FOREIGN KEY (receiver) REFERENCES public_keys (id)
);

alter table fee_transfers add constraint fee_transfers_hash_key unique (hash);

CREATE INDEX fee_transfer_hash_index ON fee_transfers (hash);

CREATE INDEX fee_transfer_receiver_index ON fee_transfers (receiver, first_seen);

CREATE TABLE blocks_user_commands (
  block_id int NOT NULL,
  user_command_id int NOT NULL,
  receipt_chain_hash_id int,
  FOREIGN KEY (block_id) REFERENCES blocks (state_hash),
  FOREIGN KEY (user_command_id) REFERENCES user_commands (id),
  FOREIGN KEY (receipt_chain_hash_id) REFERENCES receipt_chain_hashes(id)
);

alter table blocks_user_commands add constraint blocks_user_commands_block_id_user_command_id_receipt_chain_hash_id_key unique (block_id, user_command_id, receipt_chain_hash_id);

CREATE INDEX blocks_user_command__block_id ON blocks_user_commands (block_id);

CREATE INDEX blocks_user_command__user_command_id ON blocks_user_commands (user_command_id);

CREATE TABLE blocks_fee_transfers (
  block_id int NOT NULL,
  fee_transfer_id int NOT NULL,
  FOREIGN KEY (block_id) REFERENCES blocks (state_hash),
  FOREIGN KEY (fee_transfer_id) REFERENCES fee_transfers (id)
);

alter table blocks_fee_transfers add constraint blocks_fee_transfers_block_id_fee_transfer_id_key unique (block_id, fee_transfer_id);

CREATE INDEX blocks_fee_transfers__block_id ON blocks_fee_transfers (block_id);

CREATE INDEX blocks_fee_transfers__fee_transfer_id ON blocks_fee_transfers (fee_transfer_id);

CREATE TABLE snark_jobs (
  id serial PRIMARY KEY,
  prover int NOT NULL,
  fee bit(64) NOT NULL,
  job1 int,
  job2 int,
  FOREIGN KEY (prover) REFERENCES public_keys (id)
);

CREATE INDEX snark_job_index ON snark_jobs (job1, job2);

alter table snark_jobs add constraint snark_jobs_job1_job2_key unique (job1, job2);

CREATE TABLE blocks_snark_jobs (
  block_id int NOT NULL,
  snark_job_id int NOT NULL,
  FOREIGN KEY (block_id) REFERENCES blocks (state_hash),
  FOREIGN KEY (snark_job_id) REFERENCES snark_jobs (id)
);

alter table blocks_snark_jobs add constraint blocks_snark_jobs_block_id_snark_job_id_key unique (block_id, snark_job_id);