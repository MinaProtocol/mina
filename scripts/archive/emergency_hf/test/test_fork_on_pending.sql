--A (canonical)
-- |--B (pending)
-- `--C (pending [fork])
--     `--D (pending)



--A (canonical)
-- |--B (orphaned)
-- `--C (canonical [fork])
--     `--D (orphaned)


CREATE TABLE
  blocks (
    id serial NOT NULL,
    state_hash text NOT NULL,
    parent_id integer NULL,
    parent_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot_since_hard_fork bigint NOT NULL,
    global_slot_since_genesis bigint NOT NULL,
    protocol_version_id integer NOT NULL,
    chain_status text NOT NULL
  );

ALTER TABLE
  blocks
ADD
  CONSTRAINT blocks_pkey PRIMARY KEY (id);


insert into blocks ("id", "state_hash", "parent_id", "parent_hash", "global_slot_since_genesis", "global_slot_since_hard_fork", "height", "protocol_version_id","chain_status") 
values 
(1, 'A', null, '0', 0, 0, 1, 2, 'canonical'),
(2, 'B', 1   , 'A', 1, 1, 2, 2, 'orphaned'),
(3, 'C', 1   , 'A', 2, 2, 3, 2, 'pending'),
(4, 'D', 3   , 'C', 3, 3, 4, 2, 'pending');


