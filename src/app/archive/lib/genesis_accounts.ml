(* genesis_accounts.ml -- the state of every account when an era's genesis
   ledger took effect. Initial conditions, not block effects: what a balance
   query falls back to for an account that no block touched. The requests are
   in Genesis_accounts_sql. *)

open Async
open Core
open Mina_base
module Sql = Genesis_accounts_sql

type timing =
  { initial_minimum_balance : string
  ; cliff_time : int64
  ; cliff_amount : string
  ; vesting_period : int64
  ; vesting_increment : string
  }
[@@deriving equal, sexp]

type row =
  { public_key : string
  ; token : string
  ; balance : string
  ; nonce : int64
  ; timing : timing option
  }
[@@deriving equal, sexp]

(** Encoded as accounts_accessed and timing_info encode the same values. *)
let row_of_account (account : Account.t) =
  let timing =
    match account.timing with
    | Untimed ->
        None
    | Timed
        { initial_minimum_balance
        ; cliff_time
        ; cliff_amount
        ; vesting_period
        ; vesting_increment
        } ->
        Some
          { initial_minimum_balance =
              Currency.Balance.to_string initial_minimum_balance
          ; cliff_time =
              Mina_numbers.Global_slot_since_genesis.to_uint32 cliff_time
              |> Unsigned.UInt32.to_int64
          ; cliff_amount = Currency.Amount.to_string cliff_amount
          ; vesting_period =
              Mina_numbers.Global_slot_span.to_uint32 vesting_period
              |> Unsigned.UInt32.to_int64
          ; vesting_increment = Currency.Amount.to_string vesting_increment
          }
  in
  { public_key =
      Signature_lib.Public_key.Compressed.to_base58_check account.public_key
  ; token = Token_id.to_string account.token_id
  ; balance = Currency.Balance.to_string account.balance
  ; nonce = Account.Nonce.to_uint32 account.nonce |> Unsigned.UInt32.to_int64
  ; timing
  }

let row_of_tuple
    ( (public_key, token, balance, nonce)
    , ( initial_minimum_balance
      , cliff_time
      , cliff_amount
      , vesting_period
      , vesting_increment ) ) =
  let timing =
    match
      ( initial_minimum_balance
      , cliff_time
      , cliff_amount
      , vesting_period
      , vesting_increment )
    with
    | ( Some initial_minimum_balance
      , Some cliff_time
      , Some cliff_amount
      , Some vesting_period
      , Some vesting_increment ) ->
        Some
          { initial_minimum_balance
          ; cliff_time
          ; cliff_amount
          ; vesting_period
          ; vesting_increment
          }
    | _ ->
        None
  in
  { public_key; token; balance; nonce; timing }

type found =
  { genesis_height : int64
  ; genesis_slot : int64 option
        (** The global slot of the genesis block, when the archive has it. *)
  ; row : row
  }

(** The account in the newest genesis ledger at or below [height]. [None]
    when no such ledger lists it, and when the database has no
    [genesis_accounts] table. *)
let latest (module Conn : Mina_caqti.CONNECTION) ~public_key ~token ~height =
  let open Deferred.Result.Let_syntax in
  match%bind Sql.table_exists (module Conn) with
  | false ->
      return None
  | true ->
      let%map found = Sql.latest (module Conn) ~public_key ~token ~height in
      Option.map found ~f:(fun (genesis_height, genesis_slot, row) ->
          { genesis_height; genesis_slot; row = row_of_tuple row } )

let insert_chunk (module Conn : Mina_caqti.CONNECTION) ~genesis_height rows =
  let column f = Array.of_list (List.map rows ~f) in
  let timing f = column (fun row -> Option.map row.timing ~f) in
  Sql.insert_chunk
    (module Conn)
    ~genesis_height
    ~public_keys:(column (fun row -> row.public_key))
    ~tokens:(column (fun row -> row.token))
    ~balances:(column (fun row -> row.balance))
    ~nonces:(column (fun row -> row.nonce))
    ~initial_minimum_balances:(timing (fun t -> t.initial_minimum_balance))
    ~cliff_times:(timing (fun t -> t.cliff_time))
    ~cliff_amounts:(timing (fun t -> t.cliff_amount))
    ~vesting_periods:(timing (fun t -> t.vesting_period))
    ~vesting_increments:(timing (fun t -> t.vesting_increment))

let default_chunk_size = 5_000

(** Write [accounts] as the genesis ledger that takes effect at
    [genesis_height].

    Each chunk of [chunk_size] accounts is one statement and one transaction,
    so an interrupted import keeps what it wrote. The accounts are written in
    a fixed order (public key, then token), so the rows a height already has
    are the first ones in that order, and a later call continues after them.
    The ledger is written when the height has as many rows as the ledger has
    accounts; a repeated row is ignored. *)
let add ?(chunk_size = default_chunk_size) (module Conn : Mina_caqti.CONNECTION)
    ~genesis_height accounts =
  let open Deferred.Result.Let_syntax in
  match%bind Sql.table_exists (module Conn) with
  | false ->
      return `No_table
  | true ->
      let rows =
        List.map accounts ~f:row_of_account
        |> List.sort ~compare:(fun a b ->
               [%compare: string * string] (a.public_key, a.token)
                 (b.public_key, b.token) )
      in
      let total = List.length rows in
      let%bind already = Sql.written (module Conn) ~genesis_height in
      if already >= total then return `Already_loaded
      else
        let%map () =
          List.drop rows already
          |> List.chunks_of ~length:chunk_size
          |> Mina_caqti.deferred_result_list_fold ~init:() ~f:(fun () chunk ->
                 let%bind () = Conn.start () in
                 match%bind.Deferred
                   insert_chunk (module Conn) ~genesis_height chunk
                 with
                 | Ok () ->
                     Conn.commit ()
                 | Error e ->
                     let%bind.Deferred (_ : (unit, _) Result.t) =
                       Conn.rollback ()
                     in
                     Deferred.Result.fail e )
        in
        `Added (total - already, already)
