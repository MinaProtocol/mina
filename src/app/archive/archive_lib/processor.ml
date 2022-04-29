(* processor.ml -- database processing for archive node *)

module Archive_rpc = Rpc
open Async
open Core
open Caqti_async
open Mina_base
open Mina_transaction
open Mina_state
open Mina_transition
open Pipe_lib
open Signature_lib
open Pickles_types

let applied_str = "applied"

let failed_str = "failed"

module Public_key = struct
  let find (module Conn : CONNECTION) (t : Public_key.Compressed.t) =
    let public_key = Public_key.Compressed.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "SELECT id FROM public_keys WHERE value = ?")
      public_key

  let find_opt (module Conn : CONNECTION) (t : Public_key.Compressed.t) =
    let public_key = Public_key.Compressed.to_base58_check t in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM public_keys WHERE value = ?")
      public_key

  let find_by_id (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         "SELECT value FROM public_keys WHERE id = ?")
      id

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Public_key.Compressed.t) =
    let open Deferred.Result.Let_syntax in
    match%bind find_opt (module Conn) t with
    | Some id ->
        return id
    | None ->
        let public_key = Public_key.Compressed.to_base58_check t in
        Conn.find
          (Caqti_request.find Caqti_type.string Caqti_type.int
             "INSERT INTO public_keys (value) VALUES (?) RETURNING id")
          public_key
end

module Zkapp_state_data = struct
  let table_name = "zkapp_state_data"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fp : Pickles.Backend.Tick.Field.t) =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "field" ], Caqti_type.string)
      (module Conn)
      (Pickles.Backend.Tick.Field.to_string fp)

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "field" ]))
      id
end

module Zkapp_state_data_array = struct
  let table_name = "zkapp_state_data_array"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : Pickles.Backend.Tick.Field.t array) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int array) =
      Mina_caqti.deferred_result_list_map (Array.to_list fps)
        ~f:(Zkapp_state_data.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "element_ids" ], Mina_caqti.array_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      element_ids

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Mina_caqti.array_int_typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "element_ids" ]))
      id
end

module Zkapp_states = struct
  let table_name = "zkapp_states"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t option, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int option array) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps)
        ~f:
          ( Mina_caqti.add_if_some
          @@ Zkapp_state_data.add_if_doesn't_exist (module Conn) )
      >>| Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "element_ids" ], Mina_caqti.array_nullable_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      element_ids

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Mina_caqti.array_nullable_int_typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "element_ids" ]))
      id
end

module Zkapp_sequence_states = struct
  let table_name = "zkapp_sequence_states"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int array) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps) ~f:(fun field ->
          Zkapp_state_data.add_if_doesn't_exist (module Conn) field)
      >>| Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "element_ids" ], Mina_caqti.array_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      element_ids

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Mina_caqti.array_int_typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "element_ids" ]))
      id
end

module Zkapp_verification_keys = struct
  type t = { verification_key : string; hash : string }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; string ]

  let table_name = "zkapp_verification_keys"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (vk :
        ( Pickles.Side_loaded.Verification_key.t
        , Pickles.Backend.Tick.Field.t )
        With_hash.t) =
    let verification_key =
      Binable.to_string
        (module Pickles.Side_loaded.Verification_key.Stable.Latest)
        vk.data
      |> Base64.encode_exn
    in
    let hash = Pickles.Backend.Tick.Field.to_string vk.hash in
    let value = { hash; verification_key } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_permissions = struct
  let auth_required_typ =
    let encode = function
      | Permissions.Auth_required.None ->
          "none"
      | Permissions.Auth_required.Either ->
          "either"
      | Permissions.Auth_required.Proof ->
          "proof"
      | Permissions.Auth_required.Signature ->
          "signature"
      | Permissions.Auth_required.Impossible ->
          "impossible"
    in
    let decode = function
      | "none" ->
          Result.return Permissions.Auth_required.None
      | "either" ->
          Result.return Permissions.Auth_required.Either
      | "proof" ->
          Result.return Permissions.Auth_required.Proof
      | "signature" ->
          Result.return Permissions.Auth_required.Signature
      | "impossible" ->
          Result.return Permissions.Auth_required.Impossible
      | s ->
          Result.Error (sprintf "Failed to decode: \"%s\"" s)
    in
    Caqti_type.enum ~encode ~decode "zkapp_auth_required_type"

  type t =
    { edit_state : Permissions.Auth_required.t
    ; send : Permissions.Auth_required.t
    ; receive : Permissions.Auth_required.t
    ; set_delegate : Permissions.Auth_required.t
    ; set_permissions : Permissions.Auth_required.t
    ; set_verification_key : Permissions.Auth_required.t
    ; set_zkapp_uri : Permissions.Auth_required.t
    ; edit_sequence_state : Permissions.Auth_required.t
    ; set_token_symbol : Permissions.Auth_required.t
    ; increment_nonce : Permissions.Auth_required.t
    ; set_voting_for : Permissions.Auth_required.t
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      [ auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ; auth_required_typ
      ]

  let table_name = "zkapp_permissions"

  let add_if_doesn't_exist (module Conn : CONNECTION) (perms : Permissions.t) =
    let value =
      { edit_state = perms.edit_state
      ; send = perms.send
      ; receive = perms.receive
      ; set_delegate = perms.set_delegate
      ; set_permissions = perms.set_permissions
      ; set_verification_key = perms.set_verification_key
      ; set_zkapp_uri = perms.set_zkapp_uri
      ; edit_sequence_state = perms.edit_sequence_state
      ; set_token_symbol = perms.set_token_symbol
      ; increment_nonce = perms.increment_nonce
      ; set_voting_for = perms.set_voting_for
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_timing_info = struct
  type t =
    { initial_minimum_balance : int64
    ; cliff_time : int64
    ; cliff_amount : int64
    ; vesting_period : int64
    ; vesting_increment : int64
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64; int64; int64; int64 ]

  let table_name = "zkapp_timing_info"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timing_info : Party.Update.Timing_info.t) =
    let initial_minimum_balance =
      timing_info.initial_minimum_balance |> Currency.Balance.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let cliff_time = timing_info.cliff_time |> Unsigned.UInt32.to_int64 in
    let cliff_amount =
      timing_info.cliff_amount |> Currency.Amount.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let vesting_period =
      timing_info.vesting_period |> Unsigned.UInt32.to_int64
    in
    let vesting_increment =
      timing_info.vesting_increment |> Currency.Amount.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let value =
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_updates = struct
  type t =
    { app_state_id : int
    ; delegate_id : int option
    ; verification_key_id : int option
    ; permissions_id : int option
    ; zkapp_uri : string option
    ; token_symbol : string option
    ; timing_id : int option
    ; voting_for : string option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int
        ; option int
        ; option int
        ; option int
        ; option string
        ; option string
        ; option int
        ; option string
        ]

  let table_name = "zkapp_updates"

  let add_if_doesn't_exist (module Conn : CONNECTION) (update : Party.Update.t)
      =
    let open Deferred.Result.Let_syntax in
    let%bind app_state_id =
      Vector.map ~f:Zkapp_basic.Set_or_keep.to_option update.app_state
      |> Zkapp_states.add_if_doesn't_exist (module Conn)
    in
    let%bind delegate_id =
      Mina_caqti.add_if_zkapp_set
        (Public_key.add_if_doesn't_exist (module Conn))
        update.delegate
    in
    let%bind verification_key_id =
      Mina_caqti.add_if_zkapp_set
        (Zkapp_verification_keys.add_if_doesn't_exist (module Conn))
        update.verification_key
    in
    let%bind permissions_id =
      Mina_caqti.add_if_zkapp_set
        (Zkapp_permissions.add_if_doesn't_exist (module Conn))
        update.permissions
    in
    let%bind timing_id =
      Mina_caqti.add_if_zkapp_set
        (Zkapp_timing_info.add_if_doesn't_exist (module Conn))
        update.timing
    in
    let zkapp_uri = Zkapp_basic.Set_or_keep.to_option update.zkapp_uri in
    let token_symbol = Zkapp_basic.Set_or_keep.to_option update.token_symbol in
    let voting_for =
      Option.map ~f:State_hash.to_base58_check
        (Zkapp_basic.Set_or_keep.to_option update.voting_for)
    in
    let value =
      { app_state_id
      ; delegate_id
      ; verification_key_id
      ; permissions_id
      ; zkapp_uri
      ; token_symbol
      ; timing_id
      ; voting_for
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_balance_bounds = struct
  type t = { balance_lower_bound : int64; balance_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_balance_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (balance_bounds :
        Currency.Balance.t Mina_base.Zkapp_precondition.Closed_interval.t) =
    let balance_lower_bound =
      balance_bounds.lower |> Currency.Balance.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let balance_upper_bound =
      balance_bounds.upper |> Currency.Balance.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let value = { balance_lower_bound; balance_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_nonce_bounds = struct
  type t = { nonce_lower_bound : int64; nonce_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_nonce_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (nonce_bounds :
        Mina_numbers.Account_nonce.t
        Mina_base.Zkapp_precondition.Closed_interval.t) =
    let nonce_lower_bound = Unsigned.UInt32.to_int64 nonce_bounds.lower in
    let nonce_upper_bound = Unsigned.UInt32.to_int64 nonce_bounds.upper in
    let value = { nonce_lower_bound; nonce_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_precondition_account = struct
  type t =
    { balance_id : int option
    ; nonce_id : int option
    ; receipt_chain_hash : string option
    ; public_key_id : int option
    ; delegate_id : int option
    ; state_id : int
    ; sequence_state_id : int option
    ; proved_state : bool option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ option int
        ; option int
        ; option string
        ; option int
        ; option int
        ; int
        ; option int
        ; option bool
        ]

  let table_name = "zkapp_precondition_accounts"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (acct : Zkapp_precondition.Account.t) =
    let open Deferred.Result.Let_syntax in
    let%bind balance_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_balance_bounds.add_if_doesn't_exist (module Conn))
        acct.balance
    in
    let%bind nonce_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_nonce_bounds.add_if_doesn't_exist (module Conn))
        acct.nonce
    in
    let%bind public_key_id =
      Mina_caqti.add_if_zkapp_check
        (Public_key.add_if_doesn't_exist (module Conn))
        acct.public_key
    in
    let%bind delegate_id =
      Mina_caqti.add_if_zkapp_check
        (Public_key.add_if_doesn't_exist (module Conn))
        acct.delegate
    in
    let%bind state_id =
      Vector.map ~f:Zkapp_basic.Or_ignore.to_option acct.state
      |> Zkapp_states.add_if_doesn't_exist (module Conn)
    in
    let%bind sequence_state_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_state_data.add_if_doesn't_exist (module Conn))
        acct.sequence_state
    in
    let receipt_chain_hash =
      Zkapp_basic.Or_ignore.to_option acct.receipt_chain_hash
      |> Option.map ~f:Kimchi_backend.Pasta.Basic.Fp.to_string
    in
    let proved_state = Zkapp_basic.Or_ignore.to_option acct.proved_state in
    let value =
      { balance_id
      ; nonce_id
      ; receipt_chain_hash
      ; public_key_id
      ; delegate_id
      ; state_id
      ; sequence_state_id
      ; proved_state
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_account_precondition = struct
  type t =
    { kind : Party.Account_precondition.Tag.t
    ; account_id : int option
    ; nonce : int64 option
    }
  [@@deriving fields, hlist]

  let zkapp_account_precondition_kind_typ =
    let encode = function
      | Party.Account_precondition.Tag.Full ->
          "full"
      | Party.Account_precondition.Tag.Nonce ->
          "nonce"
      | Party.Account_precondition.Tag.Accept ->
          "accept"
    in
    let decode = function
      | "full" ->
          Result.return Party.Account_precondition.Tag.Full
      | "nonce" ->
          Result.return Party.Account_precondition.Tag.Nonce
      | "accept" ->
          Result.return Party.Account_precondition.Tag.Accept
      | _ ->
          Result.failf "Failed to decode zkapp_account_precondition_kind_typ"
    in
    Caqti_type.enum "zkapp_account_precondition_type" ~encode ~decode

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ zkapp_account_precondition_kind_typ; option int; option int64 ]

  let table_name = "zkapp_account_precondition"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (account_precondition : Party.Account_precondition.t) =
    let open Deferred.Result.Let_syntax in
    let%bind account_id =
      match account_precondition with
      | Party.Account_precondition.Full acct ->
          Zkapp_precondition_account.add_if_doesn't_exist (module Conn) acct
          >>| Option.some
      | _ ->
          return None
    in
    let kind = Party.Account_precondition.tag account_precondition in
    let nonce =
      match account_precondition with
      | Party.Account_precondition.Nonce nonce ->
          Option.some @@ Unsigned.UInt32.to_int64 nonce
      | _ ->
          None
    in
    let value = { kind; account_id; nonce } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_token_id_bounds = struct
  type t = { token_id_lower_bound : string; token_id_upper_bound : string }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; string ]

  let table_name = "zkapp_token_id_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (token_id_bounds :
        Token_id.t Mina_base.Zkapp_precondition.Closed_interval.t) =
    let token_id_lower_bound = token_id_bounds.lower |> Token_id.to_string in
    let token_id_upper_bound = token_id_bounds.upper |> Token_id.to_string in
    let value = { token_id_lower_bound; token_id_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_timestamp_bounds = struct
  type t = { timestamp_lower_bound : int64; timestamp_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_timestamp_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timestamp_bounds :
        Block_time.t Mina_base.Zkapp_precondition.Closed_interval.t) =
    let timestamp_lower_bound = Block_time.to_int64 timestamp_bounds.lower in
    let timestamp_upper_bound = Block_time.to_int64 timestamp_bounds.upper in
    let value = { timestamp_lower_bound; timestamp_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_length_bounds = struct
  type t = { length_lower_bound : int64; length_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_length_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (length_bounds :
        Unsigned.uint32 Mina_base.Zkapp_precondition.Closed_interval.t) =
    let length_lower_bound = Unsigned.UInt32.to_int64 length_bounds.lower in
    let length_upper_bound = Unsigned.UInt32.to_int64 length_bounds.upper in
    let value = { length_lower_bound; length_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_amount_bounds = struct
  type t = { amount_lower_bound : int64; amount_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_amount_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (amount_bounds :
        Currency.Amount.t Mina_base.Zkapp_precondition.Closed_interval.t) =
    let amount_lower_bound =
      Currency.Amount.to_uint64 amount_bounds.lower |> Unsigned.UInt64.to_int64
    in
    let amount_upper_bound =
      Currency.Amount.to_uint64 amount_bounds.upper |> Unsigned.UInt64.to_int64
    in
    let value = { amount_lower_bound; amount_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_global_slot_bounds = struct
  type t = { global_slot_lower_bound : int64; global_slot_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int64; int64 ]

  let table_name = "zkapp_global_slot_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (global_slot_bounds :
        Mina_numbers.Global_slot.t
        Mina_base.Zkapp_precondition.Closed_interval.t) =
    let global_slot_lower_bound =
      Mina_numbers.Global_slot.to_uint32 global_slot_bounds.lower
      |> Unsigned.UInt32.to_int64
    in
    let global_slot_upper_bound =
      Mina_numbers.Global_slot.to_uint32 global_slot_bounds.upper
      |> Unsigned.UInt32.to_int64
    in
    let value = { global_slot_lower_bound; global_slot_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Timing_info = struct
  type t =
    { public_key_id : int
    ; token : string
    ; initial_balance : int64
    ; initial_minimum_balance : int64
    ; cliff_time : int64
    ; cliff_amount : int64
    ; vesting_period : int64
    ; vesting_increment : int64
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; string; int64; int64; int64; int64; int64; int64 ]

  let find (module Conn : CONNECTION) (acc : Account.t) =
    let open Deferred.Result.Let_syntax in
    let%bind pk_id = Public_key.find (module Conn) acc.public_key in
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         {sql| SELECT public_key_id, token, initial_balance,
                      initial_minimum_balance, cliff_time, cliff_amount,
                      vesting_period, vesting_increment
               FROM timing_info
               WHERE public_key_id = ?
         |sql})
      pk_id

  let find_by_pk_opt (module Conn : CONNECTION) public_key =
    let open Deferred.Result.Let_syntax in
    let%bind pk_id = Public_key.find (module Conn) public_key in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.int typ
         {sql| SELECT public_key_id, token, initial_balance,
                     initial_minimum_balance, cliff_time, cliff_amount,
                     vesting_period, vesting_increment
               FROM timing_info
               WHERE public_key_id = ?
         |sql})
      pk_id

  let add_if_doesn't_exist (module Conn : CONNECTION) (acc : Account.t) =
    let open Deferred.Result.Let_syntax in
    let amount_to_int64 x =
      Unsigned.UInt64.to_int64 (Currency.Amount.to_uint64 x)
    in
    let balance_to_int64 x = amount_to_int64 (Currency.Balance.to_amount x) in
    let slot_to_int64 x =
      Mina_numbers.Global_slot.to_uint32 x |> Unsigned.UInt32.to_int64
    in
    let%bind public_key_id =
      Public_key.add_if_doesn't_exist (module Conn) acc.public_key
    in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.int Caqti_type.int
           "SELECT id FROM timing_info WHERE public_key_id = ?")
        public_key_id
    with
    | Some id ->
        return id
    | None ->
        let values =
          let token = Token_id.to_string (Account.token acc) in
          match acc.timing with
          | Timed timing ->
              { public_key_id
              ; token
              ; initial_balance = balance_to_int64 acc.balance
              ; initial_minimum_balance =
                  balance_to_int64 timing.initial_minimum_balance
              ; cliff_time = slot_to_int64 timing.cliff_time
              ; cliff_amount = amount_to_int64 timing.cliff_amount
              ; vesting_period = slot_to_int64 timing.vesting_period
              ; vesting_increment = amount_to_int64 timing.vesting_increment
              }
          | Untimed ->
              let zero = Int64.zero in
              { public_key_id
              ; token
              ; initial_balance = balance_to_int64 acc.balance
              ; initial_minimum_balance = zero
              ; cliff_time = zero
              ; cliff_amount = zero
              ; vesting_period = zero
              ; vesting_increment = zero
              }
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO timing_info
                    (public_key_id,token,initial_balance,initial_minimum_balance,
                     cliff_time, cliff_amount, vesting_period, vesting_increment)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                   RETURNING id
             |sql})
          values
end

module Snarked_ledger_hash = struct
  let find (module Conn : CONNECTION) (t : Frozen_ledger_hash.t) =
    let hash = Frozen_ledger_hash.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "SELECT id FROM snarked_ledger_hashes WHERE value = ?")
      hash

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : Frozen_ledger_hash.t)
      =
    let open Deferred.Result.Let_syntax in
    let hash = Frozen_ledger_hash.to_base58_check t in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM snarked_ledger_hashes WHERE value = ?")
        hash
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find Caqti_type.string Caqti_type.int
             "INSERT INTO snarked_ledger_hashes (value) VALUES (?) RETURNING id")
          hash

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         "SELECT value FROM snarked_ledger_hashes WHERE id = ?")
      id
end

module Zkapp_epoch_ledger = struct
  type t = { hash_id : int option; total_currency_id : int option }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ option int; option int ]

  let table_name = "zkapp_epoch_ledger"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (epoch_ledger : _ Epoch_ledger.Poly.t) =
    let open Deferred.Result.Let_syntax in
    let%bind hash_id =
      Mina_caqti.add_if_zkapp_check
        (Snarked_ledger_hash.add_if_doesn't_exist (module Conn))
        epoch_ledger.hash
    in
    let%bind total_currency_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_amount_bounds.add_if_doesn't_exist (module Conn))
        epoch_ledger.total_currency
    in
    let value = { hash_id; total_currency_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_epoch_data = struct
  type t =
    { epoch_ledger_id : int
    ; epoch_seed : string option
    ; start_checkpoint : string option
    ; lock_checkpoint : string option
    ; epoch_length_id : int option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int; option string; option string; option string; option int ]

  let table_name = "zkapp_epoch_data"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (epoch_data : Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.t) =
    let open Deferred.Result.Let_syntax in
    let%bind epoch_ledger_id =
      Zkapp_epoch_ledger.add_if_doesn't_exist (module Conn) epoch_data.ledger
    in
    let%bind epoch_length_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_length_bounds.add_if_doesn't_exist (module Conn))
        epoch_data.epoch_length
    in
    let epoch_seed =
      Zkapp_basic.Or_ignore.to_option epoch_data.seed
      |> Option.map ~f:Kimchi_backend.Pasta.Basic.Fp.to_string
    in
    let start_checkpoint =
      Zkapp_basic.Or_ignore.to_option epoch_data.start_checkpoint
      |> Option.map ~f:Kimchi_backend.Pasta.Basic.Fp.to_string
    in
    let lock_checkpoint =
      Zkapp_basic.Or_ignore.to_option epoch_data.lock_checkpoint
      |> Option.map ~f:Kimchi_backend.Pasta.Basic.Fp.to_string
    in
    let value =
      { epoch_ledger_id
      ; epoch_seed
      ; start_checkpoint
      ; lock_checkpoint
      ; epoch_length_id
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_protocol_state_precondition = struct
  type t =
    { snarked_ledger_hash_id : int option
    ; timestamp_id : int option
    ; blockchain_length_id : int option
    ; min_window_density_id : int option
    ; total_currency_id : int option
    ; curr_global_slot_since_hard_fork : int option
    ; global_slot_since_genesis : int option
    ; staking_epoch_data_id : int
    ; next_epoch_data_id : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; int
        ; int
        ]

  let table_name = "zkapp_protocol_state_precondition"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (ps : Mina_base.Zkapp_precondition.Protocol_state.t) =
    let open Deferred.Result.Let_syntax in
    let%bind snarked_ledger_hash_id =
      Mina_caqti.add_if_zkapp_check
        (Snarked_ledger_hash.add_if_doesn't_exist (module Conn))
        ps.snarked_ledger_hash
    in
    let%bind timestamp_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_timestamp_bounds.add_if_doesn't_exist (module Conn))
        ps.timestamp
    in
    let%bind blockchain_length_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_length_bounds.add_if_doesn't_exist (module Conn))
        ps.blockchain_length
    in
    let%bind min_window_density_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_length_bounds.add_if_doesn't_exist (module Conn))
        ps.min_window_density
    in
    let%bind total_currency_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_amount_bounds.add_if_doesn't_exist (module Conn))
        ps.total_currency
    in
    let%bind curr_global_slot_since_hard_fork =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_global_slot_bounds.add_if_doesn't_exist (module Conn))
        ps.global_slot_since_hard_fork
    in
    let%bind global_slot_since_genesis =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_global_slot_bounds.add_if_doesn't_exist (module Conn))
        ps.global_slot_since_genesis
    in
    let%bind staking_epoch_data_id =
      Zkapp_epoch_data.add_if_doesn't_exist (module Conn) ps.staking_epoch_data
    in
    let%bind next_epoch_data_id =
      Zkapp_epoch_data.add_if_doesn't_exist (module Conn) ps.next_epoch_data
    in
    let value =
      { snarked_ledger_hash_id
      ; timestamp_id
      ; blockchain_length_id
      ; min_window_density_id
      ; total_currency_id
      ; curr_global_slot_since_hard_fork
      ; global_slot_since_genesis
      ; staking_epoch_data_id
      ; next_epoch_data_id
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_party_body = struct
  type t =
    { public_key_id : int
    ; update_id : int
    ; token_id : string
    ; balance_change : int64
    ; increment_nonce : bool
    ; events_ids : int array
    ; sequence_events_ids : int array
    ; call_data_id : int
    ; call_depth : int
    ; zkapp_protocol_state_precondition_id : int
    ; zkapp_account_precondition_id : int
    ; use_full_commitment : bool
    ; caller : string
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int
        ; int
        ; string
        ; int64
        ; bool
        ; Mina_caqti.array_int_typ
        ; Mina_caqti.array_int_typ
        ; int
        ; int
        ; int
        ; int
        ; bool
        ; string
        ]

  let table_name = "zkapp_party_body"

  let add_if_doesn't_exist (module Conn : CONNECTION) (body : Party.Body.t) =
    let open Deferred.Result.Let_syntax in
    let%bind public_key_id =
      Public_key.add_if_doesn't_exist (module Conn) body.public_key
    in
    let%bind update_id =
      Zkapp_updates.add_if_doesn't_exist (module Conn) body.update
    in
    let increment_nonce = body.increment_nonce in
    let%bind events_ids =
      Mina_caqti.deferred_result_list_map body.events
        ~f:(Zkapp_state_data_array.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    let%bind sequence_events_ids =
      Mina_caqti.deferred_result_list_map body.sequence_events
        ~f:(Zkapp_state_data_array.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    let%bind call_data_id =
      Zkapp_state_data.add_if_doesn't_exist (module Conn) body.call_data
    in
    let%bind zkapp_protocol_state_precondition_id =
      Zkapp_protocol_state_precondition.add_if_doesn't_exist
        (module Conn)
        body.protocol_state_precondition
    in
    let%bind zkapp_account_precondition_id =
      Zkapp_account_precondition.add_if_doesn't_exist
        (module Conn)
        body.account_precondition
    in
    let token_id = Token_id.to_string body.token_id in
    let balance_change =
      let magnitude =
        Currency.Amount.to_uint64 body.balance_change.magnitude
        |> Unsigned.UInt64.to_int64
      in
      match body.balance_change.sgn with
      | Sgn.Pos ->
          magnitude
      | Sgn.Neg ->
          Int64.neg magnitude
    in
    let call_depth = body.call_depth in
    let use_full_commitment = body.use_full_commitment in
    let caller = Token_id.to_string body.caller in
    let value =
      { public_key_id
      ; update_id
      ; token_id
      ; balance_change
      ; increment_nonce
      ; events_ids
      ; sequence_events_ids
      ; call_data_id
      ; call_depth
      ; zkapp_protocol_state_precondition_id
      ; zkapp_account_precondition_id
      ; use_full_commitment
      ; caller
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      ~tannot:(function
        | "events_ids" | "sequence_events_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_party = struct
  type t = { body_id : int; authorization_kind : Control.Tag.t }
  [@@deriving fields, hlist]

  let authorization_kind_typ =
    let encode = function
      | Control.Tag.Proof ->
          "proof"
      | Control.Tag.Signature ->
          "signature"
      | Control.Tag.None_given ->
          "none_given"
    in
    let decode = function
      | "proof" ->
          Result.return Control.Tag.Proof
      | "signature" ->
          Result.return Control.Tag.Signature
      | "none_given" ->
          Result.return Control.Tag.None_given
      | _ ->
          Result.failf "Failed to decode authorization_kind_typ"
    in
    Caqti_type.enum "zkapp_authorization_kind_type" ~encode ~decode

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; authorization_kind_typ ]

  let table_name = "zkapp_party"

  let add_if_doesn't_exist (module Conn : CONNECTION) (party : Party.t) =
    let open Deferred.Result.Let_syntax in
    let%bind body_id =
      Zkapp_party_body.add_if_doesn't_exist (module Conn) party.body
    in
    let authorization_kind = Control.tag party.authorization in
    let value = { body_id; authorization_kind } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Zkapp_fee_payers = struct
  type t = { body_id : int } [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist Caqti_type.[ int ]

  let table_name = "zkapp_fee_payers"

  let add_if_doesn't_exist (module Conn : CONNECTION) (fp : Party.Fee_payer.t) =
    let open Deferred.Result.Let_syntax in
    let%bind body_id =
      Zkapp_party_body.add_if_doesn't_exist
        (module Conn)
        (Party.Body.of_fee_payer fp.body)
    in
    let value = { body_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names))
      id
end

module Epoch_data = struct
  type t =
    { seed : string
    ; ledger_hash_id : int
    ; total_currency : int64
    ; start_checkpoint : string
    ; lock_checkpoint : string
    ; epoch_length : int64
    }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; int; int64; string; string; int64 ]

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Mina_base.Epoch_data.Value.t) =
    let open Deferred.Result.Let_syntax in
    let Mina_base.Epoch_ledger.Poly.{ hash; total_currency } =
      Mina_base.Epoch_data.Poly.ledger t
    in
    let%bind ledger_hash_id =
      Snarked_ledger_hash.add_if_doesn't_exist (module Conn) hash
    in
    let seed = t.seed |> Epoch_seed.to_base58_check in
    let total_currency =
      total_currency |> Currency.Amount.to_uint64 |> Unsigned.UInt64.to_int64
    in
    let start_checkpoint = t.start_checkpoint |> State_hash.to_base58_check in
    let lock_checkpoint = t.lock_checkpoint |> State_hash.to_base58_check in
    let epoch_length =
      t.epoch_length |> Mina_numbers.Length.to_uint32
      |> Unsigned.UInt32.to_int64
    in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt typ Caqti_type.int
           {sql| SELECT id FROM epoch_data
                 WHERE seed = $1
                 AND ledger_hash_id = $2
                 AND total_currency = $3
                 AND start_checkpoint = $4
                 AND lock_checkpoint = $5
                 AND epoch_length = $6
           |sql})
        { seed
        ; ledger_hash_id
        ; total_currency
        ; start_checkpoint
        ; lock_checkpoint
        ; epoch_length
        }
    with
    | Some id ->
        return id
    | None ->
        Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
          ~table_name:"epoch_data" ~cols:(Fields.names, typ)
          (module Conn)
          { seed
          ; ledger_hash_id
          ; total_currency
          ; start_checkpoint
          ; lock_checkpoint
          ; epoch_length
          }

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name:"epoch_data"
            ~cols:Fields.names))
      id
end

module User_command = struct
  module Signed_command = struct
    type t =
      { typ : string
      ; fee_payer_id : int
      ; source_id : int
      ; receiver_id : int
      ; fee_token : string
      ; token : string
      ; nonce : int
      ; amount : int64 option
      ; fee : int64
      ; valid_until : int64 option
      ; memo : string
      ; hash : string
      }
    [@@deriving hlist]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.
          [ string
          ; int
          ; int
          ; int
          ; string
          ; string
          ; int
          ; option int64
          ; int64
          ; option int64
          ; string
          ; string
          ]

    let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
        =
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM user_commands WHERE hash = ?")
        (Transaction_hash.to_base58_check transaction_hash)

    let load (module Conn : CONNECTION) ~(id : int) =
      Conn.find
        (Caqti_request.find Caqti_type.int typ
           {sql| SELECT type,fee_payer_id,source_id,receiver_id,
                 fee_token,token,
                 nonce,amount,fee,valid_until,memo,hash
                 FROM user_commands
                 WHERE id = ?
           |sql})
        id

    type balance_public_key_ids =
      { fee_payer_id : int; source_id : int; receiver_id : int }

    let add_balance_public_keys_if_don't_exist (module Conn : CONNECTION)
        (t : Signed_command.t) =
      let open Deferred.Result.Let_syntax in
      let%bind fee_payer_id =
        Public_key.add_if_doesn't_exist
          (module Conn)
          (Signed_command.fee_payer_pk t)
      in
      let%bind source_id =
        Public_key.add_if_doesn't_exist
          (module Conn)
          (Signed_command.source_pk t)
      in
      let%map receiver_id =
        Public_key.add_if_doesn't_exist
          (module Conn)
          (Signed_command.receiver_pk t)
      in
      { fee_payer_id; source_id; receiver_id }

    let add_if_doesn't_exist ?(via = `Ident) (module Conn : CONNECTION)
        (t : Signed_command.t) =
      let open Deferred.Result.Let_syntax in
      let transaction_hash = Transaction_hash.hash_command (Signed_command t) in
      match%bind find (module Conn) ~transaction_hash with
      | Some user_command_id ->
          return user_command_id
      | None ->
          let%bind { fee_payer_id; source_id; receiver_id } =
            add_balance_public_keys_if_don't_exist (module Conn) t
          in
          let valid_until =
            let open Mina_numbers in
            let slot = Signed_command.valid_until t in
            if Global_slot.equal slot Global_slot.max_value then None
            else
              Some
                ( slot |> Mina_numbers.Global_slot.to_uint32
                |> Unsigned.UInt32.to_int64 )
          in
          (* TODO: Converting these uint64s to int64 can overflow; see #5419 *)
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               {sql| INSERT INTO user_commands (type, fee_payer_id, source_id,
                      receiver_id, fee_token, token, nonce, amount, fee,
                      valid_until, memo, hash)
                    VALUES (?::user_command_type, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    RETURNING id |sql})
            { typ =
                ( match via with
                | `Ident ->
                    Signed_command.tag_string t
                | `Parties ->
                    "zkapp" )
            ; fee_payer_id
            ; source_id
            ; receiver_id
            ; fee_token = Signed_command.fee_token t |> Token_id.to_string
            ; token = Signed_command.token t |> Token_id.to_string
            ; nonce = Signed_command.nonce t |> Unsigned.UInt32.to_int
            ; amount =
                Signed_command.amount t
                |> Core.Option.map ~f:(fun amt ->
                       Currency.Amount.to_uint64 amt |> Unsigned.UInt64.to_int64)
            ; fee =
                ( Signed_command.fee t
                |> fun amt ->
                Currency.Fee.to_uint64 amt |> Unsigned.UInt64.to_int64 )
            ; valid_until
            ; memo =
                Signed_command.memo t |> Signed_command_memo.to_base58_check
            ; hash = transaction_hash |> Transaction_hash.to_base58_check
            }
  end

  module Zkapp_command = struct
    type t =
      { zkapp_fee_payer_id : int
      ; zkapp_other_parties_ids : int array
      ; hash : string
      }
    [@@deriving fields, hlist]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ int; Mina_caqti.array_int_typ; string ]

    let find_opt (module Conn : CONNECTION)
        ~(transaction_hash : Transaction_hash.t) =
      Conn.find_opt
        ( Caqti_request.find_opt Caqti_type.string Caqti_type.int
        @@ Mina_caqti.select_cols ~select:"id" ~table_name:"zkapp_commands"
             [ "hash" ] )
        (Transaction_hash.to_base58_check transaction_hash)

    let add_if_doesn't_exist (module Conn : CONNECTION) (ps : Parties.t) =
      let open Deferred.Result.Let_syntax in
      let%bind zkapp_fee_payer_id =
        Zkapp_fee_payers.add_if_doesn't_exist (module Conn) ps.fee_payer
      in
      let%bind zkapp_other_parties_ids =
        Mina_caqti.deferred_result_list_map
          (Parties.Call_forest.to_parties_list ps.other_parties)
          ~f:(Zkapp_party.add_if_doesn't_exist (module Conn))
        >>| Array.of_list
      in
      let hash =
        Transaction_hash.hash_command (Parties ps)
        |> Transaction_hash.to_base58_check
      in
      let value = { zkapp_fee_payer_id; zkapp_other_parties_ids; hash } in
      Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
        ~table_name:"zkapp_commands" ~cols:(Fields.names, typ)
        ~tannot:(function
          | "zkapp_other_parties_ids" -> Some "int[]" | _ -> None)
        (module Conn)
        value
  end

  let as_signed_command (t : User_command.t) : Mina_base.Signed_command.t =
    match t with
    | Signed_command c ->
        c
    | Parties _ ->
        let `Needs_some_work_for_zkapps_on_mainnet =
          Mina_base.Util.todo_zkapps
        in
        failwith "TODO"

  let via (t : User_command.t) : [ `Parties | `Ident ] =
    match t with Signed_command _ -> `Ident | Parties _ -> `Parties

  let add_if_doesn't_exist conn (t : User_command.t) =
    match t with
    | Signed_command sc ->
        Signed_command.add_if_doesn't_exist conn ~via:(via t) sc
    | Parties ps ->
        Zkapp_command.add_if_doesn't_exist conn ps

  let find conn ~(transaction_hash : Transaction_hash.t) =
    let open Deferred.Result.Let_syntax in
    let%bind signed_command_id =
      Signed_command.find conn ~transaction_hash
      >>| Option.map ~f:(fun id -> `Signed_command_id id)
    in
    let%map zkapp_command_id =
      Zkapp_command.find_opt conn ~transaction_hash
      >>| Option.map ~f:(fun id -> `Zkapp_command_id id)
    in
    Option.first_some signed_command_id zkapp_command_id

  (* meant to work with either a signed command, or a zkapp *)
  let add_extensional (module Conn : CONNECTION)
      (user_cmd : Extensional.User_command.t) =
    let amount_opt_to_int64_opt amt_opt =
      Option.map amt_opt
        ~f:(Fn.compose Unsigned.UInt64.to_int64 Currency.Amount.to_uint64)
    in
    let open Deferred.Result.Let_syntax in
    let%bind fee_payer_id =
      Public_key.add_if_doesn't_exist (module Conn) user_cmd.fee_payer
    in
    let%bind source_id =
      Public_key.add_if_doesn't_exist (module Conn) user_cmd.source
    in
    let%bind receiver_id =
      Public_key.add_if_doesn't_exist (module Conn) user_cmd.receiver
    in
    Conn.find
      (Caqti_request.find Signed_command.typ Caqti_type.int
         {sql| INSERT INTO user_commands (type, fee_payer_id, source_id,
                      receiver_id, fee_token, token, nonce, amount, fee,
                      valid_until, memo, hash)
                    VALUES (?::user_command_type, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    RETURNING id
         |sql})
      { typ = user_cmd.typ
      ; fee_payer_id
      ; source_id
      ; receiver_id
      ; fee_token = user_cmd.fee_token |> Token_id.to_string
      ; token = user_cmd.token |> Token_id.to_string
      ; nonce = user_cmd.nonce |> Unsigned.UInt32.to_int
      ; amount = user_cmd.amount |> amount_opt_to_int64_opt
      ; fee =
          user_cmd.fee
          |> Fn.compose Unsigned.UInt64.to_int64 Currency.Fee.to_uint64
      ; valid_until =
          Option.map user_cmd.valid_until
            ~f:
              (Fn.compose Unsigned.UInt32.to_int64
                 Mina_numbers.Global_slot.to_uint32)
      ; memo = user_cmd.memo |> Signed_command_memo.to_base58_check
      ; hash = user_cmd.hash |> Transaction_hash.to_base58_check
      }

  let add_extensional_if_doesn't_exist (module Conn : CONNECTION)
      (user_cmd : Extensional.User_command.t) =
    let open Deferred.Result.Let_syntax in
    match%bind find (module Conn) ~transaction_hash:user_cmd.hash with
    | None ->
        add_extensional (module Conn) user_cmd
    | Some (`Signed_command_id user_cmd_id) ->
        return user_cmd_id
    | Some (`Zkapp_command_id _user_cmd_id) ->
        failwith "Unexpected zkapp command"
end

module Internal_command = struct
  type t =
    { typ : string
    ; receiver_id : int
    ; fee : int64
    ; token : string
    ; hash : string
    }

  let typ =
    let encode t = Ok ((t.typ, t.receiver_id, t.fee, t.token), t.hash) in
    let decode ((typ, receiver_id, fee, token), hash) =
      Ok { typ; receiver_id; fee; token; hash }
    in
    let rep = Caqti_type.(tup2 (tup4 string int int64 string) string) in
    Caqti_type.custom ~encode ~decode rep

  let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
      ~(typ : string) =
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup2 string string)
         Caqti_type.int
         "SELECT id FROM internal_commands WHERE hash = $1 AND type = \
          $2::internal_command_type")
      (Transaction_hash.to_base58_check transaction_hash, typ)

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         {sql| SELECT type,receiver_id,fee,token,hash
               FROM internal_commands
               WHERE id = ?
         |sql})
      id

  let add_extensional_if_doesn't_exist (module Conn : CONNECTION)
      (internal_cmd : Extensional.Internal_command.t) =
    let open Deferred.Result.Let_syntax in
    match%bind
      find
        (module Conn)
        ~transaction_hash:internal_cmd.hash ~typ:internal_cmd.typ
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist (module Conn) internal_cmd.receiver
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO internal_commands
                    (type, receiver_id, fee, token,hash)
                   VALUES (?::internal_command_type, ?, ?, ?, ?)
                   RETURNING id
             |sql})
          { typ = internal_cmd.typ
          ; receiver_id
          ; fee =
              internal_cmd.fee |> Currency.Fee.to_uint64
              |> Unsigned.UInt64.to_int64
          ; token = internal_cmd.token |> Token_id.to_string
          ; hash = internal_cmd.hash |> Transaction_hash.to_base58_check
          }
end

module Fee_transfer = struct
  module Kind = struct
    type t = [ `Normal | `Via_coinbase ]

    let to_string : t -> string = function
      | `Normal ->
          "fee_transfer"
      | `Via_coinbase ->
          "fee_transfer_via_coinbase"
  end

  type t =
    { kind : Kind.t
    ; receiver_id : int
    ; fee : int64
    ; token : string
    ; hash : string
    }

  let typ =
    let encode t =
      let kind = Kind.to_string t.kind in
      Ok ((kind, t.receiver_id, t.fee, t.token), t.hash)
    in
    let decode ((kind, receiver_id, fee, token), hash) =
      let open Result.Let_syntax in
      let%bind kind =
        match kind with
        | "fee_transfer" ->
            return `Normal
        | "fee_transfer_via_coinbase" ->
            return `Via_coinbase
        | s ->
            Result.fail (sprintf "Bad kind %s in decode attempt" s)
      in
      Ok { kind; receiver_id; fee; token; hash }
    in
    let rep = Caqti_type.(tup2 (tup4 string int int64 string) string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Fee_transfer.Single.t) (kind : [ `Normal | `Via_coinbase ]) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_fee_transfer t in
    match%bind
      Internal_command.find
        (module Conn)
        ~transaction_hash ~typ:(Kind.to_string kind)
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Fee_transfer.Single.receiver_pk t)
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO internal_commands
                    (type, receiver_id, fee, token, hash)
                   VALUES (?::internal_command_type, ?, ?, ?, ?)
                   RETURNING id
             |sql})
          { kind
          ; receiver_id
          ; fee =
              Fee_transfer.Single.fee t |> Currency.Fee.to_uint64
              |> Unsigned.UInt64.to_int64
          ; token = Token_id.to_string t.fee_token
          ; hash = transaction_hash |> Transaction_hash.to_base58_check
          }
end

module Coinbase = struct
  type t = { receiver_id : int; amount : int64; hash : string }

  let coinbase_typ = "coinbase"

  let typ =
    let encode t =
      Ok
        ( (coinbase_typ, t.receiver_id, t.amount, Token_id.(to_string default))
        , t.hash )
    in
    let decode ((_, receiver_id, amount, _), hash) =
      Ok { receiver_id; amount; hash }
    in
    let rep = Caqti_type.(tup2 (tup4 string int int64 string) string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : Coinbase.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_coinbase t in
    match%bind
      Internal_command.find (module Conn) ~transaction_hash ~typ:coinbase_typ
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist (module Conn) (Coinbase.receiver_pk t)
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO internal_commands
                    (type, receiver_id, fee, token, hash)
                   VALUES (?::internal_command_type, ?, ?, ?, ?)
                   RETURNING id
             |sql})
          { receiver_id
          ; amount =
              Coinbase.amount t |> Currency.Amount.to_uint64
              |> Unsigned.UInt64.to_int64
          ; hash = transaction_hash |> Transaction_hash.to_base58_check
          }
end

module Find_nonce = struct
  let sql_template public_keys_sql_list =
    (* using a string containing the comma-delimited public keys list as an SQL parameter results
       in syntax errors, so we inline that list into the query
    *)
    sprintf
      {sql|
SELECT t.pk_id, MAX(pk), MAX(t.height) as height, MAX(t.nonce) AS nonce FROM
(
WITH RECURSIVE pending_chain_nonce AS (

               (SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                FROM blocks b
                WHERE id = $1
                LIMIT 1)

                UNION ALL

                SELECT b.id, b.state_hash, b.parent_id, b.height, b.global_slot_since_genesis, b.timestamp, b.chain_status

                FROM blocks b
                INNER JOIN pending_chain_nonce
                ON b.id = pending_chain_nonce.parent_id AND pending_chain_nonce.id <> pending_chain_nonce.parent_id
                AND pending_chain_nonce.chain_status <> 'canonical'

               )

              /* Slot and balance are NULL here */
              SELECT pks.id AS pk_id,pks.value AS pk,full_chain.height,cmds.nonce

              FROM (SELECT
                    id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status
                    FROM pending_chain_nonce

                    UNION ALL

                    SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                    FROM blocks b
                    WHERE chain_status = 'canonical') AS full_chain

              INNER JOIN blocks_user_commands busc ON busc.block_id = full_chain.id
              INNER JOIN user_commands        cmds ON cmds.id = busc.user_command_id
              INNER JOIN public_keys          pks  ON pks.id = cmds.source_id

              WHERE pks.value IN (%s)
              AND busc.user_command_id = cmds.id

              ORDER BY (full_chain.height, busc.sequence_no) DESC
            ) t
            GROUP BY t.pk_id LIMIT $2
    |sql}
      public_keys_sql_list

  type t =
    { public_key_id : int; public_key : string; height : int; nonce : int64 }
  [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int; string; int; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let collect (module Conn : CONNECTION) ~public_keys ~parent_id =
    if List.is_empty public_keys then
      (* SQL query would fail, because `IN ()` is invalid syntax *)
      return @@ Ok []
    else
      let public_keys_sql_list =
        public_keys
        |> List.map ~f:(fun pk ->
               sprintf "'%s'"
                 (Signature_lib.Public_key.Compressed.to_base58_check pk))
        |> String.concat ~sep:","
      in
      Conn.collect_list
        (Caqti_request.collect
           Caqti_type.(tup2 int int)
           typ
           (sql_template public_keys_sql_list))
        (parent_id, List.length public_keys)

  (* INVARIANT: The map is populated with all the public_keys present *)
  let initialize_nonce_map (module Conn : CONNECTION) ~public_keys ~parent_id =
    let open Deferred.Result.Let_syntax in
    let%map ts = collect (module Conn) ~public_keys ~parent_id in
    let alist =
      List.map ts ~f:(fun t ->
          ( Signature_lib.Public_key.Compressed.of_base58_check_exn t.public_key
          , Account.Nonce.of_uint32 Unsigned.UInt32.(of_int64 t.nonce |> succ)
          ))
    in
    let map = Signature_lib.Public_key.Compressed.Map.of_alist_exn alist in
    List.fold public_keys ~init:map ~f:(fun map key ->
        match
          Signature_lib.Public_key.Compressed.Map.add map ~key
            ~data:Account.Nonce.zero
        with
        | `Ok map' ->
            map'
        | `Duplicate ->
            map)
end

module Balance = struct
  type t =
    { id : int
    ; public_key_id : int
    ; balance : int64
    ; block_id : int
    ; block_height : int64
    ; block_sequence_no : int
    ; block_secondary_sequence_no : int
    ; nonce : int64 option
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int64; int; int64; int; int; option int64 ]

  let balance_to_int64 (balance : Currency.Balance.t) : int64 =
    balance |> Currency.Balance.to_amount |> Currency.Amount.to_uint64
    |> Unsigned.UInt64.to_int64

  let find (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) ~block_id ~block_height ~block_sequence_no
      ~block_secondary_sequence_no =
    (* TODO: Do we need to query with the nonce here? *)
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup2 (tup2 int int64) (tup4 int int64 int int))
         Caqti_type.int
         {sql| SELECT id FROM balances
               WHERE public_key_id = $1
               AND balance = $2
               AND block_id = $3
               AND block_height = $4
               AND block_sequence_no = $5
               AND block_secondary_sequence_no = $6
         |sql})
      ( (public_key_id, balance_to_int64 balance)
      , (block_id, block_height, block_sequence_no, block_secondary_sequence_no)
      )

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         {sql| SELECT id, public_key_id, balance,
                      block_id, block_height,
                      block_sequence_no, block_secondary_sequence_no, nonce
               FROM balances
               WHERE id = $1
         |sql})
      id

  let add (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) ~block_id ~block_height ~block_sequence_no
      ~block_secondary_sequence_no ~nonce =
    Conn.find
      (Caqti_request.find
         Caqti_type.(
           tup2 (tup2 int int64) (tup4 int int64 (tup2 int int) (option int64)))
         Caqti_type.int
         {sql| INSERT INTO balances (public_key_id, balance,
                                     block_id, block_height, block_sequence_no, block_secondary_sequence_no, nonce)
               VALUES (?, ?, ?, ?, ?, ?, ?)
               RETURNING id |sql})
      ( (public_key_id, balance_to_int64 balance)
      , ( block_id
        , block_height
        , (block_sequence_no, block_secondary_sequence_no)
        , nonce ) )

  let add_if_doesn't_exist (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) ~block_id ~block_height ~block_sequence_no
      ~block_secondary_sequence_no ~nonce =
    let open Deferred.Result.Let_syntax in
    match%bind
      find
        (module Conn)
        ~public_key_id ~balance ~block_id ~block_height ~block_sequence_no
        ~block_secondary_sequence_no
    with
    | Some balance_id ->
        return balance_id
    | None ->
        add
          (module Conn)
          ~public_key_id ~balance ~block_id ~block_height ~block_sequence_no
          ~block_secondary_sequence_no ~nonce
end

module Block_and_internal_command = struct
  type t =
    { block_id : int
    ; internal_command_id : int
    ; sequence_no : int
    ; secondary_sequence_no : int
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; int ]

  let add (module Conn : CONNECTION) ~block_id ~internal_command_id ~sequence_no
      ~secondary_sequence_no =
    Conn.exec
      (Caqti_request.exec typ
         {sql| INSERT INTO blocks_internal_commands
                (block_id, internal_command_id, sequence_no, secondary_sequence_no
                VALUES (?, ?, ?, ?)
         |sql})
      { block_id; internal_command_id; sequence_no; secondary_sequence_no }

  let find (module Conn : CONNECTION) ~block_id ~internal_command_id
      ~sequence_no ~secondary_sequence_no =
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup4 int int int int)
         Caqti_type.string
         {sql| SELECT 'exists' FROM blocks_internal_commands
               WHERE block_id = $1
               AND internal_command_id = $2
               AND sequence_no = $3
               AND secondary_sequence_no = $4
         |sql})
      (block_id, internal_command_id, sequence_no, secondary_sequence_no)

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id
      ~internal_command_id ~sequence_no ~secondary_sequence_no =
    let open Deferred.Result.Let_syntax in
    match%bind
      find
        (module Conn)
        ~block_id ~internal_command_id ~sequence_no ~secondary_sequence_no
    with
    | Some _ ->
        return ()
    | None ->
        add
          (module Conn)
          ~block_id ~internal_command_id ~sequence_no ~secondary_sequence_no
end

module Block_and_signed_command = struct
  type t =
    { block_id : int
    ; user_command_id : int
    ; sequence_no : int
    ; status : string
    ; failure_reason : string option
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; string; option string ]

  let add (module Conn : CONNECTION) ~block_id ~user_command_id ~sequence_no
      ~status ~failure_reason =
    let failure_reason =
      Option.map ~f:Transaction_status.Failure.to_string failure_reason
    in
    Conn.exec
      (Caqti_request.exec typ
         {sql| INSERT INTO blocks_user_commands
                 (block_id,
                 user_command_id,
                 sequence_no,
                 status,
                 failure_reason)
               VALUES (?, ?, ?, ?::user_command_status, ?)
         |sql})
      { block_id; user_command_id; sequence_no; status; failure_reason }

  let add_with_status (module Conn : CONNECTION) ~block_id ~user_command_id
      ~sequence_no ~(status : Transaction_status.t) =
    let status_str, failure_reason =
      match status with
      | Applied ->
          (applied_str, None)
      | Failed failures ->
          (* for signed commands, there's exactly one failure *)
          (failed_str, Some (List.concat failures |> List.hd_exn))
    in
    add
      (module Conn)
      ~block_id ~user_command_id ~sequence_no ~status:status_str ~failure_reason

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id ~user_command_id
      ~sequence_no ~(status : string) ~failure_reason =
    let open Deferred.Result.Let_syntax in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt
           Caqti_type.(tup3 int int int)
           Caqti_type.string
           {sql| SELECT 'exists' FROM blocks_user_commands
                 WHERE block_id = $1
                 AND user_command_id = $2
                 AND sequence_no = $3
           |sql})
        (block_id, user_command_id, sequence_no)
    with
    | Some _ ->
        return ()
    | None ->
        add
          (module Conn)
          ~block_id ~user_command_id ~sequence_no ~status ~failure_reason

  let load (module Conn : CONNECTION) ~block_id ~user_command_id ~sequence_no =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         typ
         {sql| SELECT block_id, user_command_id,
               sequence_no,
               status,failure_reason,
               fee_payer_account_creation_fee_paid,
               receiver_account_creation_fee_paid,
               created_token,
               fee_payer_balance,
               source_balance,
               receiver_balance
               FROM blocks_user_commands
               WHERE block_id = $1
               AND user_command_id = $2
               AND sequence_no = $3
           |sql})
      (block_id, user_command_id, sequence_no)
end

module Zkapp_party_failures = struct
  type t = { index : int; failures : string array } [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; Mina_caqti.array_string_typ ]

  let table_name = "zkapp_party_failures"

  let add_if_doesn't_exist (module Conn : CONNECTION) index failures =
    let failures =
      List.map failures ~f:Transaction_status.Failure.to_string |> Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "index"; "failures" ], typ)
      (module Conn)
      { index; failures }

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name
            ~cols:[ "index"; "failures" ]))
      id
end

module Block_and_zkapp_command = struct
  type t =
    { block_id : int
    ; zkapp_command_id : int
    ; sequence_no : int
    ; status : string
    ; failure_reasons_ids : int array option
    }
  [@@deriving hlist]

  let table_name = "blocks_zkapp_commands"

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; string; option Mina_caqti.array_int_typ ]

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id
      ~zkapp_command_id ~sequence_no ~status
      ~(failure_reasons : Transaction_status.Failure.Collection.display option)
      =
    let open Deferred.Result.Let_syntax in
    let%bind failure_reasons_ids =
      match failure_reasons with
      | None ->
          return None
      | Some reasons ->
          let%map failure_reasons_ids_list =
            Mina_caqti.deferred_result_list_map reasons
              ~f:(fun (ndx, failure_reasons) ->
                Zkapp_party_failures.add_if_doesn't_exist
                  (module Conn)
                  ndx failure_reasons)
          in
          Some (Array.of_list failure_reasons_ids_list)
    in
    Mina_caqti.select_insert_into_cols
      ~select:
        ( "block_id, zkapp_command_id, sequence_no"
        , Caqti_type.(tup3 int int int) )
      ~table_name
      ~cols:
        ( [ "block_id"
          ; "zkapp_command_id"
          ; "sequence_no"
          ; "status"
          ; "failure_reasons_ids"
          ]
        , typ )
      (module Conn)
      { block_id; zkapp_command_id; sequence_no; status; failure_reasons_ids }

  let load (module Conn : CONNECTION) ~block_id ~zkapp_command_id ~sequence_no =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         typ
         (Mina_caqti.select_cols_from_id ~table_name
            ~cols:
              [ "block_id"
              ; "zkapp_command_id"
              ; "sequence_no"
              ; "status"
              ; "failure_reasons_ids"
              ]))
      (block_id, zkapp_command_id, sequence_no)
end

module Account_identifiers = struct
  type t = { public_key_id : int; token : string; token_owner : int }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; string; int ]

  let table_name = "account_identifiers"

  let add_if_doesn't_exist (module Conn : CONNECTION) ~account_id ~token_owner =
    let open Deferred.Result.Let_syntax in
    let pk = Account_id.public_key account_id in
    let token = Account_id.token_id account_id |> Token_id.to_string in
    let%bind public_key_id = Public_key.add_if_doesn't_exist (module Conn) pk in
    let t = { public_key_id; token; token_owner } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t
end

module Zkapp_uri = struct
  type t = string

  let typ = Caqti_type.string

  let table_name = "zkapp_uris"

  let add_if_doesn't_exist (module Conn : CONNECTION) zkapp_uri =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "uri" ], typ)
      (module Conn)
      zkapp_uri

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "uri" ]))
      id
end

module Zkapp_account = struct
  type t =
    { app_state_id : int
    ; verification_key_id : int option
    ; zkapp_version : int64
    ; sequence_state_id : int
    ; last_sequence_slot : int64
    ; proved_state : bool
    ; zkapp_uri_id : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; option int; int64; int; int64; bool; int ]

  let table_name = "zkapp_accounts"

  (* TODO: when zkapp_uri moved to Zkapp.Account in OCaml, no need to pass it in separately *)
  let add_if_doesn't_exist (module Conn : CONNECTION) zkapp_uri zkapp_account =
    let open Deferred.Result.Let_syntax in
    let ({ app_state
         ; verification_key
         ; zkapp_version
         ; sequence_state
         ; last_sequence_slot
         ; proved_state
         }
          : Mina_base.Zkapp_account.t) =
      zkapp_account
    in
    let app_state = Vector.map app_state ~f:(fun field -> Some field) in
    let%bind app_state_id =
      Zkapp_states.add_if_doesn't_exist (module Conn) app_state
    in
    let%bind verification_key_id =
      Option.value_map verification_key ~default:(return None) ~f:(fun vk ->
          let%map id =
            Zkapp_verification_keys.add_if_doesn't_exist (module Conn) vk
          in
          Some id)
    in
    let zkapp_version = zkapp_version |> Unsigned.UInt32.to_int64 in
    let%bind sequence_state_id =
      Zkapp_sequence_states.add_if_doesn't_exist (module Conn) sequence_state
    in
    let last_sequence_slot =
      Mina_numbers.Global_slot.to_uint32 last_sequence_slot
      |> Unsigned.UInt32.to_int64
    in
    let%bind zkapp_uri_id =
      Zkapp_uri.add_if_doesn't_exist (module Conn) zkapp_uri
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      { app_state_id
      ; verification_key_id
      ; zkapp_version
      ; sequence_state_id
      ; last_sequence_slot
      ; proved_state
      ; zkapp_uri_id
      }
end

module Accounts_accessed = struct
  type t =
    { ledger_index : int
    ; block_id : int
    ; account_id_id : int
    ; token_symbol : string
    ; balance : int64
    ; nonce : int64
    ; receipt_chain_hash : string
    ; delegate : string option
    ; voting_for : string
    ; timing_id : int
    ; permissions_id : int
    ; zkapp_id : int option
    }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int
        ; int
        ; int
        ; string
        ; int64
        ; int64
        ; string
        ; option string
        ; string
        ; int
        ; int
        ; option int
        ]

  let table_name = "accounts_accessed"

  let add_if_doesn't_exist (module Conn : CONNECTION) block_id
      (ledger_index, (account : Account.t)) =
    let open Deferred.Result.Let_syntax in
    let account_id = Account_id.create account.public_key account.token_id in
    let%bind account_id_id =
      Account_identifiers.add_if_doesn't_exist
        (module Conn)
        ~account_id ~token_owner:0
      (* TODO!!! TEMP!!!! need to get token owner *)
    in
    let token_symbol = account.token_symbol in
    let balance =
      account.balance |> Currency.Balance.to_uint64 |> Unsigned.UInt64.to_int64
    in
    let nonce =
      account.nonce |> Account.Nonce.to_uint32 |> Unsigned.UInt32.to_int64
    in
    let receipt_chain_hash =
      account.receipt_chain_hash |> Receipt.Chain_hash.to_base58_check
    in
    let delegate =
      Option.map account.delegate
        ~f:Signature_lib.Public_key.Compressed.to_base58_check
    in
    let voting_for = account.voting_for |> State_hash.to_base58_check in
    let%bind timing_id =
      Timing_info.add_if_doesn't_exist (module Conn) account
    in
    let%bind permissions_id =
      Zkapp_permissions.add_if_doesn't_exist (module Conn) account.permissions
    in
    let%bind zkapp_id =
      (* TODO: when zkapp_uri part of Zkapp.Account.t, don't pass it separately here *)
      Option.value_map account.zkapp ~default:(return None) ~f:(fun zkapp ->
          let%map id =
            Zkapp_account.add_if_doesn't_exist
              (module Conn)
              account.zkapp_uri zkapp
          in
          Some id)
    in
    let account_accessed : t =
      { ledger_index
      ; block_id
      ; account_id_id
      ; token_symbol
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing_id
      ; permissions_id
      ; zkapp_id
      }
    in
    Mina_caqti.select_insert_into_cols
      ~select:("block_id,account_id", Caqti_type.(tup2 int int))
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      account_accessed

  let add_accounts_if_don't_exist (module Conn : CONNECTION) block_id
      (accounts : (int * Account.t) list) =
    let%map results =
      Deferred.List.map accounts ~f:(fun account ->
          add_if_doesn't_exist (module Conn) block_id account)
    in
    Result.all results
end

module Accounts_created = struct
  type t = { block_id : int; account_id_id : int; creation_fee : int64 }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int64 ]

  let table_name = "accounts_created"

  let add_if_doesn't_exist (module Conn : CONNECTION) block_id account_id
      creation_fee =
    let open Deferred.Result.Let_syntax in
    let%bind account_id_id =
      (* TODO: TEMP!!!! -- add real token owner *)
      Account_identifiers.add_if_doesn't_exist
        (module Conn)
        ~account_id ~token_owner:0
    in
    let creation_fee =
      Currency.Fee.to_uint64 creation_fee |> Unsigned.UInt64.to_int64
    in
    let t = { block_id; account_id_id; creation_fee } in
    Mina_caqti.select_insert_into_cols
      ~select:("block_id,public_key_id", Caqti_type.(tup2 int int))
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let add_accounts_created_if_don't_exist (module Conn : CONNECTION) block_id
      accounts_created =
    let%map results =
      Deferred.List.map accounts_created ~f:(fun (pk, creation_fee) ->
          add_if_doesn't_exist (module Conn) block_id pk creation_fee)
    in
    Result.all results
end

module Block = struct
  type t =
    { state_hash : string
    ; parent_id : int option
    ; parent_hash : string
    ; creator_id : int
    ; block_winner_id : int
    ; snarked_ledger_hash_id : int
    ; staking_epoch_data_id : int
    ; next_epoch_data_id : int
    ; min_window_density : int64
    ; total_currency : int64
    ; ledger_hash : string
    ; height : int64
    ; global_slot_since_hard_fork : int64
    ; global_slot_since_genesis : int64
    ; timestamp : int64
    ; chain_status : string
    }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ string
        ; option int
        ; string
        ; int
        ; int
        ; int
        ; int
        ; int
        ; int64
        ; int64
        ; string
        ; int64
        ; int64
        ; int64
        ; int64
        ; string
        ]

  let find (module Conn : CONNECTION) ~(state_hash : State_hash.t) =
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "SELECT id FROM blocks WHERE state_hash = ?")
      (State_hash.to_base58_check state_hash)

  let find_opt (module Conn : CONNECTION) ~(state_hash : State_hash.t) =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM blocks WHERE state_hash = ?")
      (State_hash.to_base58_check state_hash)

  let load (module Conn : CONNECTION) ~id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name:"blocks"
            ~cols:Fields.names))
      id

  let add_parts_if_doesn't_exist (module Conn : CONNECTION)
      ~constraint_constants ~protocol_state ~staged_ledger_diff ~hash =
    let open Deferred.Result.Let_syntax in
    match%bind find_opt (module Conn) ~state_hash:hash with
    | Some block_id ->
        return block_id
    | None ->
        let consensus_state = Protocol_state.consensus_state protocol_state in
        let%bind parent_id =
          find_opt
            (module Conn)
            ~state_hash:(Protocol_state.previous_state_hash protocol_state)
        in
        let%bind creator_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Consensus.Data.Consensus_state.block_creator consensus_state)
        in
        let%bind block_winner_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Consensus.Data.Consensus_state.block_stake_winner consensus_state)
        in
        let%bind snarked_ledger_hash_id =
          Snarked_ledger_hash.add_if_doesn't_exist
            (module Conn)
            ( Protocol_state.blockchain_state protocol_state
            |> Blockchain_state.snarked_ledger_hash )
        in
        let%bind staking_epoch_data_id =
          Epoch_data.add_if_doesn't_exist
            (module Conn)
            (Consensus.Data.Consensus_state.staking_epoch_data consensus_state)
        in
        let%bind next_epoch_data_id =
          Epoch_data.add_if_doesn't_exist
            (module Conn)
            (Consensus.Data.Consensus_state.next_epoch_data consensus_state)
        in
        let height =
          consensus_state |> Consensus.Data.Consensus_state.blockchain_length
          |> Unsigned.UInt32.to_int64
        in
        let transactions =
          let coinbase_receiver =
            Consensus.Data.Consensus_state.coinbase_receiver consensus_state
          in
          let supercharge_coinbase =
            Consensus.Data.Consensus_state.supercharge_coinbase consensus_state
          in
          match
            Staged_ledger.Pre_diff_info.get_transactions ~constraint_constants
              ~coinbase_receiver ~supercharge_coinbase staged_ledger_diff
          with
          | Ok transactions ->
              transactions
          | Error e ->
              Error.raise (Staged_ledger.Pre_diff_info.Error.to_error e)
        in
        (* grab all the nonces associated with every public key in all of these
         * transactions for blocks earlier than this one. *)
        let%bind initial_nonce_map :
            ( Account.Nonce.t Signature_lib.Public_key.Compressed.Map.t
            , _ )
            Deferred.Result.t =
          let public_keys =
            transactions
            |> List.map ~f:(fun x -> Transaction.public_keys x.data)
            |> List.concat
          in
          (* if this block is disconnected and doesn't have a parent, the nonce map will need to start empty *)
          match parent_id with
          | None ->
              Deferred.Result.return
                Signature_lib.Public_key.Compressed.Map.empty
          | Some parent_id ->
              Find_nonce.initialize_nonce_map
                (module Conn)
                ~public_keys ~parent_id
        in
        let%bind block_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               {sql| INSERT INTO blocks (state_hash, parent_id, parent_hash,
                      creator_id, block_winner_id,
                      snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id,
                      min_window_density, total_currency,
                      ledger_hash, height, global_slot_since_hard_fork,
                      global_slot_since_genesis, timestamp, chain_status)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::chain_status_type) RETURNING id
               |sql})
            { state_hash = hash |> State_hash.to_base58_check
            ; parent_id
            ; parent_hash =
                Protocol_state.previous_state_hash protocol_state
                |> State_hash.to_base58_check
            ; creator_id
            ; block_winner_id
            ; snarked_ledger_hash_id
            ; staking_epoch_data_id
            ; next_epoch_data_id
            ; min_window_density =
                Protocol_state.consensus_state protocol_state
                |> Consensus.Data.Consensus_state.min_window_density
                |> Mina_numbers.Length.to_uint32 |> Unsigned.UInt32.to_int64
            ; total_currency =
                Protocol_state.consensus_state protocol_state
                |> Consensus.Data.Consensus_state.total_currency
                |> Currency.Amount.to_uint64 |> Unsigned.UInt64.to_int64
            ; ledger_hash =
                Protocol_state.blockchain_state protocol_state
                |> Blockchain_state.staged_ledger_hash
                |> Staged_ledger_hash.ledger_hash |> Ledger_hash.to_base58_check
            ; height
            ; global_slot_since_hard_fork =
                Consensus.Data.Consensus_state.curr_global_slot consensus_state
                |> Unsigned.UInt32.to_int64
            ; global_slot_since_genesis =
                consensus_state
                |> Consensus.Data.Consensus_state.global_slot_since_genesis
                |> Unsigned.UInt32.to_int64
            ; timestamp =
                Protocol_state.blockchain_state protocol_state
                |> Blockchain_state.timestamp |> Block_time.to_int64
                (* we don't yet know the chain status for a block we're adding *)
            ; chain_status = Chain_status.(to_string Pending)
            }
        in
        let%bind (_
                   : int
                     * Account.Nonce.t Signature_lib.Public_key.Compressed.Map.t)
            =
          Mina_caqti.deferred_result_list_fold transactions
            ~init:(0, initial_nonce_map) ~f:(fun (sequence_no, nonce_map) ->
            function
            | { Mina_base.With_status.status
              ; data = Transaction.Command command
              } ->
                let user_command =
                  { Mina_base.With_status.status; data = command }
                in
                (* This is the only place we adjust the nonce_map -- we want to modify the public key associated with the fee_payer for this user-command to increment its nonce.
                   Note: Intentionally shadowing `nonce_map` here as we want to pass the updated map. *)
                let nonce_map =
                  Signature_lib.Public_key.Compressed.Map.change
                    initial_nonce_map
                    ( Mina_base.User_command.fee_payer command
                    |> Account_id.public_key )
                    ~f:(fun _ ->
                      Some
                        ( Mina_base.User_command.nonce_exn command
                        |> Unsigned.UInt32.succ ))
                in
                let%bind id =
                  User_command.add_if_doesn't_exist
                    (module Conn)
                    user_command.data
                in
                let%map () =
                  match command with
                  | Signed_command _ ->
                      Block_and_signed_command.add_with_status
                        (module Conn)
                        ~block_id ~user_command_id:id ~sequence_no
                        ~status:user_command.status
                      >>| ignore
                  | Parties _ ->
                      let status, failure_reasons =
                        match user_command.status with
                        | Applied ->
                            (applied_str, None)
                        | Failed failures ->
                            let display =
                              Transaction_status.Failure.Collection.to_display
                                failures
                            in
                            (failed_str, Some display)
                      in
                      Block_and_zkapp_command.add_if_doesn't_exist
                        (module Conn)
                        ~block_id ~zkapp_command_id:id ~sequence_no ~status
                        ~failure_reasons
                      >>| ignore
                in
                (sequence_no + 1, nonce_map)
            | { data = Fee_transfer fee_transfer_bundled; _ } ->
                let fee_transfers =
                  Mina_base.Fee_transfer.to_numbered_list fee_transfer_bundled
                in
                (* balances.receiver1_balance is for receiver of head of fee_transfers
                   balances.receiver2_balance, if it exists, is for receiver of
                     next element of fee_transfers
                *)
                let%bind fee_transfer_infos =
                  Mina_caqti.deferred_result_list_fold fee_transfers ~init:[]
                    ~f:(fun acc (secondary_sequence_no, fee_transfer) ->
                      let%map id =
                        Fee_transfer.add_if_doesn't_exist
                          (module Conn)
                          fee_transfer `Normal
                      in
                      ( id
                      , secondary_sequence_no
                      , fee_transfer.fee
                      , fee_transfer.receiver_pk )
                      :: acc)
                in
                let fee_transfer_infos_with_balances =
                  match fee_transfer_infos with
                  | [ id ] ->
                      [ id ]
                  | [ id2; id1 ] ->
                      (* the fold reverses the order of the infos from the fee transfers *)
                      [ id1; id2 ]
                  | _ ->
                      failwith
                        "Unexpected number of single fee transfers in a fee \
                         transfer transaction"
                in
                let%map () =
                  Mina_caqti.deferred_result_list_fold
                    fee_transfer_infos_with_balances ~init:()
                    ~f:(fun () (fee_transfer_id, secondary_sequence_no, _, _) ->
                      Block_and_internal_command.add
                        (module Conn)
                        ~block_id ~internal_command_id:fee_transfer_id
                        ~sequence_no ~secondary_sequence_no
                      >>| ignore)
                in
                (sequence_no + 1, nonce_map)
            | { data = Coinbase coinbase; _ } ->
                let%bind id =
                  Coinbase.add_if_doesn't_exist (module Conn) coinbase
                in
                let%map () =
                  Block_and_internal_command.add
                    (module Conn)
                    ~block_id ~internal_command_id:id ~sequence_no
                    ~secondary_sequence_no:0
                  >>| ignore
                in
                (sequence_no + 1, nonce_map))
        in
        return block_id

  let add_if_doesn't_exist conn ~constraint_constants
      ({ data = t; hash = { state_hash = hash; _ } } :
        External_transition.t State_hash.With_state_hashes.t) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:(External_transition.protocol_state t)
      ~staged_ledger_diff:(External_transition.staged_ledger_diff t)
      ~hash

  let add_from_precomputed conn ~constraint_constants
      (t : External_transition.Precomputed_block.t) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:t.protocol_state ~staged_ledger_diff:t.staged_ledger_diff
      ~hash:(Protocol_state.hashes t.protocol_state).state_hash

  let add_from_extensional (module Conn : CONNECTION)
      (block : Extensional.Block.t) =
    let open Deferred.Result.Let_syntax in
    let%bind block_id =
      match%bind find_opt (module Conn) ~state_hash:block.state_hash with
      | Some block_id ->
          return block_id
      | None ->
          let%bind parent_id =
            find_opt (module Conn) ~state_hash:block.parent_hash
          in
          let%bind creator_id =
            Public_key.add_if_doesn't_exist (module Conn) block.creator
          in
          let%bind block_winner_id =
            Public_key.add_if_doesn't_exist (module Conn) block.block_winner
          in
          let%bind snarked_ledger_hash_id =
            Snarked_ledger_hash.add_if_doesn't_exist
              (module Conn)
              block.snarked_ledger_hash
          in
          let%bind staking_epoch_data_id =
            Epoch_data.add_if_doesn't_exist
              (module Conn)
              block.staking_epoch_data
          in
          let%bind next_epoch_data_id =
            Epoch_data.add_if_doesn't_exist (module Conn) block.next_epoch_data
          in
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               {sql| INSERT INTO blocks
                     (state_hash, parent_id, parent_hash,
                      creator_id, block_winner_id,
                      snarked_ledger_hash_id, staking_epoch_data_id,
                      next_epoch_data_id,
                      min_window_density, total_currency,
                      ledger_hash, height, global_slot_since_hard_fork,
                      global_slot_since_genesis, timestamp, chain_status)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::chain_status_type)
                     RETURNING id
               |sql})
            { state_hash = block.state_hash |> State_hash.to_base58_check
            ; parent_id
            ; parent_hash = block.parent_hash |> State_hash.to_base58_check
            ; creator_id
            ; block_winner_id
            ; snarked_ledger_hash_id
            ; staking_epoch_data_id
            ; next_epoch_data_id
            ; min_window_density =
                block.min_window_density |> Mina_numbers.Length.to_uint32
                |> Unsigned.UInt32.to_int64
            ; total_currency =
                block.total_currency |> Currency.Amount.to_uint64
                |> Unsigned.UInt64.to_int64
            ; ledger_hash = block.ledger_hash |> Ledger_hash.to_base58_check
            ; height = block.height |> Unsigned.UInt32.to_int64
            ; global_slot_since_hard_fork =
                block.global_slot_since_hard_fork |> Unsigned.UInt32.to_int64
            ; global_slot_since_genesis =
                block.global_slot_since_genesis |> Unsigned.UInt32.to_int64
            ; timestamp = block.timestamp |> Block_time.to_int64
            ; chain_status = Chain_status.to_string block.chain_status
            }
    in
    (* add user commands *)
    let%bind user_cmds_with_ids =
      let%map user_cmd_ids_rev =
        Mina_caqti.deferred_result_list_fold block.user_cmds ~init:[]
          ~f:(fun acc user_cmd ->
            let%map cmd_id =
              User_command.add_extensional_if_doesn't_exist
                (module Conn)
                user_cmd
            in
            cmd_id :: acc)
      in
      List.zip_exn block.user_cmds (List.rev user_cmd_ids_rev)
    in
    (* add user commands to join table *)
    let%bind () =
      Mina_caqti.deferred_result_list_fold user_cmds_with_ids ~init:()
        ~f:(fun () (user_command, user_command_id) ->
          Block_and_signed_command.add_if_doesn't_exist
            (module Conn)
            ~block_id ~user_command_id ~sequence_no:user_command.sequence_no
            ~status:user_command.status
            ~failure_reason:user_command.failure_reason)
    in
    (* add internal commands *)
    let%bind internal_cmds_ids_and_seq_nos =
      let%map internal_cmds_and_ids_rev =
        Mina_caqti.deferred_result_list_fold block.internal_cmds ~init:[]
          ~f:(fun acc internal_cmd ->
            let%map cmd_id =
              Internal_command.add_extensional_if_doesn't_exist
                (module Conn)
                internal_cmd
            in
            (internal_cmd, cmd_id) :: acc)
      in
      let sequence_nos =
        List.map block.internal_cmds ~f:(fun internal_cmd ->
            (internal_cmd.sequence_no, internal_cmd.secondary_sequence_no))
      in
      List.zip_exn (List.rev internal_cmds_and_ids_rev) sequence_nos
    in
    (* add internal commands to join table *)
    let%bind () =
      Mina_caqti.deferred_result_list_fold internal_cmds_ids_and_seq_nos
        ~init:()
        ~f:(fun
             ()
             ( (_internal_command, internal_command_id)
             , (sequence_no, secondary_sequence_no) )
           ->
          Block_and_internal_command.add_if_doesn't_exist
            (module Conn)
            ~block_id ~internal_command_id ~sequence_no ~secondary_sequence_no)
    in
    (* add zkApp commands *)
    let%bind zkapp_cmds_ids_and_seq_nos =
      let%map zkapp_cmds_and_ids_rev =
        Mina_caqti.deferred_result_list_fold block.zkapp_cmds ~init:[]
          ~f:(fun acc ({ parties; _ } as zkapp_cmd) ->
            let%map cmd_id =
              User_command.Zkapp_command.add_if_doesn't_exist
                (module Conn)
                parties
            in
            (zkapp_cmd, cmd_id) :: acc)
      in
      let sequence_nos =
        List.map block.zkapp_cmds ~f:(fun { sequence_no; _ } -> sequence_no)
      in
      List.zip_exn (List.rev zkapp_cmds_and_ids_rev) sequence_nos
    in
    (* add zkapp commands to join table *)
    let%bind () =
      Mina_caqti.deferred_result_list_fold zkapp_cmds_ids_and_seq_nos ~init:()
        ~f:(fun () ((zkapp_command, zkapp_command_id), sequence_no) ->
          let%map _block_id, _cmd_id, _sequence_no =
            Block_and_zkapp_command.add_if_doesn't_exist
              (module Conn)
              ~block_id ~zkapp_command_id ~sequence_no
              ~status:zkapp_command.status
              ~failure_reasons:zkapp_command.failure_reasons
          in
          ())
    in
    (* add accounts accessed *)
    let%bind _block_and_account_ids =
      Accounts_accessed.add_accounts_if_don't_exist
        (module Conn)
        block_id block.accounts_accessed
    in
    (* add accounts created *)
    let%bind _block_and_pk_ids =
      Accounts_created.add_accounts_created_if_don't_exist
        (module Conn)
        block_id block.accounts_created
    in
    return block_id

  let set_parent_id_if_null (module Conn : CONNECTION) ~parent_hash
      ~(parent_id : int) =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int string)
         {sql| UPDATE blocks SET parent_id = ?
               WHERE parent_hash = ?
               AND parent_id IS NULL
         |sql})
      (parent_id, State_hash.to_base58_check parent_hash)

  let get_subchain (module Conn : CONNECTION) ~start_block_id ~end_block_id =
    Conn.collect_list
      (Caqti_request.collect
         Caqti_type.(tup2 int int)
         typ
         {sql| WITH RECURSIVE chain AS (
              SELECT id,state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                     next_epoch_data_id,ledger_hash,height,global_slot,global_slot_since_genesis,timestamp, chain_status
              FROM blocks b WHERE b.id = $1

              UNION ALL

              SELECT b.id,b.state_hash,b.parent_id,b.parent_hash,b.creator_id,b.block_winner_id,b.snarked_ledger_hash_id,b.staking_epoch_data_id,
                     b.next_epoch_data_id,b.ledger_hash,b.height,b.global_slot,b.global_slot_since_genesis,b.timestamp,b.chain_status
              FROM blocks b

              INNER JOIN chain

              ON b.id = chain.parent_id AND (chain.id <> $2 OR b.id = $2)

           )

           SELECT state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,staking_epoch_data_id,
                  next_epoch_data_id,ledger_hash,height,global_slot,global_slot_since_genesis,timestamp,chain_status
           FROM chain ORDER BY height ASC
      |sql})
      (end_block_id, start_block_id)

  let get_highest_canonical_block_opt (module Conn : CONNECTION) =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.unit
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' ORDER BY \
          height DESC LIMIT 1")

  let get_nearest_canonical_block_above (module Conn : CONNECTION) height =
    Conn.find
      (Caqti_request.find Caqti_type.int64
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' AND \
          height > ? ORDER BY height ASC LIMIT 1")
      height

  let get_nearest_canonical_block_below (module Conn : CONNECTION) height =
    Conn.find
      (Caqti_request.find Caqti_type.int64
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' AND \
          height < ? ORDER BY height DESC LIMIT 1")
      height

  let mark_as_canonical (module Conn : CONNECTION) ~state_hash =
    Conn.exec
      (Caqti_request.exec Caqti_type.string
         "UPDATE blocks SET chain_status='canonical' WHERE state_hash = ?")
      state_hash

  let mark_as_orphaned (module Conn : CONNECTION) ~state_hash ~height =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 string int64)
         {sql| UPDATE blocks SET chain_status='orphaned'
               WHERE height = $2
               AND state_hash <> $1
         |sql})
      (state_hash, height)

  (* update chain_status for blocks now known to be canonical or orphaned *)
  let update_chain_status (module Conn : CONNECTION) ~block_id =
    let open Deferred.Result.Let_syntax in
    match%bind get_highest_canonical_block_opt (module Conn) () with
    | None ->
        (* unit tests, no canonical block, can't mark any block as canonical *)
        Deferred.Result.return ()
    | Some (highest_canonical_block_id, greatest_canonical_height) ->
        let k_int64 = Genesis_constants.k |> Int64.of_int in
        let%bind block = load (module Conn) ~id:block_id in
        if
          Int64.( > ) block.height
            (Int64.( + ) greatest_canonical_height k_int64)
        then
          (* a new block, allows marking some pending blocks as canonical *)
          let%bind subchain_blocks =
            get_subchain
              (module Conn)
              ~start_block_id:highest_canonical_block_id ~end_block_id:block_id
          in
          let block_height_less_k_int64 = Int64.( - ) block.height k_int64 in
          (* mark canonical, orphaned blocks in subchain at least k behind the new block *)
          let canonical_blocks =
            List.filter subchain_blocks ~f:(fun subchain_block ->
                Int64.( <= ) subchain_block.height block_height_less_k_int64)
          in
          Mina_caqti.deferred_result_list_fold canonical_blocks ~init:()
            ~f:(fun () block ->
              let%bind () =
                mark_as_canonical (module Conn) ~state_hash:block.state_hash
              in
              mark_as_orphaned
                (module Conn)
                ~state_hash:block.state_hash ~height:block.height)
        else if Int64.( < ) block.height greatest_canonical_height then
          (* a missing block added in the middle of canonical chain *)
          let%bind canonical_block_above_id, _above_height =
            get_nearest_canonical_block_above (module Conn) block.height
          in
          let%bind canonical_block_below_id, _below_height =
            get_nearest_canonical_block_below (module Conn) block.height
          in
          (* we can always find this chain: the genesis block should be marked as canonical, and we've found a
             canonical block above this one *)
          let%bind canonical_blocks =
            get_subchain
              (module Conn)
              ~start_block_id:canonical_block_below_id
              ~end_block_id:canonical_block_above_id
          in
          Mina_caqti.deferred_result_list_fold canonical_blocks ~init:()
            ~f:(fun () block ->
              let%bind () =
                mark_as_canonical (module Conn) ~state_hash:block.state_hash
              in
              mark_as_orphaned
                (module Conn)
                ~state_hash:block.state_hash ~height:block.height)
        else
          (* a block at or above highest canonical block, not high enough to mark any blocks as canonical *)
          Deferred.Result.return ()

  let delete_if_older_than ?height ?num_blocks ?timestamp
      (module Conn : CONNECTION) =
    let open Deferred.Result.Let_syntax in
    let%bind height =
      match (height, num_blocks) with
      | Some height, _ ->
          return height
      | None, Some num_blocks -> (
          match%map
            Conn.find_opt
              (Caqti_request.find_opt Caqti_type.unit Caqti_type.int
                 "SELECT MAX(height) FROM blocks")
              ()
          with
          | Some max_block_height ->
              max_block_height - num_blocks
          | _ ->
              0 )
      | None, None ->
          return 0
    in
    let timestamp = Option.value ~default:Int64.zero timestamp in
    if height > 0 || Int64.(timestamp > 0L) then
      let%bind () =
        (* Delete user commands from old blocks. *)
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(tup2 int int64)
             "DELETE FROM user_commands\n\
              WHERE id IN\n\
              (SELECT user_command_id FROM blocks_user_commands\n\
              INNER JOIN blocks ON blocks.id = block_id\n\
              WHERE (blocks.height < ? OR blocks.timestamp < ?))")
          (height, timestamp)
      in
      let%bind () =
        (* Delete old blocks. *)
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(tup2 int int64)
             "DELETE FROM blocks WHERE blocks.height < ? OR blocks.timestamp < \
              ?")
          (height, timestamp)
      in
      let%bind () =
        (* Delete orphaned internal commands. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM internal_commands\n\
              WHERE id NOT IN\n\
              (SELECT internal_commands.id FROM internal_commands\n\
              INNER JOIN blocks_internal_commands ON\n\
              internal_command_id = internal_commands.id)")
          ()
      in
      let%bind () =
        (* Delete orphaned snarked ledger hashes. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM snarked_ledger_hashes\n\
              WHERE id NOT IN\n\
              (SELECT snarked_ledger_hash_id FROM blocks)")
          ()
      in
      let%bind () =
        (* Delete orphaned public keys. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM public_keys\n\
              WHERE id NOT IN (SELECT fee_payer_id FROM user_commands)\n\
              AND id NOT IN (SELECT source_id FROM user_commands)\n\
              AND id NOT IN (SELECT receiver_id FROM user_commands)\n\
              AND id NOT IN (SELECT receiver_id FROM internal_commands)\n\
              AND id NOT IN (SELECT creator_id FROM blocks)")
          ()
      in
      return ()
    else return ()
end

let retry ~f ~logger ~error_str retries =
  let rec go retry_count =
    match%bind f () with
    | Error e ->
        if retry_count <= 0 then return (Error e)
        else (
          [%log warn] "Error in %s : $error. Retrying..." error_str
            ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
          let wait_for = Random.float_range 20. 2000. in
          let%bind () = after (Time.Span.of_ms wait_for) in
          go (retry_count - 1) )
    | Ok res ->
        return (Ok res)
  in
  go retries

let add_block_aux ?(retries = 3) ~logger ~pool ~add_block ~hash
    ~delete_older_than ~accounts_accessed ~accounts_created block =
  let state_hash = hash block in
  let add () =
    Caqti_async.Pool.use
      (fun (module Conn : CONNECTION) ->
        let%bind res =
          let open Deferred.Result.Let_syntax in
          let%bind () = Conn.start () in

          [%log info] "Attempting to add block data for $state_hash"
            ~metadata:
              [ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ] ;
          let%bind block_id = add_block (module Conn : CONNECTION) block in
          (* if an existing block has a parent hash that's for the block just added,
             set its parent id
          *)
          let%bind () =
            Block.set_parent_id_if_null
              (module Conn)
              ~parent_hash:(hash block) ~parent_id:block_id
          in
          (* update chain status for existing blocks *)
          let%bind () = Block.update_chain_status (module Conn) ~block_id in
          match delete_older_than with
          | Some num_blocks ->
              Block.delete_if_older_than ~num_blocks (module Conn)
          | None ->
              return ()
        in
        match res with
        | Error e as err ->
            (*Error in the current transaction*)
            [%log warn]
              "Error when adding block data to the database, rolling back \
               transaction: $error"
              ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
            let%map _ = Conn.rollback () in
            err
        | Ok _ -> (
            (* added block data, now add accounts accessed *)
            match%bind
              Caqti_async.Pool.use
                (fun (module Conn : CONNECTION) ->
                  Block.find (module Conn) ~state_hash)
                pool
            with
            | Error err ->
                [%log warn]
                  "Could not get block id for block just archived; can't store \
                   accounts accessed, rolling back transaction"
                  ~metadata:
                    [ ("block", State_hash.to_yojson state_hash)
                    ; ("error", `String (Caqti_error.show err))
                    ] ;
                Conn.rollback ()
            | Ok block_id -> (
                [%log info]
                  "Adding accounts accessed in block to archive database"
                  ~metadata:
                    [ ("block", State_hash.to_yojson state_hash)
                    ; ( "num_accounts_accessed"
                      , `Int (List.length accounts_accessed) )
                    ] ;
                match%bind
                  Caqti_async.Pool.use
                    (fun (module Conn : CONNECTION) ->
                      Accounts_accessed.add_accounts_if_don't_exist
                        (module Conn)
                        block_id accounts_accessed)
                    pool
                with
                | Error err ->
                    [%log error]
                      "Could not add accounts accessed in block to archive \
                       database, rolling back transaction"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ("error", `String (Caqti_error.show err))
                        ] ;
                    Conn.rollback ()
                | Ok _block_and_account_ids -> (
                    [%log info]
                      "Adding account creation fees to archive database"
                      ~metadata:
                        [ ("block", State_hash.to_yojson state_hash)
                        ; ( "num_accounts_created"
                          , `Int (List.length accounts_created) )
                        ] ;
                    match%bind
                      Caqti_async.Pool.use
                        (fun (module Conn : CONNECTION) ->
                          Accounts_created.add_accounts_created_if_don't_exist
                            (module Conn)
                            block_id accounts_created)
                        pool
                    with
                    | Ok _block_and_public_key_ids ->
                        [%log info]
                          "Added block data, accounts accessed, and accounts \
                           created for $state_hash, committing transaction"
                          ~metadata:
                            [ ( "state_hash"
                              , Mina_base.State_hash.to_yojson (hash block) )
                            ] ;
                        Conn.commit ()
                    | Error err ->
                        [%log warn]
                          "Could not add account creation fees in block to \
                           archive database, rolling back transaction"
                          ~metadata:
                            [ ("state_hash", State_hash.to_yojson state_hash)
                            ; ("error", `String (Caqti_error.show err))
                            ] ;
                        Conn.rollback () ) ) ))
      pool
  in
  retry ~f:add ~logger ~error_str:"add_block_aux" retries

let add_block_aux_precomputed ~constraint_constants ~logger ?retries ~pool
    ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:(Block.add_from_precomputed ~constraint_constants)
    ~hash:(fun block ->
      ( block.External_transition.Precomputed_block.protocol_state
      |> Protocol_state.hashes )
        .state_hash)
    ~accounts_accessed:
      block.External_transition.Precomputed_block.accounts_accessed
    ~accounts_created:
      block.External_transition.Precomputed_block.accounts_created block

let add_block_aux_extensional ~logger ?retries ~pool ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:Block.add_from_extensional
    ~hash:(fun (block : Extensional.Block.t) -> block.state_hash)
    ~accounts_accessed:block.Extensional.Block.accounts_accessed
    ~accounts_created:block.Extensional.Block.accounts_created block

let run pool reader ~constraint_constants ~logger ~delete_older_than :
    unit Deferred.t =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier
        (Breadcrumb_added { block; accounts_accessed; accounts_created; _ })
      -> (
        let add_block = Block.add_if_doesn't_exist ~constraint_constants in
        let hash = State_hash.With_state_hashes.state_hash in
        match%bind
          add_block_aux ~logger ~pool ~delete_older_than ~hash ~add_block
            ~accounts_accessed ~accounts_created
            (With_hash.map ~f:External_transition.decompose block)
        with
        | Error e ->
            let state_hash = hash block in
            [%log warn]
              ~metadata:
                [ ("block", State_hash.to_yojson state_hash)
                ; ("error", `String (Caqti_error.show e))
                ]
              "Failed to archive block: $block, see $error" ;
            Deferred.unit
        | Ok () ->
            Deferred.unit )
    | Transition_frontier _ ->
        Deferred.unit
    | Transaction_pool { added; removed = _ } ->
        let%map _ =
          Caqti_async.Pool.use
            (fun (module Conn : CONNECTION) ->
              let%map () =
                Deferred.List.iter added ~f:(fun command ->
                    match%map
                      User_command.add_if_doesn't_exist (module Conn) command
                    with
                    | Ok _ ->
                        ()
                    | Error e ->
                        [%log warn]
                          ~metadata:
                            [ ("error", `String (Caqti_error.show e))
                            ; ( "command"
                              , Mina_base.User_command.to_yojson command )
                            ]
                          "Failed to archive user command $command from \
                           transaction pool: $block, see $error")
              in
              Ok ())
            pool
        in
        ())

let add_genesis_accounts ~logger ~(runtime_config_opt : Runtime_config.t option)
    pool =
  match runtime_config_opt with
  | None ->
      Deferred.unit
  | Some runtime_config -> (
      let accounts =
        match Option.map runtime_config.ledger ~f:(fun l -> l.base) with
        | Some (Accounts accounts) ->
            Genesis_ledger_helper.Accounts.to_full accounts
        | Some (Named name) -> (
            match Genesis_ledger.fetch_ledger name with
            | Some (module M) ->
                [%log info] "Found ledger with name $ledger_name"
                  ~metadata:[ ("ledger_name", `String name) ] ;
                Lazy.force M.accounts
            | None ->
                [%log error]
                  "Could not find a built-in ledger named $ledger_name"
                  ~metadata:[ ("ledger_name", `String name) ] ;
                failwith
                  "Could not add genesis accounts: Named ledger not found" )
        | _ ->
            failwith "No accounts found in runtime config file"
      in
      let add_accounts () =
        Caqti_async.Pool.use
          (fun (module Conn : CONNECTION) ->
            let open Deferred.Result.Let_syntax in
            let%bind () = Conn.start () in
            let rec go accounts =
              let open Deferred.Let_syntax in
              match accounts with
              | [] ->
                  Deferred.Result.return ()
              | (_, account) :: accounts' -> (
                  match%bind
                    Timing_info.add_if_doesn't_exist (module Conn) account
                  with
                  | Error e as err ->
                      [%log error]
                        ~metadata:
                          [ ("account", Account.to_yojson account)
                          ; ("error", `String (Caqti_error.show e))
                          ]
                        "Failed to add genesis account: $account, see $error" ;
                      let%map _ = Conn.rollback () in
                      err
                  | Ok _ ->
                      go accounts' )
            in
            let%bind () = go accounts in
            Conn.commit ())
          pool
      in
      match%map
        retry ~f:add_accounts ~logger ~error_str:"add_genesis_accounts" 3
      with
      | Error e ->
          [%log warn] "genesis accounts could not be added"
            ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
          failwith "Failed to add genesis accounts"
      | Ok () ->
          () )

let create_metrics_server ~logger ~metrics_server_port ~missing_blocks_width
    pool =
  match metrics_server_port with
  | None ->
      return ()
  | Some port ->
      let missing_blocks_width =
        Option.value ~default:Metrics.default_missing_blocks_width
          missing_blocks_width
      in
      let%bind metric_server =
        Mina_metrics.Archive.create_archive_server ~port ~logger ()
      in
      let interval =
        Float.of_int (Mina_compile_config.block_window_duration_ms * 2)
      in
      let rec go () =
        let%bind () =
          Metrics.update pool metric_server ~logger ~missing_blocks_width
        in
        let%bind () = after (Time.Span.of_ms interval) in
        go ()
      in
      go ()

let setup_server ~metrics_server_port ~constraint_constants ~logger
    ~postgres_address ~server_port ~delete_older_than ~runtime_config_opt
    ~missing_blocks_width =
  let where_to_listen =
    Async.Tcp.Where_to_listen.bind_to All_addresses (On_port server_port)
  in
  let reader, writer = Strict_pipe.create ~name:"archive" Synchronous in
  let precomputed_block_reader, precomputed_block_writer =
    Strict_pipe.create ~name:"precomputed_archive_block" Synchronous
  in
  let extensional_block_reader, extensional_block_writer =
    Strict_pipe.create ~name:"extensional_archive_block" Synchronous
  in
  let implementations =
    [ Async.Rpc.Rpc.implement Archive_rpc.t (fun () archive_diff ->
          Strict_pipe.Writer.write writer archive_diff)
    ; Async.Rpc.Rpc.implement Archive_rpc.precomputed_block
        (fun () precomputed_block ->
          Strict_pipe.Writer.write precomputed_block_writer precomputed_block)
    ; Async.Rpc.Rpc.implement Archive_rpc.extensional_block
        (fun () extensional_block ->
          Strict_pipe.Writer.write extensional_block_writer extensional_block)
    ]
  in
  match Caqti_async.connect_pool ~max_size:30 postgres_address with
  | Error e ->
      [%log error]
        "Failed to create a Caqti pool for Postgresql, see error: $error"
        ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
      Deferred.unit
  | Ok pool ->
      let%bind () = add_genesis_accounts pool ~logger ~runtime_config_opt in
      run ~constraint_constants pool reader ~logger ~delete_older_than
      |> don't_wait_for ;
      Strict_pipe.Reader.iter precomputed_block_reader
        ~f:(fun precomputed_block ->
          match%map
            add_block_aux_precomputed ~logger ~pool ~constraint_constants
              ~delete_older_than precomputed_block
          with
          | Error e ->
              [%log warn]
                "Precomputed block $block could not be archived: $error"
                ~metadata:
                  [ ( "block"
                    , (Protocol_state.hashes precomputed_block.protocol_state)
                        .state_hash |> State_hash.to_yojson )
                  ; ("error", `String (Caqti_error.show e))
                  ]
          | Ok _block_id ->
              ())
      |> don't_wait_for ;
      Strict_pipe.Reader.iter extensional_block_reader
        ~f:(fun extensional_block ->
          match%map
            add_block_aux_extensional ~logger ~pool ~delete_older_than
              extensional_block
          with
          | Error e ->
              [%log warn]
                "Extensional block $block could not be archived: $error"
                ~metadata:
                  [ ( "block"
                    , extensional_block.state_hash |> State_hash.to_yojson )
                  ; ("error", `String (Caqti_error.show e))
                  ]
          | Ok _block_id ->
              ())
      |> don't_wait_for ;
      Deferred.ignore_m
      @@ Tcp.Server.create
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 [%log error]
                   "Exception while handling TCP server request: $error"
                   ~metadata:
                     [ ("error", `String (Core.Exn.to_string_mach exn))
                     ; ("context", `String "rpc_tcp_server")
                     ]))
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             Async.Rpc.Connection.server_with_close reader writer
               ~implementations:
                 (Async.Rpc.Implementations.create_exn ~implementations
                    ~on_unknown_rpc:`Raise)
               ~connection_state:(fun _ -> ())
               ~on_handshake_error:
                 (`Call
                   (fun exn ->
                     [%log error]
                       "Exception while handling RPC server request from \
                        $address: $error"
                       ~metadata:
                         [ ("error", `String (Core.Exn.to_string_mach exn))
                         ; ("context", `String "rpc_server")
                         ; ( "address"
                           , `String (Unix.Inet_addr.to_string address) )
                         ] ;
                     Deferred.unit)))
      |> don't_wait_for ;
      (*Update archive metrics*)
      create_metrics_server ~logger ~metrics_server_port ~missing_blocks_width
        pool
      |> don't_wait_for ;
      [%log info] "Archive process ready. Clients can now connect" ;
      Async.never ()

module For_test = struct
  let assert_parent_exist ~parent_id ~parent_hash conn =
    let open Deferred.Result.Let_syntax in
    match parent_id with
    | Some id ->
        let%map Block.{ state_hash = actual; _ } = Block.load conn ~id in
        [%test_result: string]
          ~expect:(parent_hash |> State_hash.to_base58_check)
          actual
    | None ->
        failwith "Failed to find parent block in database"
end
