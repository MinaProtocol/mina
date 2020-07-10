open Core_kernel

let yojson_strip_fields ~keep_fields = function
  | `Assoc l ->
      `Assoc
        (List.filter l ~f:(fun (fld, _) ->
             Array.mem ~equal:String.equal keep_fields fld ))
  | json ->
      json

let opt_fallthrough ~default x2 =
  Option.value_map ~default x2 ~f:(fun x -> Some x)

module Accounts = struct
  type single =
    { pk: string option [@default None]
    ; sk: string option [@default None]
    ; balance: Currency.Balance.t
    ; delegate: string option [@default None] }
  [@@deriving yojson, dhall_type]

  let single_of_yojson json =
    single_of_yojson
    @@ yojson_strip_fields
         ~keep_fields:[|"pk"; "sk"; "balance"; "delegate"|]
         json

  type t = single list [@@deriving yojson, dhall_type]
end

module Ledger = struct
  type base =
    | Named of string  (** One of the named ledgers in [Genesis_ledger] *)
    | Accounts of Accounts.t  (** A ledger generated from the given accounts *)
    | Hash of string  (** The ledger with the given root hash *)
  [@@deriving dhall_type]

  type t =
    { base: base
    ; num_accounts: int option
    ; hash: string option
    ; name: string option }
  [@@deriving dhall_type]

  let base_to_yojson_field = function
    | Named name ->
        ("name", `String name)
    | Accounts accounts ->
        ("accounts", Accounts.to_yojson accounts)
    | Hash hash ->
        ("hash", `String hash)

  let base_of_yojson_fields l =
    List.find_map_exn
      ~f:(fun f -> f l)
      [ List.find_map ~f:(fun (fld, value) ->
            if String.equal fld "accounts" then
              Some
                (Result.map
                   ~f:(fun accounts -> Accounts accounts)
                   (Accounts.of_yojson value))
            else None )
      ; List.find_map ~f:(fun (fld, value) ->
            if String.equal fld "name" || String.equal fld "named" then
              match value with
              | `String name ->
                  Some (Ok (Named name))
              | _ ->
                  Some
                    (Error
                       (sprintf
                          "Runtime_config.Ledger.of_yojson: Expected the \
                           field '%s' to contain a string"
                          fld))
            else None )
      ; List.find_map ~f:(fun (fld, value) ->
            if String.equal fld "hash" then
              match value with
              | `String name ->
                  Some (Ok (Hash name))
              | _ ->
                  Some
                    (Error
                       "Runtime_config.Ledger.of_yojson: Expected the field \
                        'hash' to contain a string")
            else None )
      ; (fun _ ->
          Some
            (Error
               "Runtime_config.Ledger.of_yojson: Expected a field 'accounts', \
                'name' or 'hash'") ) ]

  let to_yojson {base; num_accounts; hash; name} =
    let fields =
      List.filter_opt
        [ Option.map num_accounts ~f:(fun i -> ("num_accounts", `Int i))
        ; Option.bind hash ~f:(fun hash ->
              match base with
              | Hash _ ->
                  None
              | _ ->
                  Some ("hash", `String hash) )
        ; Option.bind name ~f:(fun name ->
              match base with
              | Named _ ->
                  None
              | _ ->
                  Some ("name", `String name) ) ]
    in
    `Assoc (base_to_yojson_field base :: fields)

  let of_yojson = function
    | `Assoc l ->
        let open Result.Let_syntax in
        let%bind base = base_of_yojson_fields l in
        let%bind num_accounts =
          Option.value ~default:(return None)
          @@ List.find_map l ~f:(fun (fld, value) ->
                 if String.equal "num_accounts" fld then
                   match value with
                   | `Int i ->
                       Some (return (Some i))
                   | _ ->
                       Some
                         (Error
                            "Runtime_config.Ledger.of_yojson: Expected the \
                             field 'num_accounts' to contain an integer")
                 else None )
        in
        let%bind name =
          Option.value ~default:(return None)
          @@ List.find_map l ~f:(fun (fld, value) ->
                 if String.equal fld "name" || String.equal fld "named" then
                   match value with
                   | `String name ->
                       Some (Ok (Some name))
                   | _ ->
                       Some
                         (Error
                            (sprintf
                               "Runtime_config.Ledger.of_yojson: Expected the \
                                field '%s' to contain a string"
                               fld))
                 else None )
        in
        let%map hash =
          match base with
          | Hash hash ->
              return (Some hash)
          | _ ->
              Option.value ~default:(return None)
              @@ List.find_map l ~f:(fun (fld, value) ->
                     if String.equal "hash" fld then
                       match value with
                       | `String hash ->
                           Some (return (Some hash))
                       | _ ->
                           Some
                             (Error
                                "Runtime_config.Ledger.of_yojson: Expected \
                                 the field 'hash' to contain a string")
                     else None )
        in
        {base; num_accounts; hash; name}
    | _ ->
        Error "Runtime_config.Ledger.of_yojson: Expected a JSON object"
end

module Proof_keys = struct
  module Level = struct
    type t = Full | Check | None [@@deriving dhall_type]

    let to_yojson = function
      | Full ->
          `String "full"
      | Check ->
          `String "check"
      | None ->
          `String "none"

    let of_yojson = function
      | `String str -> (
        match String.lowercase str with
        | "full" ->
            Ok Full
        | "check" ->
            Ok Check
        | "none" ->
            Ok None
        | _ ->
            Error
              "Runtime_config.Proof_keys.Level.of_yojson: Expected the field \
               'level' to contain one of 'full', 'check', or 'none'" )
      | _ ->
          Error
            "Runtime_config.Proof_keys.Level.of_yojson: Expected the field \
             'level' to contain a string"
  end

  module Transaction_capacity = struct
    type t = Log_2 of int | Txns_per_second_x10 of int
    [@@deriving dhall_type]

    let to_yojson = function
      | Log_2 i ->
          `Assoc [("2_to_the", `Int i)]
      | Txns_per_second_x10 i ->
          `Assoc [("txns_per_second_x10", `Int i)]

    let of_yojson json =
      match
        yojson_strip_fields
          ~keep_fields:[|"2_to_the"; "txns_per_second_x10"|]
          json
      with
      | `Assoc [("2_to_the", i)] -> (
        match i with
        | `Int i ->
            Ok (Log_2 i)
        | _ ->
            Error
              "Runtime_config.Proof_keys.Transaction_capacity.of_yojson: \
               Expected the field '2_to_the' to contain an integer" )
      | `Assoc [("txns_per_second_x10", i)] -> (
        match i with
        | `Int i ->
            Ok (Txns_per_second_x10 i)
        | _ ->
            Error
              "Runtime_config.Proof_keys.Transaction_capacity.of_yojson: \
               Expected the field 'txns_per_second_x10' to contain an integer"
        )
      | `Assoc _ ->
          Error
            "Runtime_config.Proof_keys.Transaction_capacity.of_yojson: \
             Expected exactly one of the fields '2_to_the' or \
             'txns_per_second_x10'"
      | _ ->
          Error
            "Runtime_config.Proof_keys.Level.of_yojson: Expected the field \
             'transaction_capacity' to contain a JSON object"
  end

  type t =
    { level: Level.t option [@default None]
    ; c: int option [@default None]
    ; ledger_depth: int option [@default None]
    ; work_delay: int option [@default None]
    ; block_window_duration_ms: int option [@default None]
    ; transaction_capacity: Transaction_capacity.t option [@default None]
    ; coinbase_amount: Currency.Amount.t option [@default None]
    ; account_creation_fee: Currency.Fee.t option [@default None] }
  [@@deriving yojson, dhall_type]

  let of_yojson json =
    of_yojson
    @@ yojson_strip_fields
         ~keep_fields:
           [| "level"
            ; "c"
            ; "ledger_depth"
            ; "work_delay"
            ; "block_window_duration_ms"
            ; "transaction_capacity"
            ; "coinbase_amount"
            ; "account_creation_fee" |]
         json

  let combine t1 t2 =
    { level= opt_fallthrough ~default:t1.level t2.level
    ; c= opt_fallthrough ~default:t1.c t2.c
    ; ledger_depth= opt_fallthrough ~default:t1.ledger_depth t2.ledger_depth
    ; work_delay= opt_fallthrough ~default:t1.work_delay t2.work_delay
    ; block_window_duration_ms=
        opt_fallthrough ~default:t1.block_window_duration_ms
          t2.block_window_duration_ms
    ; transaction_capacity=
        opt_fallthrough ~default:t1.transaction_capacity
          t2.transaction_capacity
    ; coinbase_amount=
        opt_fallthrough ~default:t1.coinbase_amount t2.coinbase_amount
    ; account_creation_fee=
        opt_fallthrough ~default:t1.account_creation_fee
          t2.account_creation_fee }
end

module Genesis = struct
  type t =
    { k: int option [@default None]
    ; delta: int option [@default None]
    ; genesis_state_timestamp: string option [@default None] }
  [@@deriving yojson, dhall_type]

  let of_yojson json =
    of_yojson
    @@ yojson_strip_fields
         ~keep_fields:[|"k"; "delta"; "genesis_state_timestamp"|]
         json

  let combine t1 t2 =
    { k= opt_fallthrough ~default:t1.k t2.k
    ; delta= opt_fallthrough ~default:t1.delta t2.delta
    ; genesis_state_timestamp=
        opt_fallthrough ~default:t1.genesis_state_timestamp
          t2.genesis_state_timestamp }
end

module Daemon = struct
  type t = {txpool_max_size: int option [@default None]}
  [@@deriving yojson, dhall_type]

  let of_yojson json =
    of_yojson @@ yojson_strip_fields ~keep_fields:[|"txpool_max_size"|] json

  let combine t1 t2 =
    { txpool_max_size=
        opt_fallthrough ~default:t1.txpool_max_size t2.txpool_max_size }
end

(** JSON representation:

  { "daemon":
      { "txpool_max_size": 1 }
  , "genesis": { "k": 1, "delta": 1 }
  , "proof":
      { "level": "check"
      , "c": 8
      , "ledger_depth": 14
      , "work_delay": 2
      , "block_window_duration_ms": 180000
      , "transaction_capacity": {"txns_per_second_x10": 2}
      , "coinbase_amount": "200"
      , "account_creation_fee": "0.001" }
  , "ledger":
      { "name": "release"
      , "accounts":
          [ { "pk": "public_key"
            , "sk": "secret_key"
            , "balance": "0.000600000"
            , "delegate": "public_key" }
          , { "pk": "public_key"
            , "sk": "secret_key"
            , "balance": "0.000000000"
            , "delegate": "public_key" } ]
      , "hash": "root_hash"
      , "num_accounts": 10
      , "genesis_state_timestamp": "2000-00-00 12:00:00+0100" } }

  All fields are optional *except*:
  * each account in [ledger.accounts] must have a [balance] field
  * if [ledger] is present, it must feature one of [name], [accounts] or [hash].

*)

type t =
  { daemon: Daemon.t option [@default None]
  ; genesis: Genesis.t option [@default None]
  ; proof: Proof_keys.t option [@default None]
  ; ledger: Ledger.t option [@default None] }
[@@deriving yojson, dhall_type]

let keep_fields = [|"ledger"; "genesis"; "proof"|]

let of_yojson json = of_yojson @@ yojson_strip_fields ~keep_fields json

let default = {daemon= None; genesis= None; proof= None; ledger= None}

let combine t1 t2 =
  let merge ~combine t1 t2 =
    match (t1, t2) with
    | Some t1, Some t2 ->
        Some (combine t1 t2)
    | Some t, None | None, Some t ->
        Some t
    | None, None ->
        None
  in
  { daemon= merge ~combine:Daemon.combine t1.daemon t2.daemon
  ; genesis= merge ~combine:Genesis.combine t1.genesis t2.genesis
  ; proof= merge ~combine:Proof_keys.combine t1.proof t2.proof
  ; ledger= opt_fallthrough ~default:t1.ledger t2.ledger }
