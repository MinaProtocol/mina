create type chain_status_type AS ENUM (
	'canonical',
	'orphaned',
	'pending');
  
alter table blocks 
  add column chain_status chain_status_type NOT NULL DEFAULT 'pending'::chain_status_type;

create index idx_blocks_chain_status
    on blocks (chain_status);  

create function set_block_state() returns trigger
    language plpgsql
as
$$
declare
    chain_row RECORD;
begin
    for chain_row in
        WITH RECURSIVE chain AS (
            SELECT id, state_hash, parent_id, height
            FROM blocks
            WHERE state_hash =
                  (
                      select state_hash
                      from blocks
                      where height = (select max(height) from blocks)
                      limit 1
                  )

            UNION ALL

            SELECT b.id, b.state_hash, b.parent_id, b.height
            FROM blocks b
                     INNER JOIN chain
                                ON b.id = chain.parent_id AND chain.height <> (select max(height) from blocks where chain_status = 'canonical')
        )

        SELECT state_hash, height
        FROM chain
        where height < (select max(height) from blocks)
        ORDER BY height
    loop
        update blocks set chain_status = 'canonical' where state_hash = chain_row.state_hash;
        update blocks set chain_status = 'orphaned' where height = chain_row.height and state_hash != chain_row.state_hash;
    end loop;

	return new;
end;
$$;

alter function set_block_state() owner to mina;

create trigger tr_ai_set_block_state
    after insert
    on blocks
    for each row
execute procedure set_block_state();

