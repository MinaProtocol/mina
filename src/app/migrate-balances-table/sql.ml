(* sql.ml -- (Postgresql) SQL queries for migrate_balances_table *)

open Core_kernel

let create_temp_balances_table (module Conn : Caqti_async.CONNECTION) =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       {sql| CREATE TABLE IF NOT EXISTS balances_temp
           ( id                           serial PRIMARY KEY
           , public_key_id                int    NOT NULL REFERENCES public_keys(id)
           , balance                      bigint NOT NULL
           , block_id                     int    NOT NULL REFERENCES blocks(id)
           , block_height                 int    NOT NULL
           , block_sequence_no            int    NOT NULL
           , block_secondary_sequence_no  int    NOT NULL
           , UNIQUE (public_key_id,balance,block_id,block_height,block_sequence_no,block_secondary_sequence_no)
           )
      |sql} )

let copy_table_to_temp_table (module Conn : Caqti_async.CONNECTION) table =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| CREATE TABLE IF NOT EXISTS %s_temp AS (SELECT * FROM %s)
                |sql}
          table table ) )

let create_table_index (module Conn : Caqti_async.CONNECTION) table col =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| CREATE INDEX IF NOT EXISTS idx_%s_%s ON %s(%s)
                |sql}
          table col table col ) )

let create_temp_table_index (module Conn : Caqti_async.CONNECTION) table col =
  create_table_index (module Conn) (sprintf "%s_temp" table) col

let create_table_named_index (module Conn : Caqti_async.CONNECTION) table col
    name =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| CREATE INDEX IF NOT EXISTS idx_%s_%s ON %s(%s)
                |sql}
          table name table col ) )

let create_temp_table_named_index (module Conn : Caqti_async.CONNECTION) table
    col name =
  create_table_named_index (module Conn) (sprintf "%s_temp" table) col name

let drop_table_index (module Conn : Caqti_async.CONNECTION) table col =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf {sql| DROP INDEX IF EXISTS idx_%s_%s
          |sql} table col ) )

let drop_temp_table_index (module Conn : Caqti_async.CONNECTION) table col =
  drop_table_index (module Conn) (sprintf "%s_temp" table) col

let create_cursor (module Conn : Caqti_async.CONNECTION) name =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| CREATE TABLE IF NOT EXISTS %s_cursor
                      ( value int NOT NULL)
                 |sql}
          name ) )

let initialize_cursor (module Conn : Caqti_async.CONNECTION) name =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| INSERT INTO %s_cursor (value) VALUES (0)
                |sql}
          name ) )

let current_cursor (module Conn : Caqti_async.CONNECTION) name =
  Conn.find_opt
    (Caqti_request.find_opt Caqti_type.unit Caqti_type.int
       (sprintf {sql| SELECT value FROM %s_cursor
                |sql} name ) )

let update_cursor (module Conn : Caqti_async.CONNECTION) name ndx =
  Conn.exec
    (Caqti_request.exec Caqti_type.int
       (sprintf
          {sql| UPDATE %s_cursor SET value = $1
                |sql}
          name ) )
    ndx

let drop_foreign_key_constraint (module Conn : Caqti_async.CONNECTION) table
    foreign_key =
  let sql =
    sprintf
      {sql| ALTER TABLE %s
            DROP CONSTRAINT %s
      |sql}
      table foreign_key
  in
  Conn.exec (Caqti_request.exec Caqti_type.unit sql)

let add_balances_foreign_key_constraint (module Conn : Caqti_async.CONNECTION)
    table col foreign_key =
  let sql =
    sprintf
      {sql| ALTER TABLE %s
            ADD CONSTRAINT %s
            FOREIGN KEY (%s)
            REFERENCES balances(id) ON DELETE CASCADE
      |sql}
      table foreign_key col
  in
  Conn.exec (Caqti_request.exec Caqti_type.unit sql)

let add_blocks_foreign_key_constraint (module Conn : Caqti_async.CONNECTION)
    table col foreign_key =
  let sql =
    sprintf
      {sql| ALTER TABLE %s
            ADD CONSTRAINT %s
            FOREIGN KEY (%s)
            REFERENCES blocks(id) ON DELETE CASCADE
      |sql}
      table foreign_key col
  in
  Conn.exec (Caqti_request.exec Caqti_type.unit sql)

let find_balance_entry (module Conn : Caqti_async.CONNECTION) ~public_key_id
    ~balance ~block_id ~block_height ~block_sequence_no
    ~block_secondary_sequence_no =
  Conn.find_opt
    (Caqti_request.find_opt
       Caqti_type.(tup3 int int64 (tup4 int int int int))
       Caqti_type.int
       {sql| SELECT id
            FROM balances_temp
            WHERE public_key_id = $1
            AND balance = $2
            AND block_id = $3
            AND block_height = $4
            AND block_sequence_no = $5
            AND block_secondary_sequence_no = $6
      |sql} )
    ( public_key_id
    , balance
    , (block_id, block_height, block_sequence_no, block_secondary_sequence_no)
    )

let insert_balance_entry (module Conn : Caqti_async.CONNECTION) ~public_key_id
    ~balance ~block_id ~block_height ~block_sequence_no
    ~block_secondary_sequence_no =
  Conn.find
    (Caqti_request.find
       Caqti_type.(tup3 int int64 (tup4 int int int int))
       Caqti_type.int
       {sql| INSERT INTO balances_temp
            ( public_key_id
            , balance
            , block_id
            , block_height
            , block_sequence_no
            , block_secondary_sequence_no)
            VALUES
            ( $1
            , $2
            , $3
            , $4
            , $5
            , $6)
            RETURNING id
      |sql} )
    ( public_key_id
    , balance
    , (block_id, block_height, block_sequence_no, block_secondary_sequence_no)
    )

let get_internal_commands (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit
       Caqti_type.(tup4 int int64 (tup4 int int int int) int)
       {sql| SELECT bal.public_key_id,bal.balance,bic.block_id,blocks.height,bic.sequence_no,bic.secondary_sequence_no,
            internal_command_id
            FROM blocks_internal_commands bic
            INNER JOIN blocks ON blocks.id = bic.block_id
            INNER JOIN balances bal ON bal.id = receiver_balance
            ORDER BY (bal.public_key_id,bal.balance,bic.block_id,blocks.height,bic.sequence_no,bic.secondary_sequence_no,
                      internal_command_id)
      |sql} )

let update_internal_command_receiver_balance
    (module Conn : Caqti_async.CONNECTION) ~new_balance_id ~block_id
    ~internal_command_id ~block_sequence_no ~block_secondary_sequence_no =
  Conn.exec
    (Caqti_request.exec
       Caqti_type.(tup2 int (tup4 int int int int))
       {sql| UPDATE blocks_internal_commands_temp SET receiver_balance = $1
          WHERE block_id = $2
          AND internal_command_id = $3
          AND sequence_no = $4
          AND secondary_sequence_no = $5
      |sql} )
    ( new_balance_id
    , ( block_id
      , internal_command_id
      , block_sequence_no
      , block_secondary_sequence_no ) )

let get_user_command_fee_payers (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit
       Caqti_type.(tup2 (tup4 int int int int) (tup2 int int64))
       {sql| SELECT buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                    bal_fee_payer.public_key_id,bal_fee_payer.balance
             FROM blocks_user_commands buc
             INNER JOIN blocks ON blocks.id = buc.block_id
             INNER JOIN balances bal_fee_payer ON bal_fee_payer.id = fee_payer_balance
             ORDER BY (buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                       bal_fee_payer.public_key_id,bal_fee_payer.balance)
      |sql} )

let get_user_command_sources (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit
       Caqti_type.(tup2 (tup4 int int int int) (tup2 int int64))
       {sql| SELECT buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                    bal_source.public_key_id,bal_source.balance
             FROM blocks_user_commands buc
             INNER JOIN blocks ON blocks.id = buc.block_id
             INNER JOIN balances bal_source ON bal_source.id = source_balance
             WHERE source_balance IS NOT NULL
             ORDER BY (buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                       bal_source.public_key_id,bal_source.balance)
      |sql} )

let get_user_command_receivers (module Conn : Caqti_async.CONNECTION) =
  Conn.collect_list
    (Caqti_request.collect Caqti_type.unit
       Caqti_type.(tup2 (tup4 int int int int) (tup2 int int64))
       {sql| SELECT buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                    bal_receiver.public_key_id,bal_receiver.balance
             FROM blocks_user_commands buc
             INNER JOIN blocks ON blocks.id = buc.block_id
             INNER JOIN balances bal_receiver ON bal_receiver.id = receiver_balance
             WHERE receiver_balance IS NOT NULL
             ORDER BY (buc.block_id,blocks.height,buc.sequence_no,user_command_id,
                       bal_receiver.public_key_id,bal_receiver.balance)
      |sql} )

let update_user_command_fee_payer_balance (module Conn : Caqti_async.CONNECTION)
    ~new_balance_id ~block_id ~user_command_id ~block_sequence_no =
  Conn.exec
    (Caqti_request.exec
       Caqti_type.(tup2 int (tup3 int int int))
       {sql| UPDATE blocks_user_commands_temp SET fee_payer_balance = $1
          WHERE block_id = $2
          AND user_command_id = $3
          AND sequence_no = $4
      |sql} )
    (new_balance_id, (block_id, user_command_id, block_sequence_no))

let update_user_command_source_balance (module Conn : Caqti_async.CONNECTION)
    ~new_balance_id ~block_id ~user_command_id ~block_sequence_no =
  Conn.exec
    (Caqti_request.exec
       Caqti_type.(tup2 int (tup3 int int int))
       {sql| UPDATE blocks_user_commands_temp SET source_balance = $1
          WHERE block_id = $2
          AND user_command_id = $3
          AND sequence_no = $4
          AND source_balance IS NOT NULL
      |sql} )
    (new_balance_id, (block_id, user_command_id, block_sequence_no))

let update_user_command_receiver_balance (module Conn : Caqti_async.CONNECTION)
    ~new_balance_id ~block_id ~user_command_id ~block_sequence_no =
  Conn.exec
    (Caqti_request.exec
       Caqti_type.(tup2 int (tup3 int int int))
       {sql| UPDATE blocks_user_commands_temp SET receiver_balance = $1
          WHERE block_id = $2
          AND user_command_id = $3
          AND sequence_no = $4
          AND receiver_balance IS NOT NULL
      |sql} )
    (new_balance_id, (block_id, user_command_id, block_sequence_no))

let drop_table (module Conn : Caqti_async.CONNECTION) table =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf {sql| DROP TABLE %s
                |sql} table ) )

let rename_temp_table (module Conn : Caqti_async.CONNECTION) table =
  Conn.exec
    (Caqti_request.exec Caqti_type.unit
       (sprintf
          {sql| ALTER TABLE %s_temp
                RENAME TO %s
          |sql}
          table table ) )

let get_column_count (module Conn : Caqti_async.CONNECTION) table =
  Conn.find
    (Caqti_request.find Caqti_type.string Caqti_type.int
       {sql| SELECT COUNT(*) FROM information_schema.columns
             WHERE table_name=$1
       |sql} )
    table
