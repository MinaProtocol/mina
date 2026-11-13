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

(** Rows at a height that are not [accounts]: [differing] rows hold another
    state for an account of the ledger, [not_in_ledger] rows are accounts the
    ledger does not have. Such a height was written from another ledger (an
    older config, another network), or by hand. *)
type mismatch = { differing : int; not_in_ledger : int }
[@@deriving equal, sexp, yojson]

(** Write [accounts] as the genesis ledger that takes effect at
    [genesis_height].

    The rows the height already has are compared with [accounts] first. When
    each is a row of [accounts], the missing ones are written: an interrupted
    import continues, whatever order it stopped in. When any differs, or is not
    an account of [accounts], nothing is written and the result is
    [`Mismatch]: the height holds another ledger, which is not overwritten.

    Each chunk of [chunk_size] accounts is one statement and one transaction,
    so an interrupted import keeps what it wrote. *)
let add ?(chunk_size = default_chunk_size) (module Conn : Mina_caqti.CONNECTION)
    ~genesis_height accounts =
  let open Deferred.Result.Let_syntax in
  match%bind Sql.table_exists (module Conn) with
  | false ->
      return `No_table
  | true -> (
      let key row = row.public_key ^ "\000" ^ row.token in
      let rows =
        List.map accounts ~f:row_of_account
        |> List.sort ~compare:(fun a b ->
               [%compare: string * string] (a.public_key, a.token)
                 (b.public_key, b.token) )
      in
      let ledger =
        String.Map.of_alist_exn (List.map rows ~f:(fun r -> (key r, r)))
      in
      let%bind written =
        Sql.rows_at (module Conn) ~genesis_height >>| List.map ~f:row_of_tuple
      in
      let mismatch =
        List.fold written ~init:{ differing = 0; not_in_ledger = 0 }
          ~f:(fun acc row ->
            match Map.find ledger (key row) with
            | None ->
                { acc with not_in_ledger = acc.not_in_ledger + 1 }
            | Some expected when equal_row expected row ->
                acc
            | Some _ ->
                { acc with differing = acc.differing + 1 } )
      in
      if mismatch.differing > 0 || mismatch.not_in_ledger > 0 then
        return (`Mismatch mismatch)
      else
        let present = String.Set.of_list (List.map written ~f:key) in
        let missing =
          List.filter rows ~f:(fun row -> not (Set.mem present (key row)))
        in
        match missing with
        | [] ->
            return `Already_loaded
        | _ ->
            let%map () =
              List.chunks_of missing ~length:chunk_size
              |> Mina_caqti.deferred_result_list_fold ~init:()
                   ~f:(fun () chunk ->
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
            `Added (List.length missing, List.length written) )

(** What to tell an operator about a [`Mismatch] at [genesis_height]. *)
let mismatch_message ~genesis_height { differing; not_in_ledger } =
  sprintf
    "genesis_accounts at height %Ld holds another genesis ledger than the \
     config's (%d rows differ, %d accounts are not in the config's ledger): it \
     was written from another config or network. It is not overwritten; to \
     replace it, run DELETE FROM genesis_accounts WHERE genesis_height = %Ld \
     and write the ledger again"
    genesis_height differing not_in_ledger genesis_height
