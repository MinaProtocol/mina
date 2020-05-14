open Core_kernel

let yojson_strip_fields ~fields = function
  | `Assoc l ->
      `Assoc
        (List.filter l ~f:(fun (fld, _) ->
             Array.mem ~equal:String.equal fields fld ))
  | json ->
      json

let opt_fallthrough ~default x2 =
  Option.value_map ~default x2 ~f:(fun x -> Some x)

module Accounts = struct
  type single =
    { pk: string option [@default None]
    ; sk: string option [@default None]
    ; balance: Unsigned_extended.UInt64.t
    ; delegate: string option [@default None] }
  [@@deriving yojson]

  let single_of_yojson json =
    single_of_yojson
    @@ yojson_strip_fields ~fields:[|"pk"; "sk"; "balance"; "delegate"|] json

  type t = single list [@@deriving yojson]
end

module Ledger = struct
  type base =
    | Named of string  (** One of the named ledgers in [Genesis_ledger] *)
    | Accounts of Accounts.t  (** A ledger generated from the given accounts *)
    | Hash of string  (** The ledger with the given root hash *)

  type t = {base: base; num_accounts: int option; hash: string option}

  let base_to_yojson_field = function
    | Named name ->
        ("named", `String name)
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
            if String.equal fld "name" then
              match value with
              | `String name ->
                  Some (Ok (Named name))
              | _ ->
                  Some
                    (Error
                       "Runtime_config.Ledger.of_yojson: Expected the field \
                        'name' to contain a string")
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

  let to_yojson {base; num_accounts; hash} =
    let fields =
      List.filter_opt
        [ Option.map num_accounts ~f:(fun i -> ("num_accounts", `Int i))
        ; Option.bind hash ~f:(fun hash ->
              match base with
              | Hash _ ->
                  None
              | _ ->
                  Some ("hash", `String hash) ) ]
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
        {base; num_accounts; hash}
    | _ ->
        Error "Runtime_config.Ledger.of_yojson: Expected a JSON object"
end

module Proof_keys = struct
  type t = unit

  let to_yojson () = `Assoc []

  let of_yojson = function
    | `Assoc _ ->
        Ok ()
    | _ ->
        Error "Runtime_config.Proof_keys.of_yojson: Expected a JSON object"

  let combine () () = ()
end

module Genesis = struct
  type t = {k: int option [@default None]; delta: int option [@default None]}
  [@@deriving yojson]

  let of_yojson json =
    of_yojson @@ yojson_strip_fields ~fields:[|"k"; "delta"|] json

  let combine t1 t2 =
    { k= opt_fallthrough ~default:t1.k t2.k
    ; delta= opt_fallthrough ~default:t1.delta t2.delta }
end

module Daemon = struct
  type t =
    { txpool_max_size: int option [@default None]
    ; genesis_state_timestamp: string option [@default None] }
  [@@deriving yojson]

  let of_yojson json =
    of_yojson
    @@ yojson_strip_fields
         ~fields:[|"txpool_max_size"; "genesis_state_timestamp"|]
         json

  let combine t1 t2 =
    { txpool_max_size=
        opt_fallthrough ~default:t1.txpool_max_size t2.txpool_max_size
    ; genesis_state_timestamp=
        opt_fallthrough ~default:t1.genesis_state_timestamp
          t2.genesis_state_timestamp }
end

(** JSON representation:

  { "daemon":
      { "txpool_max_size": 1
      , "genesis_state_timestamp": "2000-00-00 12:00:00+0100" }
  , "genesis": { "k": 1, "delta": 1 }
  , "proof": { }
  , "ledger":
      { "name": "release"
      , "accounts":
          [ { pk: "public_key"
            , sk: "secret_key"
            , balance: 50
            , delegate: "public_key" }
          , { pk: "public_key"
            , sk: "secret_key"
            , balance: 0
            , delegate: "public_key" } ]
      , "hash": "root_hash"
      , "num_accounts": 10 } }

  All fields are optional *except*:
  * each account in [ledger.accounts] must have a [balance] field
  * if [ledger] is present, it must feature one of [name], [accounts] or [hash].

*)

type t =
  { daemon: Daemon.t option [@default None]
  ; genesis: Genesis.t option [@default None]
  ; proof: Proof_keys.t option [@default None]
  ; ledger: Ledger.t option [@default None] }
[@@deriving yojson]

let fields = [|"ledger"; "genesis_constants"; "proof_constants"|]

let of_yojson json = of_yojson @@ yojson_strip_fields ~fields json

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
