(* sql.ml -- (Postgresql) SQL queries for replayer *)

open Core_kernel

module Block_info = struct
  (* find all blocks, working back from block with given state hash *)
  let query =
    Caqti_request.collect Caqti_type.string
      Caqti_type.(tup3 int int64 string)
      {|
         WITH RECURSIVE chain AS (

           SELECT id,parent_id,global_slot,ledger_hash FROM blocks b WHERE b.state_hash = ?

           UNION ALL

           SELECT b.id,b.parent_id,b.global_slot,b.ledger_hash FROM blocks b

           INNER JOIN chain

           ON b.id = chain.parent_id AND chain.id <> chain.parent_id
        )

        SELECT id,global_slot,ledger_hash FROM chain c
   |}

  let run (module Conn : Caqti_async.CONNECTION) state_hash =
    Conn.collect_list query state_hash
end

(* build query to find all blocks back to genesis block, starting with the block containing the
   specified state hash; for each such block, find ids of all (user or internal) commands in that block
*)

let find_command_ids_query s =
  sprintf
    {|
      WITH RECURSIVE chain AS (

        SELECT id,parent_id FROM blocks b WHERE b.state_hash = ?

        UNION ALL

        SELECT b.id,b.parent_id FROM blocks b

        INNER JOIN chain

        ON b.id = chain.parent_id AND chain.id <> chain.parent_id
      )

      SELECT DISTINCT %s_command_id FROM chain c

      INNER JOIN

      blocks_%s_commands bc

      ON bc.block_id = c.id

     |}
    s s

module User_command_ids = struct
  let query =
    Caqti_request.collect Caqti_type.string Caqti_type.int
      (find_command_ids_query "user")

  let run (module Conn : Caqti_async.CONNECTION) state_hash =
    Conn.collect_list query state_hash
end

module User_command = struct
  type t =
    { type_: string
    ; fee_payer_id: int
    ; source_id: int
    ; receiver_id: int
    ; fee: int64
    ; fee_token: int64
    ; token: int64
    ; amount: int64 option
    ; valid_until: int64 option
    ; memo: string
    ; nonce: int64
    ; block_id: int
    ; global_slot: int64
    ; txn_global_slot: int64
    ; sequence_no: int }

  let typ =
    (* chunk into groups so we can use tuple combinators *)
    let encode t =
      Ok
        ( (t.type_, t.fee_payer_id, t.source_id, t.receiver_id)
        , (t.fee, t.fee_token, t.token, t.amount)
        , (t.valid_until, t.memo, t.nonce)
        , (t.block_id, t.global_slot, t.txn_global_slot, t.sequence_no) )
    in
    let decode
        ( (type_, fee_payer_id, source_id, receiver_id)
        , (fee, fee_token, token, amount)
        , (valid_until, memo, nonce)
        , (block_id, global_slot, txn_global_slot, sequence_no) ) =
      Ok
        { type_
        ; fee_payer_id
        ; source_id
        ; receiver_id
        ; fee
        ; fee_token
        ; token
        ; amount
        ; valid_until
        ; memo
        ; nonce
        ; block_id
        ; global_slot
        ; txn_global_slot
        ; sequence_no }
    in
    let rep =
      Caqti_type.(
        tup4 (tup4 string int int int)
          (tup4 int64 int64 int64 (option int64))
          (tup3 (option int64) string int64)
          (tup4 int int64 int64 int))
    in
    Caqti_type.custom ~encode ~decode rep

  let query =
    Caqti_request.collect Caqti_type.int typ
      {|
         SELECT type,fee_payer_id, source_id,receiver_id,fee,fee_token,token,amount,valid_until,memo,nonce,blocks.id,blocks.global_slot,parent.global_slot_since_genesis,sequence_no,status

         FROM (SELECT * FROM user_commands WHERE id = ?) AS uc

         INNER JOIN

         blocks_user_commands AS buc

         ON

         uc.id = buc.user_command_id

         INNER JOIN blocks

         ON

         blocks.id = buc.block_id

         INNER JOIN blocks as parent

         ON

         parent.id = blocks.parent_id

       |}

  let run (module Conn : Caqti_async.CONNECTION) user_cmd_id =
    Conn.collect_list query user_cmd_id
end

module Internal_command_ids = struct
  let query =
    Caqti_request.collect Caqti_type.string Caqti_type.int
      (find_command_ids_query "internal")

  let run (module Conn : Caqti_async.CONNECTION) state_hash =
    Conn.collect_list query state_hash
end

module Internal_command = struct
  type t =
    { type_: string
    ; receiver_id: int
    ; fee: int64
    ; token: int64
    ; block_id: int
    ; global_slot: int64
    ; txn_global_slot: int64
    ; sequence_no: int
    ; secondary_sequence_no: int }

  let typ =
    (* chunk into groups so we can use tuple combinators *)
    let encode t =
      Ok
        ( (t.type_, t.receiver_id)
        , (t.fee, t.token)
        , (t.block_id, t.global_slot)
        , (t.txn_global_slot, t.sequence_no, t.secondary_sequence_no) )
    in
    let decode
        ( (type_, receiver_id)
        , (fee, token)
        , (block_id, global_slot)
        , (txn_global_slot, sequence_no, secondary_sequence_no) ) =
      Ok
        { type_
        ; receiver_id
        ; fee
        ; token
        ; block_id
        ; global_slot
        ; txn_global_slot
        ; sequence_no
        ; secondary_sequence_no }
    in
    let rep =
      Caqti_type.(
        tup4 (tup2 string int) (tup2 int64 int64) (tup2 int int64)
          (tup3 int64 int int))
    in
    Caqti_type.custom ~encode ~decode rep

  (* the transaction global slot is taken from the user command's parent block, mirroring
     the call to Staged_ledger.apply in Block_producer
  *)
  let query =
    Caqti_request.collect Caqti_type.int typ
      {|
         SELECT type,receiver_id,fee,token,blocks.id,blocks.global_slot,parent.global_slot,sequence_no,secondary_sequence_no FROM

         (SELECT * FROM internal_commands WHERE id = ?) AS ic

         INNER JOIN

         blocks_internal_commands AS bic

         ON

         ic.id = bic.internal_command_id

         INNER JOIN

         blocks

         ON blocks.id = bic.block_id

         INNER JOIN blocks as parent

         ON

         parent.id = blocks.parent_id

       |}

  let run (module Conn : Caqti_async.CONNECTION) internal_cmd_id =
    Conn.collect_list query internal_cmd_id
end

module Public_key = struct
  let query =
    Caqti_request.find_opt Caqti_type.int Caqti_type.string
      {|
         SELECT value FROM public_keys WHERE id = ?
       |}

  let run (module Conn : Caqti_async.CONNECTION) pk_id =
    Conn.find_opt query pk_id
end

module Epoch_data = struct
  type epoch_data = {epoch_ledger_hash: string; epoch_data_seed: string}

  let epoch_data_typ =
    let encode t = Ok (t.epoch_ledger_hash, t.epoch_data_seed) in
    let decode (epoch_ledger_hash, epoch_data_seed) =
      Ok {epoch_ledger_hash; epoch_data_seed}
    in
    let rep = Caqti_type.(tup2 string string) in
    Caqti_type.custom ~encode ~decode rep

  let query_epoch_data =
    Caqti_request.find Caqti_type.int epoch_data_typ
      {| SELECT slh.value, ed.seed FROM snarked_ledger_hashes AS slh

       INNER JOIN

       epoch_data AS ed

       ON slh.id = ed.ledger_hash_id

       WHERE ed.id = ?
    |}

  let get_epoch_data (module Conn : Caqti_async.CONNECTION) epoch_ledger_id =
    Conn.find query_epoch_data epoch_ledger_id

  let query_staking_epoch_data_id =
    Caqti_request.find Caqti_type.string Caqti_type.int
      {| SELECT staking_epoch_data_id FROM blocks

         WHERE state_hash = ?
    |}

  let get_staking_epoch_data_id (module Conn : Caqti_async.CONNECTION)
      state_hash =
    Conn.find query_staking_epoch_data_id state_hash

  let query_next_epoch_data_id =
    Caqti_request.find Caqti_type.string Caqti_type.int
      {| SELECT next_epoch_data_id FROM blocks

         WHERE state_hash = ?
    |}

  let get_next_epoch_data_id (module Conn : Caqti_async.CONNECTION) state_hash
      =
    Conn.find query_next_epoch_data_id state_hash
end

module Fork_block = struct
  (* fork block is parent of block with the given state hash *)
  let query_state_hash =
    Caqti_request.find Caqti_type.string Caqti_type.string
      {| SELECT parent.state_hash FROM blocks AS parent

         INNER JOIN

         (SELECT parent_id FROM blocks

          WHERE state_hash = ?) AS epoch_ledgers_block

         ON epoch_ledgers_block.parent_id = parent.id
    |}

  let get_state_hash (module Conn : Caqti_async.CONNECTION)
      epoch_ledgers_state_hash =
    Conn.find query_state_hash epoch_ledgers_state_hash
end
