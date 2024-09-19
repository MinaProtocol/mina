open Core_kernel
open Async

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
        [@@deriving yojson, sexp]
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
        [@@deriving yojson, sexp, bin_io_unversioned]

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
        [@@deriving sexp, yojson, bin_io_unversioned]

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
      [@@deriving sexp, yojson]

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
    [@@deriving yojson]
  end

  module Epoch_data = struct
    module Data = struct
      type t =
        { accounts : Accounts.t option [@default None]
        ; seed : string
        ; s3_data_hash : string option [@default None]
        ; hash : string option [@default None]
        }
      [@@deriving yojson]
    end

    type t =
      { staking : Data.t
      ; next : (Data.t option[@default None]) (*If None then next = staking*)
      }
    [@@deriving yojson]
  end

  module Constraint = struct
    type t =
      { constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
      ; proof_level : string
      }
    [@@deriving yojson]
  end

  type t =
    { daemon : Mina_compile_config.Inputs.t
    ; genesis : Genesis_constants.Inputs.t
    ; proof : Constraint.t
    ; ledger : Ledger.t
    ; epoch_data : Epoch_data.t option [@default None]
    }
  [@@deriving yojson]
end

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

    let of_json_layout : Json_layout.Accounts.Single.t -> (t, string) Result.t =
      Result.return

    let to_yojson = Json_layout.Accounts.Single.to_yojson

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

    let to_account (a : t) : Mina_base.Account.t =
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
      let permissions =
        let perms = Option.value_exn a.permissions in
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

  let to_yojson x = Json_layout.Accounts.to_yojson (Fn.id x)
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
        { without_base with accounts = Some accounts }
    | Hash ->
        without_base

  let to_yojson x = Json_layout.Ledger.to_yojson (to_json_layout x)

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

  let of_yojson x = Result.(Json_layout.Ledger.of_yojson x >>= of_json_layout)
end

module Epoch_data = struct
  module Data = struct
    type t = { ledger : Ledger.t; seed : string }
    [@@deriving bin_io_unversioned, to_yojson]
  end

  type t =
    { staking : Data.t; next : Data.t option (*If None, then next = staking*) }
  [@@deriving bin_io_unversioned, to_yojson]

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

  let of_yojson x =
    Result.(Json_layout.Epoch_data.of_yojson x >>= of_json_layout)
end

module Constraint = struct
  type t =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    }
  [@@deriving to_yojson]

  let of_json_layout : Json_layout.Constraint.t -> t =
   fun { constraint_constants; proof_level } ->
    { constraint_constants =
        Genesis_constants.Constraint_constants.make constraint_constants
    ; proof_level = Genesis_constants.Proof_level.of_string proof_level
    }
end

type t =
  { compile_config : Mina_compile_config.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_config : Constraint.t
  ; ledger : Ledger.t
  ; epoch_data : Epoch_data.t option
  }
[@@deriving to_yojson]

let format_as_json_without_accounts (x : t) =
  let genesis_accounts =
    let ({ accounts; _ } : Json_layout.Ledger.t) =
      Ledger.to_json_layout x.ledger
    in
    Option.map ~f:List.length accounts
  in
  let staking_accounts =
    let%bind.Option { staking; _ } = x.epoch_data in
    Option.map ~f:List.length (Ledger.to_json_layout staking.ledger).accounts
  in
  let next_accounts =
    let%bind.Option { next; _ } = x.epoch_data in
    let%bind.Option { ledger; _ } = next in
    Option.map ~f:List.length (Ledger.to_json_layout ledger).accounts
  in
  let f ledger =
    { (Ledger.to_json_layout ledger) with Json_layout.Ledger.accounts = None }
  in
  let g ({ staking; next } : Epoch_data.t) =
    { Json_layout.Epoch_data.staking =
        (let l = f staking.ledger in
         { accounts = None
         ; seed = staking.seed
         ; hash = l.hash
         ; s3_data_hash = l.s3_data_hash
         } )
    ; next =
        Option.map next ~f:(fun n ->
            let l = f n.ledger in
            { Json_layout.Epoch_data.Data.accounts = None
            ; seed = n.seed
            ; hash = l.hash
            ; s3_data_hash = l.s3_data_hash
            } )
    }
  in
  let json : Yojson.Safe.t =
    `Assoc
      [ ("daemon", Mina_compile_config.to_yojson x.compile_config)
      ; ("genesis", Genesis_constants.to_yojson x.genesis_constants)
      ; ( "proof"
        , Genesis_constants.Constraint_constants.to_yojson
            x.constraint_config.constraint_constants )
      ; ("ledger", Json_layout.Ledger.to_yojson @@ f x.ledger)
      ; ( "epoch_data"
        , Option.value_map ~default:`Null ~f:Json_layout.Epoch_data.to_yojson
            (Option.map ~f:g x.epoch_data) )
      ]
  in
  ( json
  , `Accounts_omitted
      (`Genesis genesis_accounts, `Staking staking_accounts, `Next next_accounts)
  )

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
    ~next_epoch_seed ~genesis_constants ~(constraint_config : Constraint.t)
    ~compile_config =
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
    Genesis_constants.Fork_constants.
      { state_hash
      ; blockchain_length = Mina_numbers.Length.of_int blockchain_length
      ; global_slot_since_genesis =
          Mina_numbers.Global_slot_since_genesis.of_int
            global_slot_since_genesis
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
  { (* add_genesis_winner must be set to false, because this
       config effectively creates a continuation of the current
       blockchain state and therefore the genesis ledger already
       contains the winner of the previous block. No need to
       artificially add it. In fact, it wouldn't work at all,
       because the new node would try to create this account at
       startup, even though it already exists, leading to an error.*)
    epoch_data = Some epoch_data
  ; ledger =
      { Ledger.base = Accounts accounts
      ; num_accounts = None
      ; balances = []
      ; hash
      ; s3_data_hash = None
      ; name = None
      ; add_genesis_winner = Some false
      }
  ; constraint_config =
      { constraint_config with
        constraint_constants =
          { constraint_config.constraint_constants with fork = Some fork }
      }
  ; genesis_constants
  ; compile_config
  }

module type Config_loader = sig
  val load_config :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> t Deferred.Or_error.t

  val load_config_exn :
       ?itn_features:bool
    -> ?cli_proof_level:Genesis_constants.Proof_level.t
    -> config_file:string
    -> unit
    -> t Deferred.t

  val of_json_layout : Json_layout.t -> (t, string) Result.t
end

module Config_loader : Config_loader = struct
  let load_config_json filename : Json_layout.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let%bind json =
      Monitor.try_with_or_error (fun () ->
          Deferred.map ~f:Yojson.Safe.from_string
          @@ Reader.file_contents filename )
    in
    match Json_layout.of_yojson json with
    | Ok config ->
        Deferred.Or_error.return config
    | Error e ->
        Deferred.Or_error.error_string e

  let of_json_layout (config : Json_layout.t) : (t, string) result =
    let open Result.Let_syntax in
    let constraint_config = Constraint.of_json_layout config.proof in
    let genesis_constants = Genesis_constants.make config.genesis in
    let compile_config = Mina_compile_config.make config.daemon in
    let%bind ledger = Ledger.of_json_layout config.ledger in
    let%map epoch_data =
      match config.epoch_data with
      | None ->
          Ok None
      | Some conf ->
          Epoch_data.of_json_layout conf |> Result.map ~f:Option.some
    in
    { constraint_config; genesis_constants; compile_config; ledger; epoch_data }

  let load_config ?(itn_features = false) ?cli_proof_level ~config_file () =
    let open Deferred.Or_error.Let_syntax in
    let%bind config = load_config_json config_file in
    let e_config = of_json_layout config in
    match e_config with
    | Ok config ->
        let { Constraint.proof_level; _ } = config.constraint_config in
        Deferred.Or_error.return
          { config with
            constraint_config =
              { config.constraint_config with
                proof_level = Option.value ~default:proof_level cli_proof_level
              }
          ; compile_config = { config.compile_config with itn_features }
          }
    | Error e ->
        Deferred.Or_error.error_string e

  let load_config_exn ?itn_features ?cli_proof_level ~config_file () =
    Deferred.Or_error.ok_exn
    @@ load_config ?itn_features ?cli_proof_level ~config_file ()
end
