open Core_kernel

let yojson_strip_fields ~keep_fields = function
  | `Assoc l ->
      `Assoc
        (List.filter l ~f:(fun (fld, _) ->
             Array.mem ~equal:String.equal keep_fields fld ))
  | json ->
      json

let yojson_rename_fields ~alternates = function
  | `Assoc l ->
      `Assoc
        (List.map l ~f:(fun (fld, json) ->
             let fld =
               Option.value ~default:fld
                 (Array.find_map alternates ~f:(fun (alt, orig) ->
                      if String.equal fld alt then Some orig else None ))
             in
             (fld, json) ))
  | json ->
      json

let opt_fallthrough ~default x2 =
  Option.value_map ~default x2 ~f:(fun x -> Some x)

let result_opt ~f x =
  match x with
  | Some x ->
      Result.map ~f:Option.some (f x)
  | None ->
      Result.return None

module Json_layout = struct
  module Accounts = struct
    module Single = struct
      type t =
        { pk: (string option[@default None])
        ; sk: (string option[@default None])
        ; balance: Currency.Balance.t
        ; delegate: (string option[@default None]) }
      [@@deriving yojson, dhall_type]

      let fields = [|"pk"; "sk"; "balance"; "delegate"|]

      let of_yojson json =
        of_yojson @@ yojson_strip_fields ~keep_fields:fields json
    end

    type t = Single.t list [@@deriving yojson, dhall_type]
  end

  module Ledger = struct
    type t =
      { accounts: (Accounts.t option[@default None])
      ; num_accounts: (int option[@default None])
      ; hash: (string option[@default None])
      ; name: (string option[@default None])
      ; add_genesis_winner: (bool option[@default None]) }
    [@@deriving yojson, dhall_type]

    let fields =
      [|"accounts"; "num_accounts"; "hash"; "name"; "add_genesis_winner"|]

    let of_yojson json =
      of_yojson @@ yojson_strip_fields ~keep_fields:fields json
  end

  module Proof_keys = struct
    module Transaction_capacity = struct
      type t =
        { log_2: (int option[@default None])
              [@key "2_to_the"] [@dhall_type.key "two_to_the"]
        ; txns_per_second_x10: (int option[@default None]) }
      [@@deriving yojson, dhall_type]

      let fields = [|"2_to_the"; "txns_per_second_x10"|]

      let alternates = [|("two_to_the", "2_to_the"); ("log_2", "2_to_the")|]

      let of_yojson json =
        json
        |> yojson_rename_fields ~alternates
        |> yojson_strip_fields ~keep_fields:fields
        |> of_yojson
    end

    type t =
      { level: (string option[@default None])
      ; c: (int option[@default None])
      ; ledger_depth: (int option[@default None])
      ; work_delay: (int option[@default None])
      ; block_window_duration_ms: (int option[@default None])
      ; transaction_capacity: (Transaction_capacity.t option[@default None])
      ; coinbase_amount: (Currency.Amount.t option[@default None])
      ; account_creation_fee: (Currency.Fee.t option[@default None]) }
    [@@deriving yojson, dhall_type]

    let fields =
      [| "level"
       ; "c"
       ; "ledger_depth"
       ; "work_delay"
       ; "block_window_duration_ms"
       ; "transaction_capacity"
       ; "coinbase_amount"
       ; "account_creation_fee" |]

    let of_yojson json =
      of_yojson @@ yojson_strip_fields ~keep_fields:fields json
  end

  module Genesis = struct
    type t =
      { k: (int option[@default None])
      ; delta: (int option[@default None])
      ; genesis_state_timestamp: (string option[@default None]) }
    [@@deriving yojson, dhall_type]

    let fields = [|"k"; "delta"; "genesis_state_timestamp"|]

    let of_yojson json =
      of_yojson @@ yojson_strip_fields ~keep_fields:fields json
  end

  module Daemon = struct
    type t = {txpool_max_size: (int option[@default None])}
    [@@deriving yojson, dhall_type]

    let fields = [|"txpool_max_size"|]

    let of_yojson json =
      of_yojson @@ yojson_strip_fields ~keep_fields:fields json
  end

  type t =
    { daemon: (Daemon.t option[@default None])
    ; genesis: (Genesis.t option[@default None])
    ; proof: (Proof_keys.t option[@default None])
    ; ledger: (Ledger.t option[@default None]) }
  [@@deriving yojson, dhall_type]

  let fields = [|"daemon"; "ledger"; "genesis"; "proof"|]

  let of_yojson json =
    of_yojson @@ yojson_strip_fields ~keep_fields:fields json
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

module Accounts = struct
  module Single = struct
    type t = Json_layout.Accounts.Single.t =
      { pk: string option
      ; sk: string option
      ; balance: Currency.Balance.Stable.Latest.t
      ; delegate: string option }
    [@@deriving bin_io_unversioned]

    let to_json_layout : t -> Json_layout.Accounts.Single.t = Fn.id

    let of_json_layout : Json_layout.Accounts.Single.t -> (t, string) Result.t
        =
      Result.return

    let to_yojson x = Json_layout.Accounts.Single.to_yojson (to_json_layout x)

    let of_yojson json =
      Result.bind ~f:of_json_layout
        (Json_layout.Accounts.Single.of_yojson json)
  end

  type single = Single.t =
    { pk: string option
    ; sk: string option
    ; balance: Currency.Balance.t
    ; delegate: string option }

  type t = Single.t list [@@deriving bin_io_unversioned]

  let to_json_layout : t -> Json_layout.Accounts.t =
    List.map ~f:Single.to_json_layout

  let of_json_layout (t : Json_layout.Accounts.t) : (t, string) Result.t =
    let exception Stop of string in
    try
      Result.return
      @@ List.map t ~f:(fun x ->
             match Single.of_json_layout x with
             | Ok x ->
                 x
             | Error err ->
                 raise (Stop err) )
    with Stop err -> Error err

  let to_yojson x = Json_layout.Accounts.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Accounts.of_yojson json)
end

module Ledger = struct
  type base =
    | Named of string  (** One of the named ledgers in [Genesis_ledger] *)
    | Accounts of Accounts.t  (** A ledger generated from the given accounts *)
    | Hash of string  (** The ledger with the given root hash *)
  [@@deriving bin_io_unversioned]

  type t =
    { base: base
    ; num_accounts: int option
    ; hash: string option
    ; name: string option
    ; add_genesis_winner: bool option }
  [@@deriving bin_io_unversioned]

  let to_json_layout {base; num_accounts; hash; name; add_genesis_winner} :
      Json_layout.Ledger.t =
    let without_base : Json_layout.Ledger.t =
      {accounts= None; num_accounts; hash; name; add_genesis_winner}
    in
    match base with
    | Named name ->
        {without_base with name= Some name}
    | Accounts accounts ->
        {without_base with accounts= Some (Accounts.to_json_layout accounts)}
    | Hash hash ->
        {without_base with hash= Some hash}

  let of_json_layout
      ({accounts; num_accounts; hash; name; add_genesis_winner} :
        Json_layout.Ledger.t) : (t, string) Result.t =
    let open Result.Let_syntax in
    let%map base =
      match accounts with
      | Some accounts ->
          let%map accounts = Accounts.of_json_layout accounts in
          Accounts accounts
      | None -> (
        match name with
        | Some name ->
            return (Named name)
        | None -> (
          match hash with
          | Some hash ->
              return (Hash hash)
          | None ->
              Error
                "Runtime_config.Ledger.of_json_layout: Expected a field \
                 'accounts', 'name' or 'hash'" ) )
    in
    {base; num_accounts; hash; name; add_genesis_winner}

  let to_yojson x = Json_layout.Ledger.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Ledger.of_yojson json)
end

module Proof_keys = struct
  module Level = struct
    type t = Full | Check | None [@@deriving bin_io_unversioned, eq]

    let to_string = function
      | Full ->
          "full"
      | Check ->
          "check"
      | None ->
          "none"

    let of_string str =
      match String.lowercase str with
      | "full" ->
          Ok Full
      | "check" ->
          Ok Check
      | "none" ->
          Ok None
      | _ ->
          Error "Expected one of 'full', 'check', or 'none'"

    let to_json_layout = to_string

    let of_json_layout str =
      Result.map_error (of_string str) ~f:(fun err ->
          "Runtime_config.Proof_keys.Level.of_json_layout: Could not decode \
           field 'level'. " ^ err )

    let to_yojson x = `String (to_json_layout x)

    let of_yojson = function
      | `String str ->
          of_json_layout str
      | _ ->
          Error
            "Runtime_config.Proof_keys.Level.of_json_layout: Expected the \
             field 'level' to contain a string"
  end

  module Transaction_capacity = struct
    type t = Log_2 of int | Txns_per_second_x10 of int
    [@@deriving bin_io_unversioned]

    let to_json_layout : t -> Json_layout.Proof_keys.Transaction_capacity.t =
      function
      | Log_2 i ->
          {log_2= Some i; txns_per_second_x10= None}
      | Txns_per_second_x10 i ->
          {log_2= None; txns_per_second_x10= Some i}

    let of_json_layout :
        Json_layout.Proof_keys.Transaction_capacity.t -> (t, string) Result.t =
      function
      | {log_2= Some i; txns_per_second_x10= None} ->
          Ok (Log_2 i)
      | {txns_per_second_x10= Some i; log_2= None} ->
          Ok (Txns_per_second_x10 i)
      | _ ->
          Error
            "Runtime_config.Proof_keys.Transaction_capacity.of_json_layout: \
             Expected exactly one of the fields '2_to_the' or \
             'txns_per_second_x10'"

    let to_yojson x =
      Json_layout.Proof_keys.Transaction_capacity.to_yojson (to_json_layout x)

    let of_yojson json =
      Result.bind ~f:of_json_layout
        (Json_layout.Proof_keys.Transaction_capacity.of_yojson json)
  end

  type t =
    { level: Level.t option
    ; c: int option
    ; ledger_depth: int option
    ; work_delay: int option
    ; block_window_duration_ms: int option
    ; transaction_capacity: Transaction_capacity.t option
    ; coinbase_amount: Currency.Amount.Stable.Latest.t option
    ; account_creation_fee: Currency.Fee.Stable.Latest.t option }
  [@@deriving bin_io_unversioned]

  let to_json_layout
      { level
      ; c
      ; ledger_depth
      ; work_delay
      ; block_window_duration_ms
      ; transaction_capacity
      ; coinbase_amount
      ; account_creation_fee } =
    { Json_layout.Proof_keys.level= Option.map ~f:Level.to_json_layout level
    ; c
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity=
        Option.map ~f:Transaction_capacity.to_json_layout transaction_capacity
    ; coinbase_amount
    ; account_creation_fee }

  let of_json_layout
      { Json_layout.Proof_keys.level
      ; c
      ; ledger_depth
      ; work_delay
      ; block_window_duration_ms
      ; transaction_capacity
      ; coinbase_amount
      ; account_creation_fee } =
    let open Result.Let_syntax in
    let%map level = result_opt ~f:Level.of_json_layout level
    and transaction_capacity =
      result_opt ~f:Transaction_capacity.of_json_layout transaction_capacity
    in
    { level
    ; c
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity
    ; coinbase_amount
    ; account_creation_fee }

  let to_yojson x = Json_layout.Proof_keys.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Proof_keys.of_yojson json)

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
  type t = Json_layout.Genesis.t =
    {k: int option; delta: int option; genesis_state_timestamp: string option}
  [@@deriving bin_io_unversioned]

  let to_json_layout : t -> Json_layout.Genesis.t = Fn.id

  let of_json_layout : Json_layout.Genesis.t -> (t, string) Result.t =
    Result.return

  let to_yojson x = Json_layout.Genesis.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Genesis.of_yojson json)

  let combine t1 t2 =
    { k= opt_fallthrough ~default:t1.k t2.k
    ; delta= opt_fallthrough ~default:t1.delta t2.delta
    ; genesis_state_timestamp=
        opt_fallthrough ~default:t1.genesis_state_timestamp
          t2.genesis_state_timestamp }
end

module Daemon = struct
  type t = Json_layout.Daemon.t = {txpool_max_size: int option}
  [@@deriving bin_io_unversioned]

  let to_json_layout : t -> Json_layout.Daemon.t = Fn.id

  let of_json_layout : Json_layout.Daemon.t -> (t, string) Result.t =
    Result.return

  let to_yojson x = Json_layout.Daemon.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Daemon.of_yojson json)

  let combine t1 t2 =
    { txpool_max_size=
        opt_fallthrough ~default:t1.txpool_max_size t2.txpool_max_size }
end

type t =
  { daemon: Daemon.t option
  ; genesis: Genesis.t option
  ; proof: Proof_keys.t option
  ; ledger: Ledger.t option }
[@@deriving bin_io_unversioned]

let to_json_layout {daemon; genesis; proof; ledger} =
  { Json_layout.daemon= Option.map ~f:Daemon.to_json_layout daemon
  ; genesis= Option.map ~f:Genesis.to_json_layout genesis
  ; proof= Option.map ~f:Proof_keys.to_json_layout proof
  ; ledger= Option.map ~f:Ledger.to_json_layout ledger }

let of_json_layout {Json_layout.daemon; genesis; proof; ledger} =
  let open Result.Let_syntax in
  let%map daemon = result_opt ~f:Daemon.of_json_layout daemon
  and genesis = result_opt ~f:Genesis.of_json_layout genesis
  and proof = result_opt ~f:Proof_keys.of_json_layout proof
  and ledger = result_opt ~f:Ledger.of_json_layout ledger in
  {daemon; genesis; proof; ledger}

let to_yojson x = Json_layout.to_yojson (to_json_layout x)

let of_yojson json = Result.bind ~f:of_json_layout (Json_layout.of_yojson json)

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
