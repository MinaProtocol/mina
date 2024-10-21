open Core_kernel
open Async

module Fork_config = struct
  (* Note that length might be smaller than the gernesis_slot
     or equal if a block was produced in every slot possible. *)
  type t =
    { state_hash : string
    ; blockchain_length : int (* number of blocks produced since genesis *)
    ; global_slot_since_genesis : int (* global slot since genesis *)
    }
  [@@deriving yojson, bin_io_unversioned]
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

let rec deferred_list_fold ~init ~f = function
  | [] ->
      Async.Deferred.Result.return init
  | h :: t ->
      let open Async.Deferred.Result.Let_syntax in
      let%bind init = f init h in
      deferred_list_fold ~init ~f t

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

        module Txn_version = struct
          type t = Mina_numbers.Txn_version.Stable.Latest.t
          [@@deriving bin_io_unversioned]

          include (
            Mina_numbers.Txn_version :
              module type of Mina_numbers.Txn_version with type t := t )
        end

        module Verification_key_perm = struct
          type t = { auth : Auth_required.t; txn_version : Txn_version.t }
          [@@deriving sexp, yojson, bin_io_unversioned]
        end

        type t =
          { edit_state : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.edit_state]
          ; send : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.send]
          ; receive : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.receive]
          ; access : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.access]
          ; set_delegate : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_delegate]
          ; set_permissions : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_permissions]
          ; set_verification_key : Verification_key_perm.t
                [@default
                  { auth =
                      Auth_required.of_account_perm
                        (fst
                           Mina_base.Permissions.user_default
                             .set_verification_key )
                  ; txn_version =
                      snd
                        Mina_base.Permissions.user_default.set_verification_key
                  }]
          ; set_zkapp_uri : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_zkapp_uri]
          ; edit_action_state : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.edit_action_state]
          ; set_token_symbol : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_token_symbol]
          ; increment_nonce : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.increment_nonce]
          ; set_voting_for : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_voting_for]
          ; set_timing : Auth_required.t
                [@default
                  Auth_required.of_account_perm
                    Mina_base.Permissions.user_default.set_timing]
          }
        [@@deriving yojson, fields, sexp, bin_io_unversioned]

        let fields = Fields.names |> Array.of_list

        let of_yojson json = of_yojson_generic ~fields of_yojson json

        let to_yojson t =
          `Assoc
            [ ("edit_state", Auth_required.to_yojson t.edit_state)
            ; ("send", Auth_required.to_yojson t.send)
            ; ("receive", Auth_required.to_yojson t.receive)
            ; ("access", Auth_required.to_yojson t.access)
            ; ("set_delegate", Auth_required.to_yojson t.set_delegate)
            ; ("set_permissions", Auth_required.to_yojson t.set_permissions)
            ; ( "set_verification_key"
              , Verification_key_perm.to_yojson t.set_verification_key )
            ; ("set_zkapp_uri", Auth_required.to_yojson t.set_zkapp_uri)
            ; ("edit_action_state", Auth_required.to_yojson t.edit_action_state)
            ; ("set_token_symbol", Auth_required.to_yojson t.set_token_symbol)
            ; ("increment_nonce", Auth_required.to_yojson t.increment_nonce)
            ; ("set_voting_for", Auth_required.to_yojson t.set_voting_for)
            ; ("set_timing", Auth_required.to_yojson t.set_timing)
            ]

        let of_permissions (perm : Mina_base.Permissions.t) =
          { edit_state = Auth_required.of_account_perm perm.edit_action_state
          ; send = Auth_required.of_account_perm perm.send
          ; receive = Auth_required.of_account_perm perm.receive
          ; set_delegate = Auth_required.of_account_perm perm.set_delegate
          ; set_permissions = Auth_required.of_account_perm perm.set_permissions
          ; set_verification_key =
              (let auth, txn_version = perm.set_verification_key in
               { auth = Auth_required.of_account_perm auth; txn_version } )
          ; set_token_symbol =
              Auth_required.of_account_perm perm.set_token_symbol
          ; access = Auth_required.of_account_perm perm.access
          ; edit_action_state =
              Auth_required.of_account_perm perm.edit_action_state
          ; set_zkapp_uri = Auth_required.of_account_perm perm.set_zkapp_uri
          ; increment_nonce = Auth_required.of_account_perm perm.increment_nonce
          ; set_timing = Auth_required.of_account_perm perm.set_timing
          ; set_voting_for = Auth_required.of_account_perm perm.set_voting_for
          }
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

        let of_zkapp (zkapp : Mina_base.Zkapp_account.t) : t =
          let open Mina_base.Zkapp_account in
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
          }
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
      ; s3_data_hash : string option [@default None]
      ; name : string option [@default None]
      ; add_genesis_winner : bool option [@default None]
      }
    [@@deriving yojson, fields]

    let fields = Fields.names |> Array.of_list

    let of_yojson json = of_yojson_generic ~fields of_yojson json

    let default : t =
      { accounts = None
      ; num_accounts = None
      ; balances = []
      ; hash = None
      ; s3_data_hash = None
      ; name = None
      ; add_genesis_winner = None
      }
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
      ; zkapp_cmd_limit_hardcap : int option [@default None]
      ; slot_tx_end : int option [@default None]
      ; slot_chain_end : int option [@default None]
      ; minimum_user_command_fee : Currency.Fee.t option [@default None]
      ; network_id : string option [@default None]
      ; client_port : int option [@default None] [@key "client-port"]
      ; libp2p_port : int option [@default None] [@key "libp2p-port"]
      ; rest_port : int option [@default None] [@key "rest-port"]
      ; graphql_port : int option [@default None] [@key "limited-graphql-port"]
      ; node_status_url : string option [@default None] [@key "node-status-url"]
      ; block_producer_key : string option
            [@default None] [@key "block-producer-key"]
      ; block_producer_pubkey : string option
            [@default None] [@key "block-producer-pubkey"]
      ; block_producer_password : string option
            [@default None] [@key "block-producer-password"]
      ; coinbase_receiver : string option
            [@default None] [@key "coinbase-receiver"]
      ; run_snark_worker : string option
            [@default None] [@key "run-snark-worker"]
      ; run_snark_coordinator : string option
            [@default None] [@key "run-snark-coordinator"]
      ; snark_worker_fee : int option [@default None] [@key "snark-worker-fee"]
      ; snark_worker_parallelism : int option
            [@default None] [@key "snark-worker-parallelism"]
      ; work_selection : string option [@default None] [@key "work-selection"]
      ; work_reassignment_wait : int option
            [@default None] [@key "work-reassignment-wait"]
      ; log_txn_pool_gossip : bool option
            [@default None] [@key "log-txn-pool-gossip"]
      ; log_snark_work_gossip : bool option
            [@default None] [@key "log-snark-work-gossip"]
      ; log_block_creation : bool option
            [@default None] [@key "log-block-creation"]
      ; min_connections : int option [@default None] [@key "min-connections"]
      ; max_connections : int option [@default None] [@key "max-connections"]
      ; pubsub_v0 : string option [@default None] [@key "pubsub-v0"]
      ; validation_queue_size : int option
            [@default None] [@key "validation-queue-size"]
      ; stop_time : int option [@default None] [@key "stop-time"]
      ; peers : string list option [@default None] [@key "peers"]
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
        ; s3_data_hash : string option [@default None]
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

  let default : t =
    { daemon = None
    ; genesis = None
    ; proof = None
    ; ledger = None
    ; epoch_data = None
    }
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
        ; zkapp = Option.map a.zkapp ~f:Zkapp_account.of_zkapp
        ; nonce = a.nonce
        ; receipt_chain_hash =
            Some
              (Mina_base.Receipt.Chain_hash.to_base58_check a.receipt_chain_hash)
        ; voting_for = Some (Mina_base.State_hash.to_base58_check a.voting_for)
        ; permissions = Some (Permissions.of_permissions a.permissions)
        }

    let to_account ?(ignore_missing_fields = false) (a : t) :
        Mina_base.Account.t =
      let open Signature_lib in
      let timing =
        let open Mina_base.Account_timing.Poly in
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
      let to_permissions (perms : Permissions.t) =
        Mina_base.Permissions.Poly.
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
              ( Json_layout.Accounts.Single.Permissions.Auth_required
                .to_account_perm perms.set_verification_key.auth
              , perms.set_verification_key.txn_version )
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
      let permissions =
        match (ignore_missing_fields, a.permissions) with
        | _, Some perms ->
            to_permissions perms
        | false, None ->
            failwithf "no permissions set for account %s" a.pk ()
        | true, _ ->
            Mina_base.Permissions.user_default
      in
      let mk_zkapp (app : Zkapp_account.t) :
          ( Mina_base.Zkapp_state.Value.t
          , Mina_base.Verification_key_wire.t option
          , Zkapp_account.Zkapp_version.t
          , Zkapp_account.Field.t
          , Mina_numbers.Global_slot_since_genesis.t
          , bool
          , string )
          Mina_base.Zkapp_account.Poly.t =
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
      let receipt_chain_hash =
        match (ignore_missing_fields, a.receipt_chain_hash) with
        | _, Some rch ->
            Mina_base.Receipt.Chain_hash.of_base58_check_exn rch
        | false, None ->
            failwithf "no receipt_chain_hash set for account %s" a.pk ()
        | true, _ ->
            Mina_base.Receipt.Chain_hash.empty
      in
      let voting_for =
        match (ignore_missing_fields, a.voting_for) with
        | _, Some voting_for ->
            Mina_base.State_hash.of_base58_check_exn voting_for
        | false, None ->
            failwithf "no voting_for set for account %s" a.pk ()
        | true, _ ->
            Mina_base.State_hash.dummy
      in
      { public_key = Public_key.Compressed.of_base58_check_exn a.pk
      ; token_id =
          Mina_base.Token_id.(Option.value_map ~default ~f:of_string a.token)
      ; token_symbol = Option.value ~default:"" a.token_symbol
      ; balance = a.balance
      ; nonce = a.nonce
      ; receipt_chain_hash
      ; delegate =
          Option.map ~f:Public_key.Compressed.of_base58_check_exn a.delegate
      ; voting_for
      ; timing
      ; permissions
      ; zkapp = Option.map ~f:mk_zkapp a.zkapp
      }
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
    | Hash
        (** The ledger with the given root hash stored in the containing Ledger.t *)
  [@@deriving bin_io_unversioned]

  type t =
    { base : base
    ; num_accounts : int option
    ; balances : (int * Currency.Balance.Stable.Latest.t) list
    ; hash : string option
    ; s3_data_hash : string option
    ; name : string option
    ; add_genesis_winner : bool option
    }
  [@@deriving bin_io_unversioned]

  let to_json_layout
      { base
      ; num_accounts
      ; balances
      ; hash
      ; name
      ; add_genesis_winner
      ; s3_data_hash
      } : Json_layout.Ledger.t =
    let balances =
      List.map balances ~f:(fun (number, balance) ->
          { Json_layout.Ledger.Balance_spec.number; balance } )
    in
    let without_base : Json_layout.Ledger.t =
      { accounts = None
      ; num_accounts
      ; balances
      ; hash
      ; s3_data_hash
      ; name
      ; add_genesis_winner
      }
    in
    match base with
    | Named name ->
        { without_base with name = Some name }
    | Accounts accounts ->
        { without_base with accounts = Some (Accounts.to_json_layout accounts) }
    | Hash ->
        without_base

  let of_json_layout
      ({ accounts
       ; num_accounts
       ; balances
       ; hash
       ; s3_data_hash
       ; name
       ; add_genesis_winner
       } :
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
              | Some _ ->
                  return Hash
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
    { base
    ; num_accounts
    ; balances
    ; hash
    ; s3_data_hash
    ; name
    ; add_genesis_winner
    }

  let to_yojson x = Json_layout.Ledger.to_yojson (to_json_layout x)

  let of_yojson json =
    Result.bind ~f:of_json_layout (Json_layout.Ledger.of_yojson json)
end

module Proof_keys = struct
  module Level = struct
    type t = Full | Check | No_check [@@deriving bin_io_unversioned, equal]

    let to_string = function
      | Full ->
          "full"
      | Check ->
          "check"
      | No_check ->
          "none"

    let of_string str =
      match String.lowercase str with
      | "full" ->
          Ok Full
      | "check" ->
          Ok Check
      | "none" ->
          Ok No_check
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

    let small : t = Log_2 2

    let medium : t = Log_2 3

    let to_transaction_capacity_log_2 ~block_window_duration_ms
        ~transaction_capacity =
      match transaction_capacity with
      | Log_2 i ->
          i
      | Txns_per_second_x10 tps_goal_x10 ->
          let max_coinbases = 2 in
          let max_user_commands_per_block =
            (* block_window_duration is in milliseconds, so divide by 1000 divide
               by 10 again because we have tps * 10
            *)
            tps_goal_x10 * block_window_duration_ms / (1000 * 10)
          in
          (* Log of the capacity of transactions per transition.
              - 1 will only work if we don't have prover fees.
              - 2 will work with prover fees, but not if we want a transaction
                included in every block.
              - At least 3 ensures a transaction per block and the staged-ledger
                unit tests pass.
          *)
          1
          + Core_kernel.Int.ceil_log2
              (max_user_commands_per_block + max_coinbases)
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
  [@@deriving bin_io_unversioned, yojson]

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

  let default =
    { level = None
    ; sub_windows_per_window = None
    ; ledger_depth = None
    ; work_delay = None
    ; block_window_duration_ms = None
    ; transaction_capacity = None
    ; coinbase_amount = None
    ; supercharged_coinbase_factor = None
    ; account_creation_fee = None
    ; fork = None
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
    ; zkapp_cmd_limit_hardcap : int option [@default None]
    ; slot_tx_end : int option [@default None]
    ; slot_chain_end : int option [@default None]
    ; minimum_user_command_fee : Currency.Fee.Stable.Latest.t option
          [@default None]
    ; network_id : string option [@default None]
    ; client_port : int option [@default None]
    ; libp2p_port : int option [@default None]
    ; rest_port : int option [@default None]
    ; graphql_port : int option [@default None]
    ; node_status_url : string option [@default None]
    ; block_producer_key : string option [@default None]
    ; block_producer_pubkey : string option [@default None]
    ; block_producer_password : string option [@default None]
    ; coinbase_receiver : string option [@default None]
    ; run_snark_worker : string option [@default None]
    ; run_snark_coordinator : string option [@default None]
    ; snark_worker_fee : int option [@default None]
    ; snark_worker_parallelism : int option [@default None]
    ; work_selection : string option [@default None]
    ; work_reassignment_wait : int option [@default None]
    ; log_txn_pool_gossip : bool option [@default None]
    ; log_snark_work_gossip : bool option [@default None]
    ; log_block_creation : bool option [@default None]
    ; min_connections : int option [@default None]
    ; max_connections : int option [@default None]
    ; pubsub_v0 : string option [@default None]
    ; validation_queue_size : int option [@default None]
    ; stop_time : int option [@default None]
    ; peers : string list option [@default None]
    }
  [@@deriving bin_io_unversioned, fields]

  let default : t =
    { txpool_max_size = None
    ; peer_list_url = None
    ; zkapp_proof_update_cost = None
    ; zkapp_signed_single_update_cost = None
    ; zkapp_signed_pair_update_cost = None
    ; zkapp_transaction_cost_limit = None
    ; max_event_elements = None
    ; max_action_elements = None
    ; zkapp_cmd_limit_hardcap = None
    ; slot_tx_end = None
    ; slot_chain_end = None
    ; minimum_user_command_fee = None
    ; network_id = None
    ; client_port = None
    ; libp2p_port = None
    ; rest_port = None
    ; graphql_port = None
    ; node_status_url = None
    ; block_producer_key = None
    ; block_producer_pubkey = None
    ; block_producer_password = None
    ; coinbase_receiver = None
    ; run_snark_worker = None
    ; run_snark_coordinator = None
    ; snark_worker_fee = None
    ; snark_worker_parallelism = None
    ; work_selection = None
    ; work_reassignment_wait = None
    ; log_txn_pool_gossip = None
    ; log_snark_work_gossip = None
    ; log_block_creation = None
    ; min_connections = None
    ; max_connections = None
    ; pubsub_v0 = None
    ; validation_queue_size = None
    ; stop_time = None
    ; peers = None
    }

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
    ; zkapp_cmd_limit_hardcap =
        opt_fallthrough ~default:t1.zkapp_cmd_limit_hardcap
          t2.zkapp_cmd_limit_hardcap
    ; slot_tx_end = opt_fallthrough ~default:t1.slot_tx_end t2.slot_tx_end
    ; slot_chain_end =
        opt_fallthrough ~default:t1.slot_chain_end t2.slot_chain_end
    ; minimum_user_command_fee =
        opt_fallthrough ~default:t1.minimum_user_command_fee
          t2.minimum_user_command_fee
    ; network_id = opt_fallthrough ~default:t1.network_id t2.network_id
    ; client_port = opt_fallthrough ~default:t1.client_port t2.client_port
    ; libp2p_port = opt_fallthrough ~default:t1.libp2p_port t2.libp2p_port
    ; rest_port = opt_fallthrough ~default:t1.rest_port t2.rest_port
    ; graphql_port = opt_fallthrough ~default:t1.graphql_port t2.graphql_port
    ; node_status_url =
        opt_fallthrough ~default:t1.node_status_url t2.node_status_url
    ; block_producer_key =
        opt_fallthrough ~default:t1.block_producer_key t2.block_producer_key
    ; block_producer_pubkey =
        opt_fallthrough ~default:t1.block_producer_pubkey
          t2.block_producer_pubkey
    ; block_producer_password =
        opt_fallthrough ~default:t1.block_producer_password
          t2.block_producer_password
    ; coinbase_receiver =
        opt_fallthrough ~default:t1.coinbase_receiver t2.coinbase_receiver
    ; run_snark_worker =
        opt_fallthrough ~default:t1.run_snark_worker t2.run_snark_worker
    ; run_snark_coordinator =
        opt_fallthrough ~default:t1.run_snark_coordinator
          t2.run_snark_coordinator
    ; snark_worker_fee =
        opt_fallthrough ~default:t1.snark_worker_fee t2.snark_worker_fee
    ; snark_worker_parallelism =
        opt_fallthrough ~default:t1.snark_worker_parallelism
          t2.snark_worker_parallelism
    ; work_selection =
        opt_fallthrough ~default:t1.work_selection t2.work_selection
    ; work_reassignment_wait =
        opt_fallthrough ~default:t1.work_reassignment_wait
          t2.work_reassignment_wait
    ; log_txn_pool_gossip =
        opt_fallthrough ~default:t1.log_txn_pool_gossip t2.log_txn_pool_gossip
    ; log_snark_work_gossip =
        opt_fallthrough ~default:t1.log_snark_work_gossip
          t2.log_snark_work_gossip
    ; log_block_creation =
        opt_fallthrough ~default:t1.log_block_creation t2.log_block_creation
    ; min_connections =
        opt_fallthrough ~default:t1.min_connections t2.min_connections
    ; max_connections =
        opt_fallthrough ~default:t1.max_connections t2.max_connections
    ; pubsub_v0 = opt_fallthrough ~default:t1.pubsub_v0 t2.pubsub_v0
    ; validation_queue_size =
        opt_fallthrough ~default:t1.validation_queue_size
          t2.validation_queue_size
    ; stop_time = opt_fallthrough ~default:t1.stop_time t2.stop_time
    ; peers = opt_fallthrough ~default:t1.peers t2.peers
    }
end

module Epoch_data = struct
  module Data = struct
    type t = { ledger : Ledger.t; seed : string }
    [@@deriving bin_io_unversioned, yojson]
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
      ; s3_data_hash = staking.ledger.s3_data_hash
      }
    in
    let next =
      Option.map next ~f:(fun n ->
          { Json_layout.Epoch_data.Data.accounts = accounts n.ledger
          ; seed = n.seed
          ; hash = n.ledger.hash
          ; s3_data_hash = n.ledger.s3_data_hash
          } )
    in
    { Json_layout.Epoch_data.staking; next }

  let of_json_layout : Json_layout.Epoch_data.t -> (t, string) Result.t =
   fun { staking; next } ->
    let open Result.Let_syntax in
    let data (t : [ `Staking | `Next ])
        { Json_layout.Epoch_data.Data.accounts; seed; hash; s3_data_hash } =
      let%map base =
        match accounts with
        | Some accounts ->
            return @@ Ledger.Accounts accounts
        | None -> (
            match hash with
            | Some _ ->
                return @@ Ledger.Hash
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
        ; s3_data_hash
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
end

type t =
  { daemon : Daemon.t option
  ; genesis : Genesis.t option
  ; proof : Proof_keys.t option
  ; ledger : Ledger.t option
  ; epoch_data : Epoch_data.t option
  }
[@@deriving bin_io_unversioned, fields]

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

let ledger_accounts (ledger : Mina_ledger.Ledger.Any_ledger.witness) =
  let open Async.Deferred.Result.Let_syntax in
  let yield = Async_unix.Scheduler.yield_every ~n:100 |> Staged.unstage in
  let%bind accounts =
    Mina_ledger.Ledger.Any_ledger.M.to_list ledger
    |> Async.Deferred.map ~f:Result.return
  in
  let%map accounts =
    deferred_list_fold ~init:[]
      ~f:(fun acc el ->
        let open Async.Deferred.Infix in
        let%bind () = yield () >>| Result.return in
        let%map elt = Accounts.Single.of_account el |> Async.Deferred.return in
        elt :: acc )
      accounts
  in
  List.rev accounts

let ledger_of_accounts accounts =
  Ledger.
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some false
    }

let make_fork_config ~staged_ledger ~global_slot_since_genesis ~state_hash
    ~blockchain_length ~staking_ledger ~staking_epoch_seed ~next_epoch_ledger
    ~next_epoch_seed =
  let open Async.Deferred.Result.Let_syntax in
  let global_slot_since_genesis =
    Mina_numbers.Global_slot_since_genesis.to_int global_slot_since_genesis
  in
  let blockchain_length = Unsigned.UInt32.to_int blockchain_length in
  let yield () =
    let open Async.Deferred.Infix in
    Async_unix.Scheduler.yield () >>| Result.return
  in
  let%bind () = yield () in
  let%bind accounts =
    Mina_ledger.Ledger.Any_ledger.cast (module Mina_ledger.Ledger) staged_ledger
    |> ledger_accounts
  in
  let hash =
    Option.some @@ Mina_base.Ledger_hash.to_base58_check
    @@ Mina_ledger.Ledger.merkle_root staged_ledger
  in
  let fork =
    Fork_config.
      { state_hash = Mina_base.State_hash.to_base58_check state_hash
      ; blockchain_length
      ; global_slot_since_genesis
      }
  in
  let%bind () = yield () in
  let%bind staking_ledger_accounts = ledger_accounts staking_ledger in
  let%bind () = yield () in
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
      { base = Accounts accounts
      ; num_accounts = None
      ; balances = []
      ; hash
      ; s3_data_hash = None
      ; name = None
      ; add_genesis_winner = Some false
      }
    ~proof:(Proof_keys.make ~fork ()) ()

let slot_tx_end, slot_chain_end =
  let f get_runtime t =
    let open Option.Let_syntax in
    t.daemon >>= get_runtime >>| Mina_numbers.Global_slot_since_hard_fork.of_int
  in
  (f (fun d -> d.slot_tx_end), f (fun d -> d.slot_chain_end))

module type Json_loader_intf = sig
  val load_config_files :
       ?conf_dir:string
    -> ?commit_id_short:string
    -> logger:Logger.t
    -> string list
    -> t Deferred.Or_error.t
end

module Json_loader : Json_loader_intf = struct
  let load_config_file filename =
    Monitor.try_with_or_error ~here:[%here] (fun () ->
        let%map json = Reader.file_contents filename in
        Yojson.Safe.from_string json )

  let get_magic_config_files ?conf_dir
      ?(commit_id_short = Mina_version.commit_id_short) () =
    let config_file_installed =
      (* Search for config files installed as part of a deb/brew package.
         These files are commit-dependent, to ensure that we don't clobber
         configuration for dev builds or use incompatible configs.
      *)
      let config_file_installed =
        let json = "config_" ^ commit_id_short ^ ".json" in
        List.fold_until ~init:None
          (Cache_dir.possible_paths json)
          ~f:(fun _acc f ->
            match Core.Sys.file_exists f with
            | `Yes ->
                Stop (Some f)
            | _ ->
                Continue None )
          ~finish:Fn.id
      in
      match config_file_installed with
      | Some config_file ->
          Some (config_file, `Must_exist)
      | None ->
          None
    in

    let config_file_configdir =
      Option.map conf_dir ~f:(fun dir ->
          (dir ^ "/" ^ "daemon.json", `May_be_missing) )
    in
    let config_file_envvar =
      match Sys.getenv "MINA_CONFIG_FILE" with
      | Some config_file ->
          Some (config_file, `Must_exist)
      | None ->
          None
    in
    List.filter_opt
      [ config_file_installed; config_file_configdir; config_file_envvar ]

  let load_config_files ?conf_dir ?commit_id_short ~logger config_files =
    let open Deferred.Or_error.Let_syntax in
    let config_files = List.map ~f:(fun a -> (a, `Must_exist)) config_files in
    let config_files =
      get_magic_config_files ?conf_dir ?commit_id_short () @ config_files
    in
    let%map config_jsons =
      let config_files_paths =
        List.map config_files ~f:(fun (config_file, _) -> `String config_file)
      in
      [%log info] "Reading configuration files $config_files"
        ~metadata:[ ("config_files", `List config_files_paths) ] ;
      Deferred.Or_error.List.filter_map config_files
        ~f:(fun (config_file, handle_missing) ->
          match%bind.Deferred load_config_file config_file with
          | Ok config_json ->
              Deferred.Or_error.return @@ Some (config_file, config_json)
          | Error err -> (
              match handle_missing with
              | `Must_exist ->
                  Mina_user_error.raisef ~where:"reading configuration file"
                    "The configuration file %s could not be read:\n%s"
                    config_file (Error.to_string_hum err)
              | `May_be_missing ->
                  [%log warn] "Could not read configuration from $config_file"
                    ~metadata:
                      [ ("config_file", `String config_file)
                      ; ("error", Error_json.error_to_yojson err)
                      ] ;
                  return None ) )
    in
    List.fold ~init:default config_jsons
      ~f:(fun config (config_file, config_json) ->
        match of_yojson config_json with
        | Ok loaded_config ->
            combine config loaded_config
        | Error err ->
            [%log fatal]
              "Could not parse configuration from $config_file: $error"
              ~metadata:
                [ ("config_file", `String config_file)
                ; ("config_json", config_json)
                ; ("error", `String err)
                ] ;
            failwithf "Could not parse configuration file: %s" err () )
end

module type Constants_intf = sig
  type constants

  val load_constants :
       ?conf_dir:string
    -> ?commit_id_short:string
    -> ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> logger:Logger.t
    -> string list
    -> constants Deferred.t

  val load_constants' :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> t
    -> constants

  val genesis_constants : constants -> Genesis_constants.t

  val constraint_constants :
    constants -> Genesis_constants.Constraint_constants.t

  val proof_level : constants -> Genesis_constants.Proof_level.t

  val compile_config : constants -> Mina_compile_config.t

  val magic_for_unit_tests : t -> constants
end

module Constants : Constants_intf = struct
  type constants =
    { genesis_constants : Genesis_constants.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; compile_config : Mina_compile_config.t
    }

  let genesis_constants t = t.genesis_constants

  let constraint_constants t = t.constraint_constants

  let proof_level t = t.proof_level

  let compile_config t = t.compile_config

  let combine (a : constants) (b : t) : constants =
    let genesis_constants =
      { Genesis_constants.protocol =
          { k =
              Option.value ~default:a.genesis_constants.protocol.k
                Option.(b.genesis >>= fun g -> g.k)
          ; delta =
              Option.value ~default:a.genesis_constants.protocol.delta
                Option.(b.genesis >>= fun g -> g.delta)
          ; slots_per_epoch =
              Option.value ~default:a.genesis_constants.protocol.slots_per_epoch
                Option.(b.genesis >>= fun g -> g.slots_per_epoch)
          ; slots_per_sub_window =
              Option.value
                ~default:a.genesis_constants.protocol.slots_per_sub_window
                Option.(b.genesis >>= fun g -> g.slots_per_sub_window)
          ; grace_period_slots =
              Option.value
                ~default:a.genesis_constants.protocol.grace_period_slots
                Option.(b.genesis >>= fun g -> g.grace_period_slots)
          ; genesis_state_timestamp =
              Option.value
                ~default:a.genesis_constants.protocol.genesis_state_timestamp
                Option.(
                  b.genesis
                  >>= fun g ->
                  g.genesis_state_timestamp
                  >>| Genesis_constants.genesis_timestamp_of_string
                  >>| Genesis_constants.of_time)
          }
      ; txpool_max_size =
          Option.value ~default:a.genesis_constants.txpool_max_size
            Option.(b.daemon >>= fun d -> d.txpool_max_size)
      ; num_accounts =
          Option.first_some
            Option.(b.ledger >>= fun l -> l.num_accounts)
            a.genesis_constants.num_accounts
      ; zkapp_proof_update_cost =
          Option.value ~default:a.genesis_constants.zkapp_proof_update_cost
            Option.(b.daemon >>= fun d -> d.zkapp_proof_update_cost)
      ; zkapp_signed_single_update_cost =
          Option.value
            ~default:a.genesis_constants.zkapp_signed_single_update_cost
            Option.(b.daemon >>= fun d -> d.zkapp_signed_single_update_cost)
      ; zkapp_signed_pair_update_cost =
          Option.value
            ~default:a.genesis_constants.zkapp_signed_pair_update_cost
            Option.(b.daemon >>= fun d -> d.zkapp_signed_pair_update_cost)
      ; zkapp_transaction_cost_limit =
          Option.value ~default:a.genesis_constants.zkapp_transaction_cost_limit
            Option.(b.daemon >>= fun d -> d.zkapp_transaction_cost_limit)
      ; max_event_elements =
          Option.value ~default:a.genesis_constants.max_event_elements
            Option.(b.daemon >>= fun d -> d.max_event_elements)
      ; max_action_elements =
          Option.value ~default:a.genesis_constants.max_action_elements
            Option.(b.daemon >>= fun d -> d.max_action_elements)
      ; zkapp_cmd_limit_hardcap =
          Option.value ~default:a.genesis_constants.zkapp_cmd_limit_hardcap
            Option.(b.daemon >>= fun d -> d.zkapp_cmd_limit_hardcap)
      ; minimum_user_command_fee =
          Option.value ~default:a.genesis_constants.minimum_user_command_fee
            Option.(b.daemon >>= fun d -> d.minimum_user_command_fee)
      }
    in
    let constraint_constants =
      let fork =
        let a = a.constraint_constants.fork in
        let b =
          let%map.Option f = Option.(b.proof >>= fun x -> x.fork) in
          { Genesis_constants.Fork_constants.state_hash =
              Mina_base.State_hash.of_base58_check_exn f.state_hash
          ; blockchain_length = Mina_numbers.Length.of_int f.blockchain_length
          ; global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.of_int
                f.global_slot_since_genesis
          }
        in
        Option.first_some b a
      in
      let block_window_duration_ms =
        Option.value ~default:a.constraint_constants.block_window_duration_ms
          Option.(b.proof >>= fun p -> p.block_window_duration_ms)
      in
      { a.constraint_constants with
        sub_windows_per_window =
          Option.value ~default:a.constraint_constants.sub_windows_per_window
            Option.(b.proof >>= fun p -> p.sub_windows_per_window)
      ; ledger_depth =
          Option.value ~default:a.constraint_constants.ledger_depth
            Option.(b.proof >>= fun p -> p.ledger_depth)
      ; work_delay =
          Option.value ~default:a.constraint_constants.work_delay
            Option.(b.proof >>= fun p -> p.work_delay)
      ; block_window_duration_ms
      ; transaction_capacity_log_2 =
          Option.value
            ~default:a.constraint_constants.transaction_capacity_log_2
            Option.(
              b.proof
              >>= fun p ->
              p.transaction_capacity
              >>| fun transaction_capacity ->
              Proof_keys.Transaction_capacity.to_transaction_capacity_log_2
                ~block_window_duration_ms ~transaction_capacity)
      ; coinbase_amount =
          Option.value ~default:a.constraint_constants.coinbase_amount
            Option.(b.proof >>= fun p -> p.coinbase_amount)
      ; supercharged_coinbase_factor =
          Option.value
            ~default:a.constraint_constants.supercharged_coinbase_factor
            Option.(b.proof >>= fun p -> p.supercharged_coinbase_factor)
      ; account_creation_fee =
          Option.value ~default:a.constraint_constants.account_creation_fee
            Option.(b.proof >>= fun p -> p.account_creation_fee)
      ; fork
      }
    in
    let proof_level =
      let coerce_proof_level = function
        | Proof_keys.Level.Full ->
            Genesis_constants.Proof_level.Full
        | Check ->
            Genesis_constants.Proof_level.Check
        | No_check ->
            Genesis_constants.Proof_level.No_check
      in
      Option.value ~default:a.proof_level
        Option.(b.proof >>= fun p -> p.level >>| coerce_proof_level)
    in
    let compile_config =
      { a.compile_config with
        block_window_duration =
          constraint_constants.block_window_duration_ms |> Float.of_int
          |> Time.Span.of_ms
      ; network_id =
          Option.value ~default:a.compile_config.network_id
            Option.(b.daemon >>= fun d -> d.network_id)
      }
    in
    { genesis_constants; constraint_constants; proof_level; compile_config }

  let load_constants' ?itn_features ?cli_proof_level runtime_config =
    let compile_constants =
      { genesis_constants = Genesis_constants.Compiled.genesis_constants
      ; constraint_constants = Genesis_constants.Compiled.constraint_constants
      ; proof_level = Genesis_constants.Compiled.proof_level
      ; compile_config = Mina_compile_config.Compiled.t
      }
    in
    let cs = combine compile_constants runtime_config in
    { cs with
      proof_level = Option.value ~default:cs.proof_level cli_proof_level
    ; compile_config =
        { cs.compile_config with
          itn_features =
            Option.value ~default:cs.compile_config.itn_features itn_features
        }
    }

  (* Use this function if you don't need/want the ledger configuration *)
  let load_constants ?conf_dir ?commit_id_short ?itn_features ?cli_proof_level
      ~logger config_files =
    Deferred.Or_error.ok_exn
    @@
    let open Deferred.Or_error.Let_syntax in
    let%map runtime_config =
      Json_loader.load_config_files ?conf_dir ?commit_id_short ~logger
        config_files
    in
    load_constants' ?itn_features ?cli_proof_level runtime_config

  let magic_for_unit_tests t =
    let compile_constants =
      { genesis_constants = Genesis_constants.For_unit_tests.t
      ; constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
      ; proof_level = Genesis_constants.For_unit_tests.Proof_level.t
      ; compile_config = Mina_compile_config.For_unit_tests.t
      }
    in
    combine compile_constants t
end
