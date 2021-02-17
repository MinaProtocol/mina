(* sql.ml -- (Postgresql) SQL queries for missing subchain app *)

module Subchain = struct
  let query =
    Caqti_request.collect Caqti_type.string Archive_lib.Processor.Block.typ
      {sql| WITH RECURSIVE chain AS (

              SELECT id,state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                     next_epoch_data_id,ledger_hash,height,global_slot,global_slot_since_genesis,timestamp
              FROM blocks b WHERE b.state_hash = ?

              UNION ALL

              SELECT b.id,b.state_hash,b.parent_id,b.parent_hash,b.creator_id,b.block_winner_id,b.snarked_ledger_hash_id,b.staking_epoch_data_id,
                     b.next_epoch_data_id,b.ledger_hash,b.height,b.global_slot,b.global_slot_since_genesis,b.timestamp
              FROM blocks b

              INNER JOIN chain

              ON b.id = chain.parent_id
           )

           SELECT state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                  next_epoch_data_id,ledger_hash,height,global_slot,global_slot_since_genesis,timestamp
           FROM chain
      |sql}

  (* state_hash from end block of the subchain *)
  let run (module Conn : Caqti_async.CONNECTION) state_hash =
    Conn.collect_list query state_hash
end

(* Archive_lib.Processor does not have the queries given here *)

module Public_key = struct
  let query =
    Caqti_request.find Caqti_type.int Caqti_type.string
      "SELECT value from public_keys WHERE id = ?"

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.find query id
end

module Snarked_ledger_hashes = struct
  let query =
    Caqti_request.find Caqti_type.int Caqti_type.string
      "SELECT value from snarked_ledger_hashes WHERE id = ?"

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.find query id
end

module Epoch_data = struct
  let query =
    Caqti_request.find Caqti_type.int
      Caqti_type.(tup2 string int)
      "SELECT seed,ledger_hash_id from epoch_data WHERE id = ?"

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.find query id
end

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
    { internal_command_id: int
    ; global_slot: int64
    ; sequence_no: int
    ; secondary_sequence_no: int
    ; receiver_balance: int64 }
  [@@deriving hlist]

  let typ =
    let open Archive_lib.Processor.Caqti_type_spec in
    let spec = Caqti_type.[int; int64; int; int; int64] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let query =
    Caqti_request.collect Caqti_type.int typ
      {sql| SELECT internal_command_id, global_slot, sequence_no, secondary_sequence_no, receiver_balance
            FROM (blocks_internal_commands
              INNER JOIN blocks
              ON blocks.id = blocks_internal_commands.block_id)
            WHERE block_id = ?
      |sql}

  let run (module Conn : Caqti_async.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end
