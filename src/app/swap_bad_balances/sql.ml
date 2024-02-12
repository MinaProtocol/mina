(* sql.ml -- (Postgresql) SQL queries for swap_bad_balances *)

open Async

module Receiver_balances = struct
  (* find receiver balances for combined fee transfer *)
  let query_ids_from_fee_transfer =
    Mina_caqti.collect_req
      Caqti_type.(t2 string int)
      Caqti_type.(int)
      {sql| SELECT bic.receiver_balance
            FROM blocks_internal_commands bic
            INNER JOIN blocks b
            ON b.id = bic.block_id
            WHERE b.state_hash = $1 AND bic.sequence_no = $2
      |sql}

  let run_ids_from_fee_transfer (module Conn : Caqti_async.CONNECTION)
      state_hash seq_no =
    Conn.collect_list query_ids_from_fee_transfer (state_hash, seq_no)

  let add_if_doesn't_exist (module Conn : Caqti_async.CONNECTION) (pk, balance)
      =
    let open Deferred.Result.Let_syntax in
    (* if duplicates, any is acceptable *)
    match%bind
      Conn.find_opt
        (Mina_caqti.find_opt_req
           Caqti_type.(t2 int int64)
           Caqti_type.int
           {sql| SELECT id
                          FROM balances
                          WHERE public_key_id = $1
                          AND balance = $2
                          LIMIT 1
                    |sql} )
        (pk, balance)
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Mina_caqti.find_req
             Caqti_type.(t2 int int64)
             Caqti_type.int
             "INSERT INTO balances (public_key_id,balance) VALUES ($1,$2) \
              RETURNING id" )
          (pk, balance)

  let load (module Conn : Caqti_async.CONNECTION) id =
    Conn.find
      (Mina_caqti.find_req
         Caqti_type.(int)
         Caqti_type.(t2 int int64)
         {sql| SELECT public_key_id,balance
            FROM balances
            WHERE id = $1
      |sql} )
      id

  let query_swap_in_new_balance =
    Mina_caqti.exec_req
      Caqti_type.(t4 string int int int)
      {sql| UPDATE blocks_internal_commands bic SET receiver_balance = $4
            FROM blocks b
            WHERE b.id = bic.block_id
            AND b.state_hash = $1
            AND bic.sequence_no = $2
            AND bic.receiver_balance = $3
      |sql}

  let swap_in_new_balance (module Conn : Caqti_async.CONNECTION) state_hash
      seq_no old_balance_id new_balance_id =
    Conn.exec query_swap_in_new_balance
      (state_hash, seq_no, old_balance_id, new_balance_id)
end
