open Core_kernel

module Fork_config = struct
  (* Note that previous_length might be smaller than the gernesis_slot
     or equal if a block was produced in every slot possible. *)
  type t =
    { previous_state_hash : string
    ; previous_length : int (* number of blocks produced since genesis *)
    ; previous_global_slot : int (* global slot since genesis *)
    }
  [@@deriving yojson, bin_io_unversioned]

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind previous_global_slot = Int.gen_incl 0 1_000_000 in
    let%bind previous_length = Int.gen_incl 0 previous_global_slot in
    let%map state_hash = Mina_base.State_hash.gen in
    let previous_state_hash = Mina_base.State_hash.to_base58_check state_hash in
    { previous_state_hash; previous_length; previous_global_slot }
end

let yojson_strip_fields ~keep_fields = function
  | `Assoc l ->
      `Assoc
        (List.filter l ~f:(fun (fld, _) ->
             Array.mem ~equal:String.equal keep_fields fld ) )
  | json ->
      json

let yojson_rename_fields ~alternates = function
  | `Assoc l ->
      `Assoc
        (List.map l ~f:(fun (fld, json) ->
             let fld =
               Option.value ~default:fld
                 (Array.find_map alternates ~f:(fun (alt, orig) ->
                      if String.equal fld alt then Some orig else None ) )
             in
             (fld, json) ) )
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

let dump_on_error yojson x =
  Result.map_error x ~f:(fun str ->
      str ^ "\n\nCould not parse JSON:\n" ^ Yojson.Safe.pretty_to_string yojson )

let of_yojson_generic ~fields of_yojson json =
  dump_on_error json @@ of_yojson
  @@ yojson_strip_fields ~keep_fields:fields json

let map_results ls ~f =
  let open Result.Let_syntax in
  let%map r =
    List.fold_result ls ~init:[] ~f:(fun t el ->
        let%map h = f el in
        h :: t )
  in
  List.rev r

module Json_layout = struct
  module Accounts = struct
    module Single = struct
      module Timed = struct
        type t =
          { initial_minimum_balance : Currency.Balance.t
          ; cliff_time : Mina_numbers.Global_slot_since_genesis.t
          ; cliff_amount : Currency.Amount.t
          ; vesting_period : Mina_numbers.Global_slot_span.t
          ; vesting_increment : Currency.Amount.t
          }
        [@@deriving yojson, fields, sexp]

        let fields = Fields.names |> Array.of_list

        let of_yojson json = of_yojson_generic ~fields of_yojson json
      end

      module Permissions = struct
        module Auth_required = struct
          type t = None | Either | Proof | Signature | Impossible
          [@@deriving sexp, bin_io_unversioned]

          let to_yojson = function
            | None ->
                `String "none"
            | Either ->
                `String "either"
            | Proof ->
                `String "proof"
            | Signature ->
                `String "signature"
            | Impossible ->
                `String "impossible"

          let of_yojson = function
            | `String s -> (
                match String.lowercase s with
                | "none" ->
                    Ok None
                | "either" ->
                    Ok Either
                | "proof" ->
                    Ok Proof
                | "signature" ->
                    Ok Signature
                | "impossible" ->
                    Ok Impossible
                | _ ->
                    Error (sprintf "Invalid Auth_required.t value: %s" s) )
            | _ ->
                Error
                  "Runtime_config.Json_Account.Single.Permissions.Auth_Required.t"

          let of_account_perm = function
            | Mina_base.Permissions.Auth_required.None ->
                None
            | Either ->
                Either
            | Proof ->
                Proof
            | Signature ->
                Signature
            | Impossible ->
                Impossible

          let to_account_perm = function
            | None ->
                Mina_base.Permissions.Auth_required.None
            | Either ->
                Either
            | Proof ->
                Proof
            | Signature ->
                Signature
            | Impossible ->
                Impossible
        end

        type t =
          { edit_state : Auth_required.t [@default None]
          ; send : Auth_required.t [@default None]
          ; receive : Auth_required.t [@default None]
          ; access : Auth_required.t [@default None]
          ; set_delegate : Auth_required.t [@default None]
          ; set_permissions : Auth_required.t [@default None]
          ; set_verification_key : Auth_required.t [@default None]
          ; set_zkapp_uri : Auth_required.t [@default None]
          ; edit_action_state : Auth_required.t [@default None]
          ; set_token_symbol : Auth_required.t [@default None]
          ; increment_nonce : Auth_required.t [@default None]
          ; set_voting_for : Auth_required.t [@default None]
          ; set_timing : Auth_required.t [@default None]
          }
        [@@deriving yojson, fields, sexp, bin_io_unversioned]

        let fields = Fields.names |> Array.of_list

        let of_yojson json = of_yojson_generic ~fields of_yojson json
      end

      module Zkapp_account = struct
        module Field = struct
          type t = Snark_params.Tick.Field.t
          [@@deriving sexp, bin_io_unversioned]

          let to_yojson t = `String (Snark_params.Tick.Field.to_string t)

          let of_yojson = function
            | `String s ->
                Ok (Snark_params.Tick.Field.of_string s)
            | _ ->
                Error
                  "Invalid JSON in runtime config Zkapp_account.state, \
                   expected string"
        end

        module Verification_key = struct
          type t = Pickles.Side_loaded.Verification_key.Stable.Latest.t
          [@@deriving sexp, bin_io_unversioned]

          let to_yojson t =
            `String (Pickles.Side_loaded.Verification_key.to_base64 t)

          let of_yojson = function
            | `String s ->
                let vk_or_err =
                  Pickles.Side_loaded.Verification_key.of_base64 s
                in
                Result.map_error vk_or_err ~f:Error.to_string_hum
            | _ ->
                Error
                  "Invalid JSON in runtime config \
                   Zkapp_account.verification_key, expected string"
        end

        module Zkapp_version = struct
          type t = Mina_numbers.Zkapp_version.Stable.Latest.t
          [@@deriving bin_io_unversioned]

          include (
            Mina_numbers.Zkapp_version :
              module type of Mina_numbers.Zkapp_version with type t := t )
        end

        type t =
          { app_state : Field.t list
          ; verification_key : Verification_key.t option [@default None]
          ; zkapp_version : Zkapp_version.t
          ; action_state : Field.t list
          ; last_action_slot : int
          ; proved_state : bool
          ; zkapp_uri : string
          }
        [@@deriving sexp, fields, yojson, bin_io_unversioned]

        let fields = Fields.names |> Array.of_list

        let of_yojson json = of_yojson_generic ~fields of_yojson json
      end

      type t =
        { pk : string
        ; sk : string option [@default None]
        ; balance : Currency.Balance.t
        ; delegate : string option [@default None]
        ; timing : Timed.t option [@default None]
        ; token : string option [@default None]
        ; nonce : Mina_numbers.Account_nonce.t
              [@default Mina_numbers.Account_nonce.zero]
        ; receipt_chain_hash : string option [@default None]
        ; voting_for : string option [@default None]
        ; zkapp : Zkapp_account.t option [@default None]
        ; permissions : Permissions.t option [@default None]
        ; token_symbol : string option [@default None]
        }
      [@@deriving sexp, fields, yojson]

      let fields = Fields.names |> Array.of_list

      let of_yojson json = of_yojson_generic ~fields of_yojson json

      let default : t =
        { pk = Signature_lib.Public_key.Compressed.(to_base58_check empty)
        ; sk = None
        ; balance = Currency.Balance.zero
        ; delegate = None
        ; timing = None
        ; token = None
        ; nonce = Mina_numbers.Account_nonce.zero
        ; receipt_chain_hash = None
        ; voting_for = None
        ; zkapp = None
        ; permissions = None
        ; token_symbol = None
        }
    end

    type t = Single.t list [@@deriving yojson]
  end

  module Ledger = struct
    module Balance_spec = struct
      type t = { number : int; balance : Currency.Balance.t }
      [@@deriving yojson]
    end

    type t =
      { accounts : Accounts.t option [@default None]
      ; num_accounts : int option [@default None]
      ; balances : Balance_spec.t list [@default []]
      ; hash : string option [@default None]
      ; name : string option [@default None]
      ; add_genesis_winner : bool option [@default None]
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json
  end

  module Proof_keys = struct
    module Transaction_capacity = struct
      type t =
        { log_2 : int option [@default None] [@key "2_to_the"]
        ; txns_per_second_x10 : int option [@default None]
        }
      [@@deriving yojson]

      (* we don't deriving the field names here, because the first one differs from the
         field in the record type
      *)
      let fields = [| "2_to_the"; "txns_per_second_x10" |]

      let alternates = [| ("two_to_the", "2_to_the"); ("log_2", "2_to_the") |]

      let of_yojson json =
        json
        |> yojson_rename_fields ~alternates
        |> yojson_strip_fields ~keep_fields:fields
        |> of_yojson |> dump_on_error json
    end

    type t =
      { level : string option [@default None]
      ; sub_windows_per_window : int option [@default None]
      ; ledger_depth : int option [@default None]
      ; work_delay : int option [@default None]
      ; block_window_duration_ms : int option [@default None]
      ; transaction_capacity : Transaction_capacity.t option [@default None]
      ; coinbase_amount : Currency.Amount.t option [@default None]
      ; supercharged_coinbase_factor : int option [@default None]
      ; account_creation_fee : Currency.Fee.t option [@default None]
      ; fork : Fork_config.t option [@default None]
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json
  end

  module Genesis = struct
    type t =
      { k : int option [@default None]
      ; delta : int option [@default None]
      ; slots_per_epoch : int option [@default None]
      ; slots_per_sub_window : int option [@default None]
      ; grace_period_slots : int option [@default None]
      ; genesis_state_timestamp : string option [@default None]
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json
  end

  module Daemon = struct
    type t =
      { txpool_max_size : int option [@default None]
      ; peer_list_url : string option [@default None]
      ; zkapp_proof_update_cost : float option [@default None]
      ; zkapp_signed_single_update_cost : float option [@default None]
      ; zkapp_signed_pair_update_cost : float option [@default None]
      ; zkapp_transaction_cost_limit : float option [@default None]
      ; max_event_elements : int option [@default None]
      ; max_action_elements : int option [@default None]
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json
  end

  module Epoch_data = struct
    module Data = struct
      type t =
        { accounts : Accounts.t option [@default None]
        ; seed : string
        ; hash : string option [@default None]
        }
      [@@deriving yojson, fields]

      let fields = Fields.names |> Array.of_list

      let of_yojson json = of_yojson_generic ~fields of_yojson json
    end

    type t =
      { staking : Data.t
      ; next : (Data.t option[@default None]) (*If None then next = staking*)
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json
  end

  type t =
    { daemon : Daemon.t option [@default None]
    ; genesis : Genesis.t option [@default None]
    ; proof : Proof_keys.t option [@default None]
    ; ledger : Ledger.t option [@default None]
    ; epoch_data : Epoch_data.t option [@default None]
    }
  [@@deriving yojson, fields]

  let fields = Fields.names |> Array.of_list

  let of_yojson json = of_yojson_generic ~fields of_yojson json
end

(** JSON representation:

  { "daemon":
      { "txpool_max_size": 1
      , "peer_list_url": "https://www.example.com/peer-list.txt" }
  , "genesis": { "k": 1, "delta": 1 }
  , "proof":
      { "level": "check"
      , "sub_windows_per_window": 8
      , "ledger_depth": 14
      , "work_delay": 2
      , "block_window_duration_ms": 120000
      , "transaction_capacity": {"txns_per_second_x10": 2}
      , "coinbase_amount": "200"
      , "supercharged_coinbase_factor": 2
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
    module Timed = struct
      type t = Json_layout.Accounts.Single.Timed.t =
        { initial_minimum_balance : Currency.Balance.Stable.Latest.t
        ; cliff_time : Mina_numbers.Global_slot_since_genesis.Stable.Latest.t
        ; cliff_amount : Currency.Amount.Stable.Latest.t
        ; vesting_period : Mina_numbers.Global_slot_span.Stable.Latest.t
        ; vesting_increment : Currency.Amount.Stable.Latest.t
        }
      [@@deriving bin_io_unversioned, sexp]
    end

    module Permissions = Json_layout.Accounts.Single.Permissions
    module Zkapp_account = Json_layout.Accounts.Single.Zkapp_account

    type t = Json_layout.Accounts.Single.t =
      { pk : string
      ; sk : string option
      ; balance : Currency.Balance.Stable.Latest.t
      ; delegate : string option
      ; timing : Timed.t option
      ; token : string option
      ; nonce : Mina_numbers.Account_nonce.Stable.Latest.t
      ; receipt_chain_hash : string option
      ; voting_for : string option
      ; zkapp : Zkapp_account.t option
      ; permissions : Permissions.t option
      ; token_symbol : string option
      }
    [@@deriving bin_io_unversioned, sexp]

    let to_json_layout : t -> Json_layout.Accounts.Single.t = Fn.id

    let of_json_layout : Json_layout.Accounts.Single.t -> (t, string) Result.t =
      Result.return

    let to_yojson x = Json_layout.Accounts.Single.to_yojson (to_json_layout x)

    let of_yojson json =
      Result.bind ~f:of_json_layout (Json_layout.Accounts.Single.of_yojson json)

    let default = Json_layout.Accounts.Single.default

    let of_account (a : Mina_base.Account.t) : (t, string) Result.t =
      let open Result.Let_syntax in
      let open Signature_lib in
      return
        { pk = Public_key.Compressed.to_base58_check a.public_key
        ; sk = None
        ; balance = a.balance
        ; delegate =
            Option.map a.delegate ~f:(fun pk ->
                Public_key.Compressed.to_base58_check pk )
        ; timing =
            ( match a.timing with
            | Untimed ->
                None
            | Timed t ->
                let open Timed in
                Some
                  { initial_minimum_balance = t.initial_minimum_balance
                  ; cliff_time = t.cliff_time
                  ; cliff_amount = t.cliff_amount
                  ; vesting_period = t.vesting_period
                  ; vesting_increment = t.vesting_increment
                  } )
        ; token = Some (Mina_base.Token_id.to_string a.token_id)
        ; token_symbol = Some a.token_symbol
        ; zkapp =
            Option.map a.zkapp ~f:(fun zkapp ->
                let open Zkapp_account in
                { app_state = Mina_base.Zkapp_state.V.to_list zkapp.app_state
                ; verification_key =
                    Option.map zkapp.verification_key ~f:With_hash.data
                ; zkapp_version = zkapp.zkapp_version
                ; action_state =
                    Pickles_types.Vector.Vector_5.to_list zkapp.action_state
                ; last_action_slot =
                    Unsigned.UInt32.to_int
                    @@ Mina_numbers.Global_slot_since_genesis.to_uint32
                         zkapp.last_action_slot
                ; proved_state = zkapp.proved_state
                ; zkapp_uri = zkapp.zkapp_uri
                } )
        ; nonce = a.nonce
        ; receipt_chain_hash =
            Some
              (Mina_base.Receipt.Chain_hash.to_base58_check a.receipt_chain_hash)
        ; voting_for = Some (Mina_base.State_hash.to_base58_check a.voting_for)
        ; permissions =
            Some
              Permissions.
                { edit_state =
                    Auth_required.of_account_perm a.permissions.edit_state
                ; send = Auth_required.of_account_perm a.permissions.send
                ; receive = Auth_required.of_account_perm a.permissions.receive
                ; set_delegate =
                    Auth_required.of_account_perm a.permissions.set_delegate
                ; set_permissions =
                    Auth_required.of_account_perm a.permissions.set_permissions
                ; set_verification_key =
                    Auth_required.of_account_perm
                      a.permissions.set_verification_key
                ; set_token_symbol =
                    Auth_required.of_account_perm a.permissions.set_token_symbol
                ; access = Auth_required.of_account_perm a.permissions.access
                ; edit_action_state =
                    Auth_required.of_account_perm
                      a.permissions.edit_action_state
                ; set_zkapp_uri =
                    Auth_required.of_account_perm a.permissions.set_zkapp_uri
                ; increment_nonce =
                    Auth_required.of_account_perm a.permissions.increment_nonce
                ; set_timing =
                    Auth_required.of_account_perm a.permissions.set_timing
                ; set_voting_for =
                    Auth_required.of_account_perm a.permissions.set_voting_for
                }
        }

    let to_account (a : t) : Mina_base.Account.t =
      let open Signature_lib in
      let open Mina_base.Account.Poly.Stable.V2 in
      let timing =
        let open Mina_base.Account_timing.Poly.Stable.V2 in
        match a.timing with
        | None ->
            Untimed
        | Some
            { initial_minimum_balance
            ; cliff_time
            ; cliff_amount
            ; vesting_period
            ; vesting_increment
            } ->
            Timed
              { initial_minimum_balance
              ; cliff_time
              ; cliff_amount
              ; vesting_period
              ; vesting_increment
              }
      in
      let permissions =
        let perms = Option.value_exn a.permissions in
        Mina_base.Permissions.Poly.Stable.V2.
          { edit_state =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.edit_state
          ; access =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.access
          ; send =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.send
          ; receive =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.receive
          ; set_delegate =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_delegate
          ; set_permissions =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_permissions
          ; set_verification_key =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_verification_key
          ; set_zkapp_uri =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_zkapp_uri
          ; edit_action_state =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.edit_action_state
          ; set_token_symbol =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_token_symbol
          ; increment_nonce =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.increment_nonce
          ; set_voting_for =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_voting_for
          ; set_timing =
              Json_layout.Accounts.Single.Permissions.Auth_required
              .to_account_perm perms.set_timing
          }
      in
      let mk_zkapp (app : Zkapp_account.t) :
          ( Mina_base__.Zkapp_state.Value.Stable.V1.t
          , Mina_base__.Verification_key_wire.Stable.V1.t option
          , Zkapp_account.Zkapp_version.t
          , Zkapp_account.Field.t
          , Mina_wire_types.Mina_numbers.Global_slot_since_genesis.V1.t
          , bool
          , string )
          Mina_base.Zkapp_account.Poly.Stable.V2.t =
        let hash_data = Mina_base.Verification_key_wire.digest_vk in
        Zkapp_account.
          { app_state = Mina_base.Zkapp_state.V.of_list_exn app.app_state
          ; verification_key =
              Option.map ~f:With_hash.(of_data ~hash_data) app.verification_key
          ; zkapp_version = app.zkapp_version
          ; action_state =
              Pickles_types.Vector.Vector_5.of_list_exn app.action_state
          ; last_action_slot =
              Mina_numbers.Global_slot_since_genesis.of_uint32
              @@ Unsigned.UInt32.of_int app.last_action_slot
          ; proved_state = app.proved_state
          ; zkapp_uri = app.zkapp_uri
          }
      in
      { public_key = Public_key.Compressed.of_base58_check_exn a.pk
      ; token_id =
          Mina_base.Token_id.(Option.value_map ~default ~f:of_string a.token)
      ; token_symbol = Option.value ~default:"" a.token_symbol
      ; balance = a.balance
      ; nonce = a.nonce
      ; receipt_chain_hash =
          Mina_base.Receipt.Chain_hash.of_base58_check_exn
            (Option.value_exn a.receipt_chain_hash)
      ; delegate =
          Option.map ~f:Public_key.Compressed.of_base58_check_exn a.delegate
      ; voting_for =
          Mina_base.State_hash.of_base58_check_exn
            (Option.value_exn a.voting_for)
      ; timing
      ; permissions
      ; zkapp = Option.map ~f:mk_zkapp a.zkapp
      }

    let gen =
      Quickcheck.Generator.map Mina_base.Account.gen ~f:(fun a ->
          (* This will never fail with a proper account generator. *)
          of_account a |> Result.ok_or_failwith )
  end

  type single = Single.t =
    { pk : string
    ; sk : string option
    ; balance : Currency.Balance.t
    ; delegate : string option
    ; timing : Single.Timed.t option
    ; token : string option
    ; nonce : Mina_numbers.Account_nonce.t
    ; receipt_chain_hash : string option
    ; voting_for : string option
    ; zkapp : Single.Zkapp_account.t option
    ; permissions : Single.Permissions.t option
    ; token_symbol : string option
    }

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
    { base : base
    ; num_accounts : int option
    ; balances : (int * Currency.Balance.Stable.Latest.t) list
    ; hash : string option
    ; name : string option
    ; add_genesis_winner : bool option
    }
  [@@deriving bin_io_unversioned]

  let to_json_layout
      { base; num_accounts; balances; hash; name; add_genesis_winner } :
      Json_layout.Ledger.t =
    let balances =
      List.map balances ~f:(fun (number, balance) ->
          { Json_layout.Ledger.Balance_spec.number; balance } )
    in
    let without_base : Json_layout.Ledger.t =
      { accounts = None
      ; num_accounts
      ; balances
      ; hash
      ; name
      ; add_genesis_winner
      }
    in
    match base with
    | Named name ->
        { without_base with name = Some name }
    | Accounts accounts ->
        { without_base with accounts = Some (Accounts.to_json_layout accounts) }
    | Hash hash ->
        { without_base with hash = Some hash }

  let of_json_layout
      ({ accounts; num_accounts; balances; hash; name; add_genesis_winner } :
        Json_layout.Ledger.t ) : (t, string) Result.t =
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
    let balances =
      List.map balances
        ~f:(fun { Json_layout.Ledger.Balance_spec.number; balance } ->
          (number, balance) )
    in
    { base; num_accounts; balances; hash; name; add_genesis_winner }

  let to_yojson x = Json_layout.Ledger.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Ledger.of_yojson json)

  let gen =
    let open Quickcheck in
    let open Generator.Let_syntax in
    let%bind accounts = Generator.list Accounts.Single.gen in
    let num_accounts = List.length accounts in
    let balances =
      List.mapi accounts ~f:(fun number a -> (number, a.balance))
    in
    let%bind hash =
      Mina_base.Ledger_hash.(Generator.map ~f:to_base58_check gen)
      |> Option.quickcheck_generator
    in
    let%bind name = String.gen_nonempty in
    let%map add_genesis_winner = Bool.quickcheck_generator in
    { base = Accounts accounts
    ; num_accounts = Some num_accounts
    ; balances
    ; hash
    ; name = Some name
    ; add_genesis_winner = Some add_genesis_winner
    }
end

module Proof_keys = struct
  module Level = struct
    type t = Full | Check | None [@@deriving bin_io_unversioned, equal]

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

    let gen = Quickcheck.Generator.of_list [ Full; Check; None ]
  end

  module Transaction_capacity = struct
    type t = Log_2 of int | Txns_per_second_x10 of int
    [@@deriving bin_io_unversioned]

    let to_json_layout : t -> Json_layout.Proof_keys.Transaction_capacity.t =
      function
      | Log_2 i ->
          { log_2 = Some i; txns_per_second_x10 = None }
      | Txns_per_second_x10 i ->
          { log_2 = None; txns_per_second_x10 = Some i }

    let of_json_layout :
        Json_layout.Proof_keys.Transaction_capacity.t -> (t, string) Result.t =
      function
      | { log_2 = Some i; txns_per_second_x10 = None } ->
          Ok (Log_2 i)
      | { txns_per_second_x10 = Some i; log_2 = None } ->
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

    let gen =
      let open Quickcheck in
      let log_2_gen =
        Generator.map ~f:(fun i -> Log_2 i) @@ Int.gen_incl 0 10
      in
      let txns_per_second_x10_gen =
        Generator.map ~f:(fun i -> Txns_per_second_x10 i) @@ Int.gen_incl 0 1000
      in
      Generator.union [ log_2_gen; txns_per_second_x10_gen ]

    let small : t = Log_2 2

    let medium : t = Log_2 3
  end

  type t =
    { level : Level.t option
    ; sub_windows_per_window : int option
    ; ledger_depth : int option
    ; work_delay : int option
    ; block_window_duration_ms : int option
    ; transaction_capacity : Transaction_capacity.t option
    ; coinbase_amount : Currency.Amount.Stable.Latest.t option
    ; supercharged_coinbase_factor : int option
    ; account_creation_fee : Currency.Fee.Stable.Latest.t option
    ; fork : Fork_config.t option
    }
  [@@deriving bin_io_unversioned]

  let make ?level ?sub_windows_per_window ?ledger_depth ?work_delay
      ?block_window_duration_ms ?transaction_capacity ?coinbase_amount
      ?supercharged_coinbase_factor ?account_creation_fee ?fork () =
    { level
    ; sub_windows_per_window
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity
    ; coinbase_amount
    ; supercharged_coinbase_factor
    ; account_creation_fee
    ; fork
    }

  let to_json_layout
      { level
      ; sub_windows_per_window
      ; ledger_depth
      ; work_delay
      ; block_window_duration_ms
      ; transaction_capacity
      ; coinbase_amount
      ; supercharged_coinbase_factor
      ; account_creation_fee
      ; fork
      } =
    { Json_layout.Proof_keys.level = Option.map ~f:Level.to_json_layout level
    ; sub_windows_per_window
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity =
        Option.map ~f:Transaction_capacity.to_json_layout transaction_capacity
    ; coinbase_amount
    ; supercharged_coinbase_factor
    ; account_creation_fee
    ; fork
    }

  let of_json_layout
      { Json_layout.Proof_keys.level
      ; sub_windows_per_window
      ; ledger_depth
      ; work_delay
      ; block_window_duration_ms
      ; transaction_capacity
      ; coinbase_amount
      ; supercharged_coinbase_factor
      ; account_creation_fee
      ; fork
      } =
    let open Result.Let_syntax in
    let%map level = result_opt ~f:Level.of_json_layout level
    and transaction_capacity =
      result_opt ~f:Transaction_capacity.of_json_layout transaction_capacity
    in
    { level
    ; sub_windows_per_window
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity
    ; coinbase_amount
    ; supercharged_coinbase_factor
    ; account_creation_fee
    ; fork
    }

  let to_yojson x = Json_layout.Proof_keys.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Proof_keys.of_yojson json)

  let combine t1 t2 =
    { level = opt_fallthrough ~default:t1.level t2.level
    ; sub_windows_per_window =
        opt_fallthrough ~default:t1.sub_windows_per_window
          t2.sub_windows_per_window
    ; ledger_depth = opt_fallthrough ~default:t1.ledger_depth t2.ledger_depth
    ; work_delay = opt_fallthrough ~default:t1.work_delay t2.work_delay
    ; block_window_duration_ms =
        opt_fallthrough ~default:t1.block_window_duration_ms
          t2.block_window_duration_ms
    ; transaction_capacity =
        opt_fallthrough ~default:t1.transaction_capacity t2.transaction_capacity
    ; coinbase_amount =
        opt_fallthrough ~default:t1.coinbase_amount t2.coinbase_amount
    ; supercharged_coinbase_factor =
        opt_fallthrough ~default:t1.supercharged_coinbase_factor
          t2.supercharged_coinbase_factor
    ; account_creation_fee =
        opt_fallthrough ~default:t1.account_creation_fee t2.account_creation_fee
    ; fork = opt_fallthrough ~default:t1.fork t2.fork
    }

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind level = Level.gen in
    let%bind sub_windows_per_window = Int.gen_incl 0 1000 in
    let%bind ledger_depth = Int.gen_incl 0 64 in
    let%bind work_delay = Int.gen_incl 0 1000 in
    let%bind block_window_duration_ms = Int.gen_incl 1_000 360_000 in
    let%bind transaction_capacity = Transaction_capacity.gen in
    let%bind coinbase_amount =
      Currency.Amount.(gen_incl zero (of_mina_int_exn 1))
    in
    let%bind supercharged_coinbase_factor = Int.gen_incl 0 100 in
    let%bind account_creation_fee =
      Currency.Fee.(gen_incl one (of_mina_int_exn 10))
    in
    let%map fork =
      let open Quickcheck.Generator in
      union [ map ~f:Option.some Fork_config.gen; return None ]
    in
    { level = Some level
    ; sub_windows_per_window = Some sub_windows_per_window
    ; ledger_depth = Some ledger_depth
    ; work_delay = Some work_delay
    ; block_window_duration_ms = Some block_window_duration_ms
    ; transaction_capacity = Some transaction_capacity
    ; coinbase_amount = Some coinbase_amount
    ; supercharged_coinbase_factor = Some supercharged_coinbase_factor
    ; account_creation_fee = Some account_creation_fee
    ; fork
    }
end

module Genesis = struct
  type t = Json_layout.Genesis.t =
    { k : int option (* the depth of finality constant (in slots) *)
    ; delta : int option (* max permissible delay of packets (in slots) *)
    ; slots_per_epoch : int option
    ; slots_per_sub_window : int option
    ; grace_period_slots : int option
    ; genesis_state_timestamp : string option
    }
  [@@deriving bin_io_unversioned]

  let to_json_layout : t -> Json_layout.Genesis.t = Fn.id

  let of_json_layout : Json_layout.Genesis.t -> (t, string) Result.t =
    Result.return

  let to_yojson x = Json_layout.Genesis.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Genesis.of_yojson json)

  let combine t1 t2 =
    { k = opt_fallthrough ~default:t1.k t2.k
    ; delta = opt_fallthrough ~default:t1.delta t2.delta
    ; slots_per_epoch =
        opt_fallthrough ~default:t1.slots_per_epoch t2.slots_per_epoch
    ; slots_per_sub_window =
        opt_fallthrough ~default:t1.slots_per_sub_window t2.slots_per_sub_window
    ; grace_period_slots =
        opt_fallthrough ~default:t1.grace_period_slots t2.grace_period_slots
    ; genesis_state_timestamp =
        opt_fallthrough ~default:t1.genesis_state_timestamp
          t2.genesis_state_timestamp
    }

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind k = Int.gen_incl 0 1000 in
    let%bind delta = Int.gen_incl 0 1000 in
    let%bind slots_per_epoch = Int.gen_incl 1 1_000_000 in
    let%bind slots_per_sub_window = Int.gen_incl 1 1_000 in
    let%bind grace_period_slots =
      Quickcheck.Generator.union
        [ return None
        ; Quickcheck.Generator.map ~f:Option.some @@ Int.gen_incl 0 1000
        ]
    in
    let%map genesis_state_timestamp =
      Time.(gen_incl epoch (of_string "2050-01-01 00:00:00Z"))
      |> Quickcheck.Generator.map ~f:Time.to_string
    in
    { k = Some k
    ; delta = Some delta
    ; slots_per_epoch = Some slots_per_epoch
    ; slots_per_sub_window = Some slots_per_sub_window
    ; grace_period_slots
    ; genesis_state_timestamp = Some genesis_state_timestamp
    }
end

module Daemon = struct
  (* Peer list URL should usually be None. This option is better provided with
     a command line argument. Putting it in the config makes the network explicitly
     rely on a certain number of nodes, reducing decentralisation. See #14766 *)
  type t = Json_layout.Daemon.t =
    { txpool_max_size : int option
    ; peer_list_url : string option
    ; zkapp_proof_update_cost : float option [@default None]
    ; zkapp_signed_single_update_cost : float option [@default None]
    ; zkapp_signed_pair_update_cost : float option [@default None]
    ; zkapp_transaction_cost_limit : float option [@default None]
    ; max_event_elements : int option [@default None]
    ; max_action_elements : int option [@default None]
    }
  [@@deriving bin_io_unversioned]

  let to_json_layout : t -> Json_layout.Daemon.t = Fn.id

  let of_json_layout : Json_layout.Daemon.t -> (t, string) Result.t =
    Result.return

  let to_yojson x = Json_layout.Daemon.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Daemon.of_yojson json)

  let combine t1 t2 =
    { txpool_max_size =
        opt_fallthrough ~default:t1.txpool_max_size t2.txpool_max_size
    ; peer_list_url = opt_fallthrough ~default:t1.peer_list_url t2.peer_list_url
    ; zkapp_proof_update_cost =
        opt_fallthrough ~default:t1.zkapp_proof_update_cost
          t2.zkapp_proof_update_cost
    ; zkapp_signed_single_update_cost =
        opt_fallthrough ~default:t1.zkapp_signed_single_update_cost
          t2.zkapp_signed_single_update_cost
    ; zkapp_signed_pair_update_cost =
        opt_fallthrough ~default:t1.zkapp_signed_pair_update_cost
          t2.zkapp_signed_pair_update_cost
    ; zkapp_transaction_cost_limit =
        opt_fallthrough ~default:t1.zkapp_transaction_cost_limit
          t2.zkapp_transaction_cost_limit
    ; max_event_elements =
        opt_fallthrough ~default:t1.max_event_elements t2.max_event_elements
    ; max_action_elements =
        opt_fallthrough ~default:t1.max_action_elements t2.max_action_elements
    }

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind txpool_max_size = Int.gen_incl 0 1000 in
    let%bind zkapp_proof_update_cost = Float.gen_incl 0.0 100.0 in
    let%bind zkapp_signed_single_update_cost = Float.gen_incl 0.0 100.0 in
    let%bind zkapp_signed_pair_update_cost = Float.gen_incl 0.0 100.0 in
    let%bind zkapp_transaction_cost_limit = Float.gen_incl 0.0 100.0 in
    let%bind max_event_elements = Int.gen_incl 0 100 in
    let%map max_action_elements = Int.gen_incl 0 1000 in
    { txpool_max_size = Some txpool_max_size
    ; peer_list_url = None
    ; zkapp_proof_update_cost = Some zkapp_proof_update_cost
    ; zkapp_signed_single_update_cost = Some zkapp_signed_single_update_cost
    ; zkapp_signed_pair_update_cost = Some zkapp_signed_pair_update_cost
    ; zkapp_transaction_cost_limit = Some zkapp_transaction_cost_limit
    ; max_event_elements = Some max_event_elements
    ; max_action_elements = Some max_action_elements
    }
end

module Epoch_data = struct
  module Data = struct
    type t = { ledger : Ledger.t; seed : string }
    [@@deriving bin_io_unversioned, yojson]

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger = Ledger.gen in
      let%map seed = String.gen_nonempty in
      { ledger; seed }
  end

  type t =
    { staking : Data.t; next : Data.t option (*If None, then next = staking*) }
  [@@deriving bin_io_unversioned, yojson]

  let to_json_layout : t -> Json_layout.Epoch_data.t =
   fun { staking; next } ->
    let accounts (ledger : Ledger.t) =
      match ledger.base with Accounts acc -> Some acc | _ -> None
    in
    let staking =
      { Json_layout.Epoch_data.Data.accounts = accounts staking.ledger
      ; seed = staking.seed
      ; hash = staking.ledger.hash
      }
    in
    let next =
      Option.map next ~f:(fun n ->
          { Json_layout.Epoch_data.Data.accounts = accounts n.ledger
          ; seed = n.seed
          ; hash = n.ledger.hash
          } )
    in
    { Json_layout.Epoch_data.staking; next }

  let of_json_layout : Json_layout.Epoch_data.t -> (t, string) Result.t =
   fun { staking; next } ->
    let open Result.Let_syntax in
    let data (t : [ `Staking | `Next ])
        { Json_layout.Epoch_data.Data.accounts; seed; hash } =
      let%map base =
        match accounts with
        | Some accounts ->
            return @@ Ledger.Accounts accounts
        | None -> (
            match hash with
            | Some hash ->
                return @@ Ledger.Hash hash
            | None ->
                let ledger_name =
                  match t with `Staking -> "staking" | `Next -> "next"
                in
                Error
                  (sprintf
                     "Runtime_config.Epoch_data.of_json_layout: Expected a \
                      field 'accounts', or 'hash' in '%s' ledger"
                     ledger_name ) )
      in
      let ledger =
        { Ledger.base
        ; num_accounts = None
        ; balances = []
        ; hash
        ; name = None
        ; add_genesis_winner = Some false
        }
      in
      { Data.ledger; seed }
    in
    let%bind staking = data `Staking staking in
    let%map next =
      Option.value_map next ~default:(Ok None) ~f:(fun next ->
          Result.map ~f:Option.some @@ data `Next next )
    in
    { staking; next }

  let to_yojson x = Json_layout.Epoch_data.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Epoch_data.of_yojson json)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind staking = Data.gen in
    let%map next = Option.quickcheck_generator Data.gen in
    { staking; next }
end

type t =
  { daemon : Daemon.t option
  ; genesis : Genesis.t option
  ; proof : Proof_keys.t option
  ; ledger : Ledger.t option
  ; epoch_data : Epoch_data.t option
  }
[@@deriving bin_io_unversioned]

let make ?daemon ?genesis ?proof ?ledger ?epoch_data () =
  { daemon; genesis; proof; ledger; epoch_data }

let to_json_layout { daemon; genesis; proof; ledger; epoch_data } =
  { Json_layout.daemon = Option.map ~f:Daemon.to_json_layout daemon
  ; genesis = Option.map ~f:Genesis.to_json_layout genesis
  ; proof = Option.map ~f:Proof_keys.to_json_layout proof
  ; ledger = Option.map ~f:Ledger.to_json_layout ledger
  ; epoch_data = Option.map ~f:Epoch_data.to_json_layout epoch_data
  }

let of_json_layout { Json_layout.daemon; genesis; proof; ledger; epoch_data } =
  let open Result.Let_syntax in
  let%map daemon = result_opt ~f:Daemon.of_json_layout daemon
  and genesis = result_opt ~f:Genesis.of_json_layout genesis
  and proof = result_opt ~f:Proof_keys.of_json_layout proof
  and ledger = result_opt ~f:Ledger.of_json_layout ledger
  and epoch_data = result_opt ~f:Epoch_data.of_json_layout epoch_data in
  { daemon; genesis; proof; ledger; epoch_data }

let to_yojson x = Json_layout.to_yojson (to_json_layout x)

let to_yojson_without_accounts x =
  let layout = to_json_layout x in
  let genesis_accounts =
    let%bind.Option { accounts; _ } = layout.ledger in
    Option.map ~f:List.length accounts
  in
  let staking_accounts =
    let%bind.Option { staking; _ } = layout.epoch_data in
    Option.map ~f:List.length staking.accounts
  in
  let next_accounts =
    let%bind.Option { next; _ } = layout.epoch_data in
    let%bind.Option { accounts; _ } = next in
    Option.map ~f:List.length accounts
  in
  let layout =
    let f ledger = { ledger with Json_layout.Ledger.accounts = None } in
    { layout with
      ledger = Option.map ~f layout.ledger
    ; epoch_data =
        Option.map layout.epoch_data ~f:(fun { staking; next } ->
            { Json_layout.Epoch_data.staking = { staking with accounts = None }
            ; next = Option.map next ~f:(fun n -> { n with accounts = None })
            } )
    }
  in
  ( Json_layout.to_yojson layout
  , `Accounts_omitted
      (`Genesis genesis_accounts, `Staking staking_accounts, `Next next_accounts)
  )

let of_yojson json = Result.bind ~f:of_json_layout (Json_layout.of_yojson json)

let default =
  { daemon = None
  ; genesis = None
  ; proof = None
  ; ledger = None
  ; epoch_data = None
  }

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
  { daemon = merge ~combine:Daemon.combine t1.daemon t2.daemon
  ; genesis = merge ~combine:Genesis.combine t1.genesis t2.genesis
  ; proof = merge ~combine:Proof_keys.combine t1.proof t2.proof
  ; ledger = opt_fallthrough ~default:t1.ledger t2.ledger
  ; epoch_data = opt_fallthrough ~default:t1.epoch_data t2.epoch_data
  }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map daemon = Daemon.gen
  and genesis = Genesis.gen
  and proof = Proof_keys.gen
  and ledger = Ledger.gen
  and epoch_data = Epoch_data.gen in
  { daemon = Some daemon
  ; genesis = Some genesis
  ; proof = Some proof
  ; ledger = Some ledger
  ; epoch_data = Some epoch_data
  }

let ledger_accounts (ledger : Mina_ledger.Ledger.Any_ledger.witness) =
  Mina_ledger.Ledger.Any_ledger.M.to_list ledger
  |> Async.Deferred.map ~f:(map_results ~f:Accounts.Single.of_account)

let ledger_of_accounts accounts =
  Ledger.
    { base = Accounts accounts
    ; num_accounts = Some (List.length accounts)
    ; balances = List.mapi accounts ~f:(fun i a -> (i, a.balance))
    ; hash = None
    ; name = None
    ; add_genesis_winner = Some false
    }

let make_fork_config ~staged_ledger ~global_slot ~blockchain_length
    ~protocol_state_hash ~staking_ledger ~staking_epoch_seed ~next_epoch_ledger
    ~next_epoch_seed (runtime_config : t) =
  let open Async.Deferred.Result.Let_syntax in
  let global_slot =
    Mina_numbers.Global_slot_since_hard_fork.to_int global_slot
  in
  let blockchain_length = Unsigned.UInt32.to_int blockchain_length in
  let%bind accounts =
    Mina_ledger.Ledger.Any_ledger.cast (module Mina_ledger.Ledger) staged_ledger
    |> ledger_accounts
  in
  let ledger = Option.value_exn runtime_config.ledger in
  let previous_length =
    let open Option.Let_syntax in
    let%bind proof = runtime_config.proof in
    let%map fork = proof.fork in
    fork.previous_length + blockchain_length
  in
  let fork =
    Fork_config.
      { previous_state_hash =
          Mina_base.State_hash.to_base58_check protocol_state_hash
      ; previous_length =
          Option.value ~default:blockchain_length previous_length
      ; previous_global_slot = global_slot
      }
  in
  let%bind staking_ledger_accounts = ledger_accounts staking_ledger in
  let%map next_epoch_ledger_accounts =
    match next_epoch_ledger with
    | None ->
        return None
    | Some l ->
        ledger_accounts l >>| Option.return
  in
  let epoch_data =
    let open Epoch_data in
    let open Data in
    { staking =
        { ledger = ledger_of_accounts staking_ledger_accounts
        ; seed = staking_epoch_seed
        }
    ; next =
        Option.map next_epoch_ledger_accounts ~f:(fun accounts ->
            { ledger = ledger_of_accounts accounts; seed = next_epoch_seed } )
    }
  in
  let update =
    make
    (* add_genesis_winner must be set to false, because this
       config effectively creates a continuation of the current
       blockchain state and therefore the genesis ledger already
       contains the winner of the previous block. No need to
       artificially add it. In fact, it wouldn't work at all,
       because the new node would try to create this account at
       startup, even though it already exists, leading to an error.*)
      ~epoch_data
      ~ledger:
        { ledger with
          base = Accounts accounts
        ; add_genesis_winner = Some false
        }
      ~proof:(Proof_keys.make ~fork ()) ()
  in
  combine runtime_config update

module Test_configs = struct
  let bootstrap =
    lazy
      ( (* test_postake_bootstrap *)
        {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 6
      , "delta": 0
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "none"
      , "sub_windows_per_window": 8
      , "ledger_depth": 6
      , "work_delay": 2
      , "block_window_duration_ms": 1500
      , "transaction_capacity": {"2_to_the": 3}
      , "coinbase_amount": "20"
      , "supercharged_coinbase_factor": 2
      , "account_creation_fee": "1" }
  , "ledger": { "name": "test", "add_genesis_winner": false } }
      |json}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith )

  let transactions =
    lazy
      ( (* test_postake_txns *)
        {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 6
      , "delta": 0
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "check"
      , "sub_windows_per_window": 8
      , "ledger_depth": 6
      , "work_delay": 2
      , "block_window_duration_ms": 15000
      , "transaction_capacity": {"2_to_the": 3}
      , "coinbase_amount": "20"
      , "supercharged_coinbase_factor": 2
      , "account_creation_fee": "1" }
  , "ledger":
      { "name": "test_split_two_stakers"
      , "add_genesis_winner": false } }
      |json}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith )

  let split_snarkless =
    lazy
      ( (* test_postake_split_snarkless *)
        {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 24
      , "delta": 0
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "check"
      , "sub_windows_per_window": 8
      , "ledger_depth": 30
      , "work_delay": 1
      , "block_window_duration_ms": 10000
      , "transaction_capacity": {"2_to_the": 2}
      , "coinbase_amount": "20"
      , "supercharged_coinbase_factor": 2
      , "account_creation_fee": "1" }
  , "ledger":
      { "name": "test_split_two_stakers"
      , "add_genesis_winner": false } }
      |json}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith )

  let delegation =
    lazy
      ( (* test_postake_delegation *)
        {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 4
      , "delta": 0
      , "slots_per_epoch": 72
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "check"
      , "sub_windows_per_window": 4
      , "ledger_depth": 6
      , "work_delay": 1
      , "block_window_duration_ms": 5000
      , "transaction_capacity": {"2_to_the": 2}
      , "coinbase_amount": "20"
      , "supercharged_coinbase_factor": 2
      , "account_creation_fee": "1" }
  , "ledger":
      { "name": "test_delegation"
      , "add_genesis_winner": false } }
      |json}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith )
end
