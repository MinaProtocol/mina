(* sql.ml -- (Postgresql) SQL queries for migrate_balances_include_nonces *)

let add_nonce_column (module Conn : Caqti_async.CONNECTION) =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       {sql| ALTER TABLE balances ADD COLUMN IF NOT EXISTS nonce bigint
       |sql})

let fee_payers_and_nonces (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit
       Caqti_type.(tup2 int int64)
       {sql| SELECT fee_payer_balance,nonce
             FROM user_commands uc
             INNER JOIN blocks_user_commands buc
             ON uc.id = buc.user_command_id
       |sql})

let update_balance_nonce (module Conn : Caqti_async.CONNECTION) ~id ~nonce =
  Conn.exec
    (Caqti_request.exec
       Caqti_type.(tup2 int int64)
       {sql| UPDATE balances
             SET nonce = $2
             WHERE id = $1
       |sql})
    (id, nonce)

let balances_with_null_nonces (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit Archive_lib.Processor.Balance.typ
       {sql| SELECT id,public_key_id, balance,
                    block_id, block_height,
                    block_sequence_no,block_secondary_sequence_no,
                    nonce
             FROM balances
             WHERE nonce IS NULL
       |sql})

let most_recent_nonce (module Conn : Caqti_async.CONNECTION) ~public_key_id
    ~block_height ~block_sequence_no ~block_secondary_sequence_no =
  Conn.find_opt
    (Caqti_request.find_opt
       Caqti_type.(tup4 int int64 int int)
       Caqti_type.int64
       {sql| SELECT nonce FROM balances
             WHERE public_key_id = $1
             AND (block_height < $2
                  OR (block_height = $2 AND block_sequence_no < $3)
                  OR (block_height = $2 AND block_sequence_no = $3 AND block_secondary_sequence_no < $4))
             AND nonce IS NOT NULL
             ORDER BY block_height DESC, block_sequence_no DESC, block_secondary_sequence_no DESC LIMIT 1
       |sql})
    (public_key_id, block_height, block_sequence_no, block_secondary_sequence_no)
