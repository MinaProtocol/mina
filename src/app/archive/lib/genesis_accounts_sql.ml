(* genesis_accounts_sql.ml -- requests on the genesis_accounts table (see
   create_schema.sql) *)

open Mina_caqti

(** Whether the database has the table: one created before the schema upgrade
    that adds it does not. *)
let table_exists (module Conn : CONNECTION) =
  Conn.find
    (find_req Caqti_type.unit Caqti_type.bool
       "SELECT to_regclass('genesis_accounts') IS NOT NULL" )
    ()

(** The number of rows of the genesis ledger at [genesis_height]. *)
let written (module Conn : CONNECTION) ~genesis_height =
  Conn.find
    (find_req Caqti_type.int64 Caqti_type.int
       {sql| SELECT count(*)::int FROM genesis_accounts
             WHERE genesis_height = ?
       |sql} )
    genesis_height

(* One statement per chunk: the rows travel as one array per column. *)
let insert_chunk_req =
  exec_req
    Caqti_type.(
      t2
        (t4 int64 Mina_caqti.array_string_typ Mina_caqti.array_string_typ
           Mina_caqti.array_string_typ )
        (t2 Mina_caqti.array_int64_typ
           (t5 Mina_caqti.array_nullable_string_typ
              Mina_caqti.array_nullable_int64_typ
              Mina_caqti.array_nullable_string_typ
              Mina_caqti.array_nullable_int64_typ
              Mina_caqti.array_nullable_string_typ ) ))
    {sql| INSERT INTO genesis_accounts
            (genesis_height, public_key, token, balance, nonce,
             initial_minimum_balance, cliff_time, cliff_amount,
             vesting_period, vesting_increment)
          SELECT $1, rows.*
          FROM unnest($2::text[], $3::text[], $4::text[], $5::bigint[],
                      $6::text[], $7::bigint[], $8::text[], $9::bigint[],
                      $10::text[]) AS rows
          ON CONFLICT DO NOTHING
    |sql}

(** Insert one chunk of rows, given column by column; the timing columns are
    [None] for an untimed account. A repeated row is ignored. *)
let insert_chunk (module Conn : CONNECTION) ~genesis_height ~public_keys ~tokens
    ~balances ~nonces ~initial_minimum_balances ~cliff_times ~cliff_amounts
    ~vesting_periods ~vesting_increments =
  Conn.exec insert_chunk_req
    ( (genesis_height, public_keys, tokens, balances)
    , ( nonces
      , ( initial_minimum_balances
        , cliff_times
        , cliff_amounts
        , vesting_periods
        , vesting_increments ) ) )

let row_typ =
  Caqti_type.(
    t2
      (t4 string string string int64)
      (t5 (option string) (option int64) (option string) (option int64)
         (option string) ))

let latest_req =
  find_opt_req
    Caqti_type.(t3 string string int64)
    Caqti_type.(t3 int64 (option int64) row_typ)
    {sql| SELECT ga.genesis_height,
                 (SELECT b.global_slot_since_genesis FROM blocks b
                  WHERE b.height = ga.genesis_height
                    AND b.global_slot_since_hard_fork = 0
                  ORDER BY b.id LIMIT 1),
                 ga.public_key, ga.token, ga.balance, ga.nonce,
                 ga.initial_minimum_balance, ga.cliff_time, ga.cliff_amount,
                 ga.vesting_period, ga.vesting_increment
          FROM genesis_accounts ga
          WHERE ga.public_key = $1
            AND ga.token = $2
            AND ga.genesis_height <= $3
          ORDER BY ga.genesis_height DESC
          LIMIT 1
    |sql}

(** The row of the account in the newest genesis ledger at or below
    [height], with that ledger's height and the genesis block's slot. *)
let latest (module Conn : CONNECTION) ~public_key ~token ~height =
  Conn.find_opt latest_req (public_key, token, height)
