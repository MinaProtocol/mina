--Updates to the archive db schema post deployment (after main-net)
--For now adding this to keep track of the commands to run during the 4.1 planned hardfork
--add the new column without the not null constraint first
alter table blocks add column global_slot_since_genesis bigint;

--update the values of the new column
update blocks as b1 set global_slot_since_genesis = (select global_slot from blocks b2 where b1.id = b2.id);

--add the not null constraint
alter table blocks alter column global_slot_since_genesis set not null;

--check if global_slot_since_genesis = global_slot; this should return 0 rows
select * from blocks as b1 inner join blocks as b2 on b1.id = b2.id where b1.global_slot_since_genesis <> b2.global_slot


