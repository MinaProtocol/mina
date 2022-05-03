(* sql.ml -- (Postgresql) SQL queries for extract_blocks app *)

module Subchain = struct
  let make_sql ~join_condition =
    Core_kernel.sprintf
      {sql| WITH RECURSIVE chain AS (

              SELECT id,state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                     next_epoch_data_id,ledger_hash,height,global_slot_since_hard_fork,global_slot_since_genesis,timestamp,chain_status
              FROM blocks b WHERE b.state_hash = $1

              UNION ALL

              SELECT b.id,b.state_hash,b.parent_id,b.parent_hash,b.creator_id,b.block_winner_id,b.snarked_ledger_hash_id,b.staking_epoch_data_id,
                     b.next_epoch_data_id,b.ledger_hash,b.height,b.global_slot_since_hard_fork,b.global_slot_since_genesis,b.timestamp,b.chain_status
              FROM blocks b

              INNER JOIN chain

              ON %s
           )

           SELECT state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                  next_epoch_data_id,ledger_hash,height,global_slot_since_hard_fork,global_slot_since_genesis,timestamp,chain_status
           FROM chain
      |sql}
      join_condition

  let query_unparented =
    Caqti_request.collect Caqti_type.string Archive_lib.Processor.Block.typ
      (make_sql ~join_condition:"b.id = chain.parent_id")

  let query_from_start =
    Caqti_request.collect
      Caqti_type.(tup2 string string)
      Archive_lib.Processor.Block.typ
      (make_sql
         ~join_condition:
           "b.id = chain.parent_id AND (chain.state_hash <> $2 OR b.state_hash \
            = $2)")

  let start_from_unparented (module Conn : Caqti_async.CONNECTION)
      ~end_state_hash =
    Conn.collect_list query_unparented end_state_hash

  let start_from_specified (module Conn : Caqti_async.CONNECTION)
      ~start_state_hash ~end_state_hash =
    Conn.collect_list query_from_start (end_state_hash, start_state_hash)

  let query_all =
    let open Core_kernel in
    let comma_fields =
      String.concat Archive_lib.Processor.Block.Fields.names ~sep:","
    in
    Caqti_request.collect Caqti_type.unit Archive_lib.Processor.Block.typ
      (sprintf "SELECT %s FROM blocks" comma_fields)

  let all_blocks (module Conn : Caqti_async.CONNECTION) =
    Conn.collect_list query_all ()
end

(* Archive_lib.Processor does not have the queries given here *)

module Blocks_and_user_commands = struct
  let query =
    Caqti_request.collect Caqti_type.int
      Caqti_type.(tup2 int int)
      {sql| SELECT user_command_id, sequence_no
            FROM blocks_user_commands
            WHERE block_id = ?
      |sql}

  let run (module Conn : Caqti_async.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Blocks_and_internal_commands = struct
  type t =
    { internal_command_id : int
    ; sequence_no : int
    ; secondary_sequence_no : int
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int ]

  let query =
    Caqti_request.collect Caqti_type.int typ
      {sql| SELECT internal_command_id, sequence_no, secondary_sequence_no
            FROM (blocks_internal_commands
            INNER JOIN blocks
            ON blocks.id = blocks_internal_commands.block_id)
            WHERE block_id = ?
      |sql}

  let run (module Conn : Caqti_async.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Blocks_and_zkapp_commands = struct
  let query =
    Caqti_request.collect Caqti_type.int
      Caqti_type.(tup2 int int)
      {sql| SELECT zkapp_command_id, sequence_no
            FROM blocks_zkapp_commands
            WHERE block_id = ?
      |sql}

  let run (module Conn : Caqti_async.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end
