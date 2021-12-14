(* processor.ml -- database processing for archive node *)

module Archive_rpc = Rpc
open Async
open Core
open Caqti_async
open Mina_base
open Mina_state
open Mina_transition
open Pipe_lib
open Signature_lib
open Pickles_types

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

module Snapp_state_data = struct
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fp : Pickles.Backend.Tick.Field.t) =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_state_data"
      ~cols:([ "field" ], Caqti_type.string)
      (module Conn)
      (Pickles.Backend.Tick.Field.to_string fp)
end

module Snapp_state_data_array = struct
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : Pickles.Backend.Tick.Field.t array) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int array) =
      Mina_caqti.deferred_result_list_map (Array.to_list fps)
        ~f:(Snapp_state_data.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_state_data_array"
      ~cols:([ "element_ids" ], Mina_caqti.array_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      element_ids
end

module Snapp_states = struct
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t option, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int option array) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps)
        ~f:
          ( Mina_caqti.add_if_some
          @@ Snapp_state_data.add_if_doesn't_exist (module Conn) )
      >>| Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_states"
      ~cols:([ "element_ids" ], Mina_caqti.array_nullable_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      element_ids
end

module Snapp_verification_keys = struct
  type t = { verification_key : string; hash : string }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ string; string ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (vk :
        ( Pickles.Side_loaded.Verification_key.t
        , Pickles.Backend.Tick.Field.t )
        With_hash.Stable.Latest.t) =
    let verification_key =
      Binable.to_string
        (module Pickles.Side_loaded.Verification_key.Stable.Latest)
        vk.data
      |> Base64.encode_exn
    in
    let hash = Pickles.Backend.Tick.Field.to_string vk.hash in
    let value = { hash; verification_key } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_verification_keys" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_permissions = struct
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
      | Permissions.Auth_required.Both ->
          "both"
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
      | "both" ->
          Result.return Permissions.Auth_required.Both
      | "impossible" ->
          Result.return Permissions.Auth_required.Impossible
      | s ->
          Result.Error (sprintf "Failed to decode: \"%s\"" s)
    in
    Caqti_type.enum ~encode ~decode "snapp_auth_required_type"

  type t =
    { stake : bool
    ; edit_state : Permissions.Auth_required.t
    ; send : Permissions.Auth_required.t
    ; receive : Permissions.Auth_required.t
    ; set_delegate : Permissions.Auth_required.t
    ; set_permissions : Permissions.Auth_required.t
    ; set_verification_key : Permissions.Auth_required.t
    ; set_snapp_uri : Permissions.Auth_required.t
    ; edit_sequence_state : Permissions.Auth_required.t
    ; set_token_symbol : Permissions.Auth_required.t
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ bool
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
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION) (perms : Permissions.t) =
    let value =
      { stake = perms.stake
      ; edit_state = perms.edit_state
      ; send = perms.send
      ; receive = perms.receive
      ; set_delegate = perms.set_delegate
      ; set_permissions = perms.set_permissions
      ; set_verification_key = perms.set_verification_key
      ; set_snapp_uri = perms.set_snapp_uri
      ; edit_sequence_state = perms.edit_sequence_state
      ; set_token_symbol = perms.set_token_symbol
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_permissions" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_timing_info = struct
  type t =
    { initial_minimum_balance : int64
    ; cliff_time : int64
    ; vesting_period : int64
    ; vesting_increment : int64
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64; int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timing_info : Party.Update.Timing_info.t) =
    let initial_minimum_balance =
      timing_info.initial_minimum_balance |> Currency.Balance.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let cliff_time = timing_info.cliff_time |> Unsigned.UInt32.to_int64 in
    let vesting_period =
      timing_info.vesting_period |> Unsigned.UInt32.to_int64
    in
    let vesting_increment =
      timing_info.vesting_increment |> Currency.Amount.to_uint64
      |> Unsigned.UInt64.to_int64
    in
    let value =
      { initial_minimum_balance; cliff_time; vesting_period; vesting_increment }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_timing_info" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_updates = struct
  type t =
    { app_state_id : int
    ; delegate_id : int option
    ; verification_key_id : int option
    ; permissions_id : int option
    ; snapp_uri : string option
    ; token_symbol : string option
    ; timing_id : int option
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ int
        ; option int
        ; option int
        ; option int
        ; option string
        ; option string
        ; option int
        ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION) (update : Party.Update.t)
      =
    let open Deferred.Result.Let_syntax in
    let%bind app_state_id =
      Vector.map ~f:Snapp_basic.Set_or_keep.to_option update.app_state
      |> Snapp_states.add_if_doesn't_exist (module Conn)
    in
    let%bind delegate_id =
      Mina_caqti.add_if_snapp_set
        (Public_key.add_if_doesn't_exist (module Conn))
        update.delegate
    in
    let%bind verification_key_id =
      Mina_caqti.add_if_snapp_set
        (Snapp_verification_keys.add_if_doesn't_exist (module Conn))
        update.verification_key
    in
    let%bind permissions_id =
      Mina_caqti.add_if_snapp_set
        (Snapp_permissions.add_if_doesn't_exist (module Conn))
        update.permissions
    in
    let%bind timing_id =
      Mina_caqti.add_if_snapp_set
        (Snapp_timing_info.add_if_doesn't_exist (module Conn))
        update.timing
    in
    let snapp_uri = Snapp_basic.Set_or_keep.to_option update.snapp_uri in
    let token_symbol = Snapp_basic.Set_or_keep.to_option update.token_symbol in
    let value =
      { app_state_id
      ; delegate_id
      ; verification_key_id
      ; permissions_id
      ; snapp_uri
      ; token_symbol
      ; timing_id
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_updates" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_party_body = struct
  type t =
    { public_key_id : int
    ; update_id : int
    ; token_id : int64
    ; delta : int64
    ; increment_nonce : bool
    ; events_ids : int array
    ; sequence_events_ids : int array
    ; call_data_id : int
    ; depth : int
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ int
        ; int
        ; int64
        ; int64
        ; bool
        ; Mina_caqti.array_int_typ
        ; Mina_caqti.array_int_typ
        ; int
        ; int
        ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION) (body : Party.Body.t) =
    let open Deferred.Result.Let_syntax in
    let%bind public_key_id =
      Public_key.add_if_doesn't_exist (module Conn) body.pk
    in
    let%bind update_id =
      Snapp_updates.add_if_doesn't_exist (module Conn) body.update
    in
    let increment_nonce = body.increment_nonce in
    let%bind events_ids =
      Mina_caqti.deferred_result_list_map body.events
        ~f:(Snapp_state_data_array.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    let%bind sequence_events_ids =
      Mina_caqti.deferred_result_list_map body.sequence_events
        ~f:(Snapp_state_data_array.add_if_doesn't_exist (module Conn))
      >>| Array.of_list
    in
    let%bind call_data_id =
      Snapp_state_data.add_if_doesn't_exist (module Conn) body.call_data
    in
    let token_id =
      Unsigned.UInt64.to_int64 @@ Token_id.to_uint64 body.token_id
    in
    let delta =
      let magnitude =
        Currency.Amount.to_uint64 body.delta.magnitude
        |> Unsigned.UInt64.to_int64
      in
      match body.delta.sgn with
      | Sgn.Pos ->
          magnitude
      | Sgn.Neg ->
          Int64.neg magnitude
    in
    let depth = body.depth in
    let value =
      { public_key_id
      ; update_id
      ; token_id
      ; delta
      ; increment_nonce
      ; events_ids
      ; sequence_events_ids
      ; call_data_id
      ; depth
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_party_body" ~cols:(Fields.names, typ)
      ~tannot:(function
        | "events_ids" | "sequence_events_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      value
end

module Snapp_balance_bounds = struct
  type t = { balance_lower_bound : int64; balance_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (balance_bounds :
        Currency.Balance.t Mina_base.Snapp_predicate.Closed_interval.t) =
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
      ~table_name:"snapp_balance_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_nonce_bounds = struct
  type t = { nonce_lower_bound : int64; nonce_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (nonce_bounds :
        Mina_numbers.Account_nonce.t Mina_base.Snapp_predicate.Closed_interval.t)
      =
    let nonce_lower_bound = Unsigned.UInt32.to_int64 nonce_bounds.lower in
    let nonce_upper_bound = Unsigned.UInt32.to_int64 nonce_bounds.upper in
    let value = { nonce_lower_bound; nonce_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_nonce_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_account = struct
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
    let open Mina_caqti.Type_spec in
    let spec =
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
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (acct : Snapp_predicate.Account.t) =
    let open Deferred.Result.Let_syntax in
    let%bind balance_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_balance_bounds.add_if_doesn't_exist (module Conn))
        acct.balance
    in
    let%bind nonce_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_nonce_bounds.add_if_doesn't_exist (module Conn))
        acct.nonce
    in
    let%bind public_key_id =
      Mina_caqti.add_if_snapp_check
        (Public_key.add_if_doesn't_exist (module Conn))
        acct.public_key
    in
    let%bind delegate_id =
      Mina_caqti.add_if_snapp_check
        (Public_key.add_if_doesn't_exist (module Conn))
        acct.delegate
    in
    let%bind state_id =
      Vector.map ~f:Snapp_basic.Or_ignore.to_option acct.state
      |> Snapp_states.add_if_doesn't_exist (module Conn)
    in
    let%bind sequence_state_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_state_data.add_if_doesn't_exist (module Conn))
        acct.sequence_state
    in
    let receipt_chain_hash =
      Snapp_basic.Or_ignore.to_option acct.receipt_chain_hash
      |> Option.map ~f:Marlin_plonk_bindings_pasta_fp.to_string
    in
    let proved_state = Snapp_basic.Or_ignore.to_option acct.proved_state in
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
      ~table_name:"snapp_account" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_predicate = struct
  type t =
    { kind : Party.Predicate.Tag.t
    ; account_id : int option
    ; nonce : int64 option
    }
  [@@deriving fields, hlist]

  let snapp_predicate_kind_typ =
    let encode = function
      | Party.Predicate.Tag.Full ->
          "full"
      | Party.Predicate.Tag.Nonce ->
          "nonce"
      | Party.Predicate.Tag.Accept ->
          "accept"
    in
    let decode = function
      | "full" ->
          Result.return Party.Predicate.Tag.Full
      | "nonce" ->
          Result.return Party.Predicate.Tag.Nonce
      | "accept" ->
          Result.return Party.Predicate.Tag.Accept
      | _ ->
          Result.failf "Failed to decode snapp_predicate_kind_typ"
    in
    Caqti_type.enum "snapp_predicate_type" ~encode ~decode

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.[ snapp_predicate_kind_typ; option int; option int64 ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (predicate : Party.Predicate.t) =
    let open Deferred.Result.Let_syntax in
    let%bind account_id =
      match predicate with
      | Party.Predicate.Full acct ->
          Snapp_account.add_if_doesn't_exist (module Conn) acct >>| Option.some
      | _ ->
          return None
    in
    let kind = Party.Predicate.tag predicate in
    let nonce =
      match predicate with
      | Party.Predicate.Nonce nonce ->
          Option.some @@ Unsigned.UInt32.to_int64 nonce
      | _ ->
          None
    in
    let value = { kind; account_id; nonce } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_predicate" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_token_id_bounds = struct
  type t = { token_id_lower_bound : int64; token_id_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (token_id_bounds : Token_id.t Mina_base.Snapp_predicate.Closed_interval.t)
      =
    let token_id_lower_bound =
      token_id_bounds.lower |> Token_id.to_uint64 |> Unsigned.UInt64.to_int64
    in
    let token_id_upper_bound =
      token_id_bounds.upper |> Token_id.to_uint64 |> Unsigned.UInt64.to_int64
    in
    let value = { token_id_lower_bound; token_id_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_token_id_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_timestamp_bounds = struct
  type t = { timestamp_lower_bound : int64; timestamp_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timestamp_bounds :
        Block_time.t Mina_base.Snapp_predicate.Closed_interval.t) =
    let timestamp_lower_bound = Block_time.to_int64 timestamp_bounds.lower in
    let timestamp_upper_bound = Block_time.to_int64 timestamp_bounds.upper in
    let value = { timestamp_lower_bound; timestamp_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_timestamp_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_length_bounds = struct
  type t = { length_lower_bound : int64; length_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (length_bounds :
        Unsigned.uint32 Mina_base.Snapp_predicate.Closed_interval.t) =
    let length_lower_bound = Unsigned.UInt32.to_int64 length_bounds.lower in
    let length_upper_bound = Unsigned.UInt32.to_int64 length_bounds.upper in
    let value = { length_lower_bound; length_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_length_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_amount_bounds = struct
  type t = { amount_lower_bound : int64; amount_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (amount_bounds :
        Currency.Amount.t Mina_base.Snapp_predicate.Closed_interval.t) =
    let amount_lower_bound =
      Currency.Amount.to_uint64 amount_bounds.lower |> Unsigned.UInt64.to_int64
    in
    let amount_upper_bound =
      Currency.Amount.to_uint64 amount_bounds.upper |> Unsigned.UInt64.to_int64
    in
    let value = { amount_lower_bound; amount_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_amount_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_global_slot_bounds = struct
  type t = { global_slot_lower_bound : int64; global_slot_upper_bound : int64 }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int64; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (global_slot_bounds :
        Mina_numbers.Global_slot.t Mina_base.Snapp_predicate.Closed_interval.t)
      =
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
      ~table_name:"snapp_global_slot_bounds" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Timing_info = struct
  type t =
    { public_key_id : int
    ; token : int64
    ; initial_balance : int64
    ; initial_minimum_balance : int64
    ; cliff_time : int64
    ; cliff_amount : int64
    ; vesting_period : int64
    ; vesting_increment : int64
    }
  [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.[ int; int64; int64; int64; int64; int64; int64; int64 ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

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
          let token =
            Token_id.to_uint64 (Account.token acc) |> Unsigned.UInt64.to_int64
          in
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
end

module Snapp_epoch_ledger = struct
  type t = { hash_id : int option; total_currency_id : int option }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ option int; option int ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (epoch_ledger : _ Epoch_ledger.Poly.t) =
    let open Deferred.Result.Let_syntax in
    let%bind hash_id =
      Mina_caqti.add_if_snapp_check
        (Snarked_ledger_hash.add_if_doesn't_exist (module Conn))
        epoch_ledger.hash
    in
    let%bind total_currency_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_amount_bounds.add_if_doesn't_exist (module Conn))
        epoch_ledger.total_currency
    in
    let value = { hash_id; total_currency_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_epoch_ledger" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_epoch_data = struct
  type t =
    { epoch_ledger_id : int
    ; epoch_seed : string option
    ; start_checkpoint : string option
    ; lock_checkpoint : string option
    ; epoch_length_id : int option
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ int; option string; option string; option string; option int ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (epoch_data : Mina_base.Snapp_predicate.Protocol_state.Epoch_data.t) =
    let open Deferred.Result.Let_syntax in
    let%bind epoch_ledger_id =
      Snapp_epoch_ledger.add_if_doesn't_exist (module Conn) epoch_data.ledger
    in
    let%bind epoch_length_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_length_bounds.add_if_doesn't_exist (module Conn))
        epoch_data.epoch_length
    in
    let epoch_seed =
      Snapp_basic.Or_ignore.to_option epoch_data.seed
      |> Option.map ~f:Marlin_plonk_bindings_pasta_fp.to_string
    in
    let start_checkpoint =
      Snapp_basic.Or_ignore.to_option epoch_data.start_checkpoint
      |> Option.map ~f:Marlin_plonk_bindings_pasta_fp.to_string
    in
    let lock_checkpoint =
      Snapp_basic.Or_ignore.to_option epoch_data.lock_checkpoint
      |> Option.map ~f:Marlin_plonk_bindings_pasta_fp.to_string
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
      ~table_name:"snapp_epoch_data" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_party = struct
  type t =
    { body_id : int; predicate_id : int; authorization_kind : Control.Tag.t }
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
    Caqti_type.enum "snapp_authorization_kind_type" ~encode ~decode

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int; int; authorization_kind_typ ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION) (party : Party.t) =
    let open Deferred.Result.Let_syntax in
    let%bind body_id =
      Snapp_party_body.add_if_doesn't_exist (module Conn) party.data.body
    in
    let%bind predicate_id =
      Snapp_predicate.add_if_doesn't_exist (module Conn) party.data.predicate
    in
    let authorization_kind = Control.tag party.authorization in
    let value = { body_id; predicate_id; authorization_kind } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_party" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_fee_payers = struct
  type t = { body_id : int; nonce : int64 } [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fp : Party.Predicated.Fee_payer.t) =
    let open Deferred.Result.Let_syntax in
    let%bind body_id =
      Snapp_party_body.add_if_doesn't_exist
        (module Conn)
        (Party.Body.of_fee_payer fp.body)
    in
    let nonce = fp.predicate |> Unsigned.UInt32.to_int64 in
    let value = { body_id; nonce } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_fee_payers" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Snapp_predicate_protocol_states = struct
  type t =
    { snarked_ledger_hash_id : int option
    ; snarked_next_available_token_id : int option
    ; timestamp_id : int option
    ; blockchain_length_id : int option
    ; min_window_density_id : int option
    ; total_currency_id : int option
    ; curr_global_slot_since_hard_fork : int option
    ; global_slot_since_genesis : int option
    ; staking_epoch_data_id : int
    ; next_epoch_data : int
    }
  [@@deriving fields, hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; int
        ; int
        ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (ps : Mina_base.Snapp_predicate.Protocol_state.t) =
    let open Deferred.Result.Let_syntax in
    let%bind snarked_ledger_hash_id =
      Mina_caqti.add_if_snapp_check
        (Snarked_ledger_hash.add_if_doesn't_exist (module Conn))
        ps.snarked_ledger_hash
    in
    let%bind snarked_next_available_token_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_token_id_bounds.add_if_doesn't_exist (module Conn))
        ps.snarked_next_available_token
    in
    let%bind timestamp_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_timestamp_bounds.add_if_doesn't_exist (module Conn))
        ps.timestamp
    in
    let%bind blockchain_length_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_length_bounds.add_if_doesn't_exist (module Conn))
        ps.blockchain_length
    in
    let%bind min_window_density_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_length_bounds.add_if_doesn't_exist (module Conn))
        ps.min_window_density
    in
    let%bind total_currency_id =
      Mina_caqti.add_if_snapp_check
        (Snapp_amount_bounds.add_if_doesn't_exist (module Conn))
        ps.total_currency
    in
    let%bind curr_global_slot_since_hard_fork =
      Mina_caqti.add_if_snapp_check
        (Snapp_global_slot_bounds.add_if_doesn't_exist (module Conn))
        ps.global_slot_since_hard_fork
    in
    let%bind global_slot_since_genesis =
      Mina_caqti.add_if_snapp_check
        (Snapp_global_slot_bounds.add_if_doesn't_exist (module Conn))
        ps.global_slot_since_genesis
    in
    let%bind staking_epoch_data_id =
      Snapp_epoch_data.add_if_doesn't_exist (module Conn) ps.staking_epoch_data
    in
    let%bind next_epoch_data =
      Snapp_epoch_data.add_if_doesn't_exist (module Conn) ps.next_epoch_data
    in
    let value =
      { snarked_ledger_hash_id
      ; snarked_next_available_token_id
      ; timestamp_id
      ; blockchain_length_id
      ; min_window_density_id
      ; total_currency_id
      ; curr_global_slot_since_hard_fork
      ; global_slot_since_genesis
      ; staking_epoch_data_id
      ; next_epoch_data
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name:"snapp_predicate_protocol_states" ~cols:(Fields.names, typ)
      (module Conn)
      value
end

module Epoch_data = struct
  type t = { seed : string; ledger_hash_id : int }

  let typ =
    let encode t = Ok (t.seed, t.ledger_hash_id) in
    let decode (seed, ledger_hash_id) = Ok { seed; ledger_hash_id } in
    let rep = Caqti_type.(tup2 string int) in
    Caqti_type.custom ~encode ~decode rep

  (* for extensional blocks, we have just the seed and ledger hash *)
  let add_from_seed_and_ledger_hash_id (module Conn : CONNECTION) ~seed
      ~ledger_hash_id =
    let open Deferred.Result.Let_syntax in
    let seed = Epoch_seed.to_base58_check seed in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt typ Caqti_type.int
           "SELECT id FROM epoch_data WHERE seed = ? AND ledger_hash_id = ?")
        { seed; ledger_hash_id }
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO epoch_data (seed, ledger_hash_id) VALUES (?, ?)
                   RETURNING id
             |sql})
          { seed; ledger_hash_id }

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Mina_base.Epoch_data.Value.t) =
    let open Deferred.Result.Let_syntax in
    let Mina_base.Epoch_ledger.Poly.{ hash; _ } =
      Mina_base.Epoch_data.Poly.ledger t
    in
    let%bind ledger_hash_id =
      Snarked_ledger_hash.add_if_doesn't_exist (module Conn) hash
    in
    add_from_seed_and_ledger_hash_id
      (module Conn)
      ~seed:(Mina_base.Epoch_data.Poly.seed t)
      ~ledger_hash_id
end

module User_command = struct
  module Signed_command = struct
    type t =
      { typ : string
      ; fee_payer_id : int
      ; source_id : int
      ; receiver_id : int
      ; fee_token : int64
      ; token : int64
      ; nonce : int
      ; amount : int64 option
      ; fee : int64
      ; valid_until : int64 option
      ; memo : string
      ; hash : string
      }
    [@@deriving hlist]

    let typ =
      let open Mina_caqti.Type_spec in
      let spec =
        Caqti_type.
          [ string
          ; int
          ; int
          ; int
          ; int64
          ; int64
          ; int
          ; option int64
          ; int64
          ; option int64
          ; string
          ; string
          ]
      in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

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
                    "snapp" )
            ; fee_payer_id
            ; source_id
            ; receiver_id
            ; fee_token =
                Signed_command.fee_token t |> Token_id.to_uint64
                |> Unsigned.UInt64.to_int64
            ; token =
                Signed_command.token t |> Token_id.to_uint64
                |> Unsigned.UInt64.to_int64
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
            ; memo = Signed_command.memo t |> Signed_command_memo.to_string
            ; hash = transaction_hash |> Transaction_hash.to_base58_check
            }
  end

  module Snapp_command = struct
    type t =
      { snapp_fee_payer_id : int
      ; snapp_other_parties_ids : int array
      ; snapp_predicate_protocol_state_id : int
      ; hash : string
      }
    [@@deriving fields, hlist]

    let typ =
      let open Mina_caqti.Type_spec in
      let spec = Caqti_type.[ int; Mina_caqti.array_int_typ; int; string ] in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let find_opt (module Conn : CONNECTION)
        ~(transaction_hash : Transaction_hash.t) =
      Conn.find_opt
        ( Caqti_request.find_opt Caqti_type.string Caqti_type.int
        @@ Mina_caqti.select_cols ~select:"id" ~table_name:"snapp_commands"
             [ "hash" ] )
        (Transaction_hash.to_base58_check transaction_hash)

    let add_if_doesn't_exist (module Conn : CONNECTION) (ps : Parties.t) =
      let open Deferred.Result.Let_syntax in
      let%bind snapp_fee_payer_id =
        Snapp_fee_payers.add_if_doesn't_exist (module Conn) ps.fee_payer.data
      in
      let%bind snapp_other_parties_ids =
        Mina_caqti.deferred_result_list_map ps.other_parties
          ~f:(Snapp_party.add_if_doesn't_exist (module Conn))
        >>| Array.of_list
      in
      let%bind snapp_predicate_protocol_state_id =
        Snapp_predicate_protocol_states.add_if_doesn't_exist
          (module Conn)
          ps.protocol_state
      in
      let hash =
        Transaction_hash.hash_command (Parties ps)
        |> Transaction_hash.to_base58_check
      in
      let value =
        { snapp_fee_payer_id
        ; snapp_other_parties_ids
        ; snapp_predicate_protocol_state_id
        ; hash
        }
      in
      Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
        ~table_name:"snapp_commands" ~cols:(Fields.names, typ)
        ~tannot:(function
          | "snapp_other_parties_ids" -> Some "int[]" | _ -> None)
        (module Conn)
        value
  end

  let as_signed_command (t : User_command.t) : Mina_base.Signed_command.t =
    match t with
    | Signed_command c ->
        c
    | Parties _ ->
        let `Needs_some_work_for_snapps_on_mainnet =
          Mina_base.Util.todo_snapps
        in
        failwith "TODO"

  let via (t : User_command.t) : [ `Parties | `Ident ] =
    match t with Signed_command _ -> `Ident | Parties _ -> `Parties

  let add_if_doesn't_exist conn (t : User_command.t) =
    match t with
    | Signed_command sc ->
        Signed_command.add_if_doesn't_exist conn ~via:(via t) sc
    | Parties ps ->
        Snapp_command.add_if_doesn't_exist conn ps

  let find conn ~(transaction_hash : Transaction_hash.t) =
    let open Deferred.Result.Let_syntax in
    let%bind signed_command_id =
      Signed_command.find conn ~transaction_hash
      >>| Option.map ~f:(fun id -> `Signed_command_id id)
    in
    let%map snapp_command_id =
      Snapp_command.find_opt conn ~transaction_hash
      >>| Option.map ~f:(fun id -> `Snapp_command_id id)
    in
    Option.first_some signed_command_id snapp_command_id

  (* meant to work with either a signed command, or a snapp *)
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
      ; fee_token =
          user_cmd.fee_token |> Token_id.to_uint64 |> Unsigned.UInt64.to_int64
      ; token = user_cmd.token |> Token_id.to_uint64 |> Unsigned.UInt64.to_int64
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
      ; memo = user_cmd.memo |> Signed_command_memo.to_string
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
    | Some (`Snapp_command_id _user_cmd_id) ->
        failwith "Unexpected snapp command"
end

module Internal_command = struct
  type t =
    { typ : string
    ; receiver_id : int
    ; fee : int64
    ; token : int64
    ; hash : string
    }

  let typ =
    let encode t = Ok ((t.typ, t.receiver_id, t.fee, t.token), t.hash) in
    let decode ((typ, receiver_id, fee, token), hash) =
      Ok { typ; receiver_id; fee; token; hash }
    in
    let rep = Caqti_type.(tup2 (tup4 string int int64 int64) string) in
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
          ; token =
              internal_cmd.token |> Token_id.to_uint64
              |> Unsigned.UInt64.to_int64
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
    ; token : int64
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
    let rep = Caqti_type.(tup2 (tup4 string int int64 int64) string) in
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
          ; token = Token_id.to_string t.fee_token |> Int64.of_string
          ; hash = transaction_hash |> Transaction_hash.to_base58_check
          }
end

module Coinbase = struct
  type t = { receiver_id : int; amount : int64; hash : string }

  let coinbase_typ = "coinbase"

  let typ =
    let encode t =
      Ok
        ( ( coinbase_typ
          , t.receiver_id
          , t.amount
          , Token_id.(to_string default) |> Int64.of_string )
        , t.hash )
    in
    let decode ((_, receiver_id, amount, _), hash) =
      Ok { receiver_id; amount; hash }
    in
    let rep = Caqti_type.(tup2 (tup4 string int int64 int64) string) in
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

module Balance = struct
  type t = { id : int; public_key_id : int; balance : int64 } [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int; int; int64 ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let balance_to_int64 (balance : Currency.Balance.t) : int64 =
    balance |> Currency.Balance.to_amount |> Currency.Amount.to_uint64
    |> Unsigned.UInt64.to_int64

  let find (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) =
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup2 int int64)
         Caqti_type.int
         {sql| SELECT id FROM balances
               WHERE public_key_id = $1
               AND balance = $2
         |sql})
      (public_key_id, balance_to_int64 balance)

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int
         Caqti_type.(tup2 int int64)
         {sql| SELECT public_key_id, balance FROM balances
               WHERE id = $1
         |sql})
      id

  let add (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup2 int int64)
         Caqti_type.int
         {sql| INSERT INTO balances (public_key_id, balance) VALUES (?, ?) RETURNING id |sql})
      (public_key_id, balance_to_int64 balance)

  let add_if_doesn't_exist (module Conn : CONNECTION) ~(public_key_id : int)
      ~(balance : Currency.Balance.t) =
    let open Deferred.Result.Let_syntax in
    match%bind find (module Conn) ~public_key_id ~balance with
    | Some balance_id ->
        return balance_id
    | None ->
        add (module Conn) ~public_key_id ~balance
end

module Block_and_internal_command = struct
  type t =
    { block_id : int
    ; internal_command_id : int
    ; sequence_no : int
    ; secondary_sequence_no : int
    ; receiver_account_creation_fee_paid : int64 option
    ; receiver_balance_id : int
    }
  [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec = Caqti_type.[ int; int; int; int; option int64; int ] in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add (module Conn : CONNECTION) ~block_id ~internal_command_id ~sequence_no
      ~secondary_sequence_no ~receiver_account_creation_fee_paid
      ~receiver_balance_id =
    Conn.exec
      (Caqti_request.exec typ
         {sql| INSERT INTO blocks_internal_commands
                (block_id, internal_command_id, sequence_no, secondary_sequence_no,
                 receiver_account_creation_fee_paid,receiver_balance)
                VALUES (?, ?, ?, ?, ?, ?)
         |sql})
      { block_id
      ; internal_command_id
      ; sequence_no
      ; secondary_sequence_no
      ; receiver_account_creation_fee_paid
      ; receiver_balance_id
      }

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
      ~internal_command_id ~sequence_no ~secondary_sequence_no
      ~receiver_account_creation_fee_paid ~receiver_balance_id =
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
          ~receiver_account_creation_fee_paid ~receiver_balance_id
end

module Block_and_signed_command = struct
  type t =
    { block_id : int
    ; user_command_id : int
    ; sequence_no : int
    ; status : string
    ; failure_reason : string option
    ; fee_payer_account_creation_fee_paid : int64 option
    ; receiver_account_creation_fee_paid : int64 option
    ; created_token : int64 option
    ; fee_payer_balance_id : int
    ; source_balance_id : int option
    ; receiver_balance_id : int option
    }
  [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ int
        ; int
        ; int
        ; string
        ; option string
        ; option int64
        ; option int64
        ; option int64
        ; int
        ; option int
        ; option int
        ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let add (module Conn : CONNECTION) ~block_id ~user_command_id ~sequence_no
      ~status ~failure_reason ~fee_payer_account_creation_fee_paid
      ~receiver_account_creation_fee_paid ~created_token ~fee_payer_balance_id
      ~source_balance_id ~receiver_balance_id =
    let failure_reason =
      Option.map ~f:Transaction_status.Failure.to_string failure_reason
    in
    let amount_to_int64 x =
      Unsigned.UInt64.to_int64 (Currency.Amount.to_uint64 x)
    in
    let fee_payer_account_creation_fee_paid =
      Option.map ~f:amount_to_int64 fee_payer_account_creation_fee_paid
    in
    let receiver_account_creation_fee_paid =
      Option.map ~f:amount_to_int64 receiver_account_creation_fee_paid
    in
    let created_token =
      Option.map created_token ~f:(fun tid ->
          Unsigned.UInt64.to_int64 (Token_id.to_uint64 tid))
    in
    Conn.exec
      (Caqti_request.exec typ
         {sql| INSERT INTO blocks_user_commands
                 (block_id,
                 user_command_id,
                 sequence_no,
                 status,
                 failure_reason,
                 fee_payer_account_creation_fee_paid,
                 receiver_account_creation_fee_paid,
                 created_token,
                 fee_payer_balance,
                 source_balance,
                 receiver_balance)
               VALUES (?, ?, ?, ?::user_command_status, ?, ?, ?, ?, ?, ?, ?)
         |sql})
      { block_id
      ; user_command_id
      ; sequence_no
      ; status
      ; failure_reason
      ; fee_payer_account_creation_fee_paid
      ; receiver_account_creation_fee_paid
      ; created_token
      ; fee_payer_balance_id
      ; source_balance_id
      ; receiver_balance_id
      }

  let add_with_status (module Conn : CONNECTION) ~block_id ~user_command_id
      ~sequence_no ~(status : Transaction_status.t) ~fee_payer_id ~source_id
      ~receiver_id =
    let open Deferred.Result.Let_syntax in
    let ( status_str
        , failure_reason
        , fee_payer_account_creation_fee_paid
        , receiver_account_creation_fee_paid
        , created_token
        , { Transaction_status.Balance_data.fee_payer_balance
          ; source_balance
          ; receiver_balance
          } ) =
      match status with
      | Applied
          ( { fee_payer_account_creation_fee_paid
            ; receiver_account_creation_fee_paid
            ; created_token
            }
          , balances ) ->
          ( "applied"
          , None
          , fee_payer_account_creation_fee_paid
          , receiver_account_creation_fee_paid
          , created_token
          , balances )
      | Failed (failure, balances) ->
          ("failed", Some failure, None, None, None, balances)
    in
    let add_optional_balance id balance =
      match balance with
      | None ->
          Deferred.Result.return None
      | Some balance ->
          let%map balance_id =
            Balance.add_if_doesn't_exist
              (module Conn)
              ~public_key_id:id ~balance
          in
          Some balance_id
    in
    (* Any transaction included in a block will have had its fee paid, so we can
     * assume the fee payer balance will be Some here *)
    let fee_payer_balance = Option.value_exn fee_payer_balance in
    let%bind fee_payer_balance_id =
      Balance.add_if_doesn't_exist
        (module Conn)
        ~public_key_id:fee_payer_id ~balance:fee_payer_balance
    in
    let%bind source_balance_id =
      add_optional_balance source_id source_balance
    in
    let%bind receiver_balance_id =
      add_optional_balance receiver_id receiver_balance
    in
    add
      (module Conn)
      ~block_id ~user_command_id ~sequence_no ~status:status_str ~failure_reason
      ~fee_payer_account_creation_fee_paid ~receiver_account_creation_fee_paid
      ~created_token ~fee_payer_balance_id ~source_balance_id
      ~receiver_balance_id

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id ~user_command_id
      ~sequence_no ~(status : string) ~failure_reason
      ~fee_payer_account_creation_fee_paid ~receiver_account_creation_fee_paid
      ~created_token ~fee_payer_balance_id ~source_balance_id
      ~receiver_balance_id =
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
          ~fee_payer_account_creation_fee_paid
          ~receiver_account_creation_fee_paid ~created_token
          ~fee_payer_balance_id ~source_balance_id ~receiver_balance_id

  let load (module Conn : CONNECTION) ~block_id ~user_command_id =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup2 int int)
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
           |sql})
      (block_id, user_command_id)
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
    ; ledger_hash : string
    ; height : int64
    ; global_slot_since_hard_fork : int64
    ; global_slot_since_genesis : int64
    ; timestamp : int64
    }
  [@@deriving hlist]

  let typ =
    let open Mina_caqti.Type_spec in
    let spec =
      Caqti_type.
        [ string
        ; option int
        ; string
        ; int
        ; int
        ; int
        ; int
        ; int
        ; string
        ; int64
        ; int64
        ; int64
        ; int64
        ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

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

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         {sql| SELECT state_hash, parent_id, parent_hash, creator_id,
                      block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id,
                      next_epoch_data_id, ledger_hash, height, global_slot,
                      global_slot_since_genesis, timestamp FROM blocks
               WHERE id = ?
         |sql})
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
        let%bind block_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               {sql| INSERT INTO blocks (state_hash, parent_id, parent_hash,
                      creator_id, block_winner_id,
                      snarked_ledger_hash_id, staking_epoch_data_id,
                      next_epoch_data_id, ledger_hash, height, global_slot,
                      global_slot_since_genesis, timestamp)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id
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
            ; ledger_hash =
                Protocol_state.blockchain_state protocol_state
                |> Blockchain_state.staged_ledger_hash
                |> Staged_ledger_hash.ledger_hash |> Ledger_hash.to_base58_check
            ; height =
                consensus_state
                |> Consensus.Data.Consensus_state.blockchain_length
                |> Unsigned.UInt32.to_int64
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
            }
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
        let account_creation_fee_of_fees_and_balance ?additional_fee fee balance
            =
          (* TODO: add transaction statuses to internal commands
             the archive lib should not know the details of
             account creation fees; the calculation below is
             a temporizing hack
          *)
          let fee_uint64 = Currency.Fee.to_uint64 fee in
          let balance_uint64 = Currency.Balance.to_uint64 balance in
          let account_creation_fee_uint64 =
            Currency.Fee.to_uint64 constraint_constants.account_creation_fee
          in
          (* for coinbases, an associated fee transfer may reduce
             the amount given to the coinbase receiver beyond
             the account creation fee
          *)
          let creation_deduction_uint64 =
            match additional_fee with
            | None ->
                account_creation_fee_uint64
            | Some fee' ->
                Unsigned.UInt64.add
                  (Currency.Fee.to_uint64 fee')
                  account_creation_fee_uint64
          in
          (* first compare guards against underflow in subtraction *)
          if
            Unsigned.UInt64.compare fee_uint64 creation_deduction_uint64 >= 0
            && Unsigned.UInt64.equal balance_uint64
                 (Unsigned.UInt64.sub fee_uint64 creation_deduction_uint64)
          then Some (Unsigned.UInt64.to_int64 account_creation_fee_uint64)
          else None
        in
        let%bind (_ : int) =
          Mina_caqti.deferred_result_list_fold transactions ~init:0
            ~f:(fun sequence_no -> function
            | { Mina_base.With_status.status
              ; data = Mina_base.Transaction.Command command
              } ->
                let user_command =
                  { Mina_base.With_status.status; data = command }
                in
                let%bind id =
                  User_command.add_if_doesn't_exist
                    (module Conn)
                    user_command.data
                in
                let%map () =
                  match command with
                  | Signed_command c ->
                      let%bind { fee_payer_id; source_id; receiver_id } =
                        User_command.Signed_command
                        .add_balance_public_keys_if_don't_exist
                          (module Conn)
                          c
                      in
                      Block_and_signed_command.add_with_status
                        (module Conn)
                        ~block_id ~user_command_id:id ~sequence_no
                        ~status:user_command.status ~fee_payer_id ~source_id
                        ~receiver_id
                      >>| ignore
                  | Parties _ ->
                      Deferred.Result.return ()
                in
                sequence_no + 1
            | { data = Fee_transfer fee_transfer_bundled; status } ->
                let balances =
                  Transaction_status.Fee_transfer_balance_data
                  .of_balance_data_exn
                    (Transaction_status.balance_data status)
                in
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
                      [ (id, balances.receiver1_balance) ]
                  | [ id2; id1 ] ->
                      (* the fold reverses the order of the infos from the fee transfers *)
                      [ (id1, balances.receiver1_balance)
                      ; (id2, Option.value_exn balances.receiver2_balance)
                      ]
                  | _ ->
                      failwith
                        "Unexpected number of single fee transfers in a fee \
                         transfer transaction"
                in
                let%map () =
                  Mina_caqti.deferred_result_list_fold
                    fee_transfer_infos_with_balances ~init:()
                    ~f:(fun
                         ()
                         ( ( fee_transfer_id
                           , secondary_sequence_no
                           , fee
                           , receiver_pk )
                         , balance )
                       ->
                      let%bind receiver_id =
                        Public_key.add_if_doesn't_exist
                          (module Conn)
                          receiver_pk
                      in
                      let%bind receiver_balance_id =
                        Balance.add_if_doesn't_exist
                          (module Conn)
                          ~public_key_id:receiver_id ~balance
                      in
                      let receiver_account_creation_fee_paid =
                        account_creation_fee_of_fees_and_balance fee balance
                      in
                      Block_and_internal_command.add
                        (module Conn)
                        ~block_id ~internal_command_id:fee_transfer_id
                        ~sequence_no ~secondary_sequence_no
                        ~receiver_account_creation_fee_paid ~receiver_balance_id
                      >>| ignore)
                in
                sequence_no + 1
            | { data = Coinbase coinbase; status } ->
                let balances =
                  Transaction_status.Coinbase_balance_data.of_balance_data_exn
                    (Transaction_status.balance_data status)
                in
                let%bind additional_fee =
                  match Mina_base.Coinbase.fee_transfer coinbase with
                  | None ->
                      return None
                  | Some { receiver_pk; fee } ->
                      let fee_transfer =
                        Mina_base.Fee_transfer.Single.create ~receiver_pk ~fee
                          ~fee_token:Token_id.default
                      in
                      let%bind id =
                        Fee_transfer.add_if_doesn't_exist
                          (module Conn)
                          fee_transfer `Via_coinbase
                      in
                      let%bind fee_transfer_receiver_id =
                        Public_key.add_if_doesn't_exist
                          (module Conn)
                          receiver_pk
                      in
                      let balance =
                        Option.value_exn balances.fee_transfer_receiver_balance
                      in
                      let%bind receiver_balance_id =
                        Balance.add_if_doesn't_exist
                          (module Conn)
                          ~public_key_id:fee_transfer_receiver_id ~balance
                      in
                      let receiver_account_creation_fee_paid =
                        account_creation_fee_of_fees_and_balance fee balance
                      in
                      let%bind () =
                        Block_and_internal_command.add
                          (module Conn)
                          ~block_id ~internal_command_id:id ~sequence_no
                          ~secondary_sequence_no:0
                          ~receiver_account_creation_fee_paid
                          ~receiver_balance_id
                      in
                      return (Some fee)
                in
                let%bind id =
                  Coinbase.add_if_doesn't_exist (module Conn) coinbase
                in
                let%bind coinbase_receiver_id =
                  Public_key.add_if_doesn't_exist
                    (module Conn)
                    coinbase.receiver
                in
                let%bind receiver_balance_id =
                  Balance.add_if_doesn't_exist
                    (module Conn)
                    ~public_key_id:coinbase_receiver_id
                    ~balance:balances.coinbase_receiver_balance
                in
                let receiver_account_creation_fee_paid =
                  account_creation_fee_of_fees_and_balance ?additional_fee
                    (Currency.Amount.to_fee coinbase.amount)
                    balances.coinbase_receiver_balance
                in
                let%map () =
                  Block_and_internal_command.add
                    (module Conn)
                    ~block_id ~internal_command_id:id ~sequence_no
                    ~secondary_sequence_no:0 ~receiver_account_creation_fee_paid
                    ~receiver_balance_id
                  >>| ignore
                in
                sequence_no + 1)
        in
        return block_id

  let add_if_doesn't_exist conn ~constraint_constants
      ({ data = t; hash } : (External_transition.t, State_hash.t) With_hash.t) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:(External_transition.protocol_state t)
      ~staged_ledger_diff:(External_transition.staged_ledger_diff t)
      ~hash

  let add_from_precomputed conn ~constraint_constants
      (t : External_transition.Precomputed_block.t) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:t.protocol_state ~staged_ledger_diff:t.staged_ledger_diff
      ~hash:(Protocol_state.hash t.protocol_state)

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
          let%bind staking_ledger_hash_id =
            Snarked_ledger_hash.add_if_doesn't_exist
              (module Conn)
              block.staking_epoch_ledger_hash
          in
          let%bind staking_epoch_data_id =
            Epoch_data.add_from_seed_and_ledger_hash_id
              (module Conn)
              ~seed:block.staking_epoch_seed
              ~ledger_hash_id:staking_ledger_hash_id
          in
          let%bind next_ledger_hash_id =
            Snarked_ledger_hash.add_if_doesn't_exist
              (module Conn)
              block.next_epoch_ledger_hash
          in
          let%bind next_epoch_data_id =
            Epoch_data.add_from_seed_and_ledger_hash_id
              (module Conn)
              ~seed:block.next_epoch_seed ~ledger_hash_id:next_ledger_hash_id
          in
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               {sql| INSERT INTO blocks
                     (state_hash, parent_id, parent_hash,
                      creator_id, block_winner_id,
                      snarked_ledger_hash_id, staking_epoch_data_id,
                      next_epoch_data_id, ledger_hash, height, global_slot,
                      global_slot_since_genesis, timestamp)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id
               |sql})
            { state_hash = block.state_hash |> State_hash.to_base58_check
            ; parent_id
            ; parent_hash = block.parent_hash |> State_hash.to_base58_check
            ; creator_id
            ; block_winner_id
            ; snarked_ledger_hash_id
            ; staking_epoch_data_id
            ; next_epoch_data_id
            ; ledger_hash = block.ledger_hash |> Ledger_hash.to_base58_check
            ; height = block.height |> Unsigned.UInt32.to_int64
            ; global_slot_since_hard_fork =
                block.global_slot_since_hard_fork |> Unsigned.UInt32.to_int64
            ; global_slot_since_genesis =
                block.global_slot_since_genesis |> Unsigned.UInt32.to_int64
            ; timestamp = block.timestamp |> Block_time.to_int64
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
    let balance_id_of_pk_and_balance pk balance =
      let%bind public_key_id =
        Public_key.add_if_doesn't_exist (module Conn) pk
      in
      Balance.add_if_doesn't_exist (module Conn) ~public_key_id ~balance
    in
    let balance_id_of_pk_and_balance_opt pk balance_opt =
      Option.value_map balance_opt ~default:(Deferred.Result.return None)
        ~f:(fun balance ->
          let%map id = balance_id_of_pk_and_balance pk balance in
          Some id)
    in
    (* add user commands to join table *)
    let%bind () =
      Mina_caqti.deferred_result_list_fold user_cmds_with_ids ~init:()
        ~f:(fun () (user_command, user_command_id) ->
          let%bind source_balance_id =
            balance_id_of_pk_and_balance_opt user_command.source
              user_command.source_balance
          in
          let%bind fee_payer_balance_id =
            balance_id_of_pk_and_balance user_command.fee_payer
              user_command.fee_payer_balance
          in
          let%bind receiver_balance_id =
            balance_id_of_pk_and_balance_opt user_command.receiver
              user_command.receiver_balance
          in
          Block_and_signed_command.add_if_doesn't_exist
            (module Conn)
            ~block_id ~user_command_id ~sequence_no:user_command.sequence_no
            ~status:user_command.status
            ~failure_reason:user_command.failure_reason
            ~fee_payer_account_creation_fee_paid:
              user_command.fee_payer_account_creation_fee_paid
            ~receiver_account_creation_fee_paid:
              user_command.receiver_account_creation_fee_paid
            ~created_token:user_command.created_token ~fee_payer_balance_id
            ~source_balance_id ~receiver_balance_id)
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
             ( (internal_command, internal_command_id)
             , (sequence_no, secondary_sequence_no) )
           ->
          let%bind receiver_balance_id =
            balance_id_of_pk_and_balance internal_command.receiver
              internal_command.receiver_balance
          in
          Block_and_internal_command.add_if_doesn't_exist
            (module Conn)
            ~block_id ~internal_command_id ~sequence_no ~secondary_sequence_no
            ~receiver_account_creation_fee_paid:None (* TEMP *)
            ~receiver_balance_id)
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

let add_block_aux ?(retries = 3) ~logger ~add_block ~hash ~delete_older_than
    pool block =
  let add () =
    Caqti_async.Pool.use
      (fun (module Conn : CONNECTION) ->
        let%bind res =
          let open Deferred.Result.Let_syntax in
          let%bind () = Conn.start () in
          let%bind block_id = add_block (module Conn : CONNECTION) block in
          (* if an existing block has a parent hash that's for the block just added,
             set its parent id
          *)
          let%bind () =
            Block.set_parent_id_if_null
              (module Conn)
              ~parent_hash:(hash block) ~parent_id:block_id
          in
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
              "Error when adding block data to the database, rolling it back: \
               $error"
              ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
            let%map _ = Conn.rollback () in
            err
        | Ok _ ->
            [%log info] "Committing block data for $state_hash"
              ~metadata:
                [ ("state_hash", Mina_base.State_hash.to_yojson (hash block)) ] ;
            Conn.commit ())
      pool
  in
  retry ~f:add ~logger ~error_str:"add_block_aux" retries

let add_block_aux_precomputed ~constraint_constants =
  add_block_aux ~add_block:(Block.add_from_precomputed ~constraint_constants)
    ~hash:(fun block ->
      block.External_transition.Precomputed_block.protocol_state
      |> Protocol_state.hash)

let add_block_aux_extensional =
  add_block_aux ~add_block:Block.add_from_extensional
    ~hash:(fun (block : Extensional.Block.t) -> block.state_hash)

let run pool reader ~constraint_constants ~logger ~delete_older_than =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier (Breadcrumb_added { block; _ }) -> (
        let add_block = Block.add_if_doesn't_exist ~constraint_constants in
        let hash block = With_hash.hash block in
        match%map
          add_block_aux ~logger ~delete_older_than ~hash ~add_block pool block
        with
        | Error e ->
            [%log warn]
              ~metadata:
                [ ("block", With_hash.hash block |> State_hash.to_yojson)
                ; ("error", `String (Caqti_error.show e))
                ]
              "Failed to archive block: $block, see $error"
        | Ok () ->
            () )
    | Transition_frontier _ ->
        Deferred.return ()
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
            add_block_aux_precomputed ~logger ~constraint_constants
              ~delete_older_than pool precomputed_block
          with
          | Error e ->
              [%log warn]
                "Precomputed block $block could not be archived: $error"
                ~metadata:
                  [ ( "block"
                    , Protocol_state.hash precomputed_block.protocol_state
                      |> State_hash.to_yojson )
                  ; ("error", `String (Caqti_error.show e))
                  ]
          | Ok () ->
              ())
      |> don't_wait_for ;
      Strict_pipe.Reader.iter extensional_block_reader
        ~f:(fun extensional_block ->
          match%map
            add_block_aux_extensional ~logger ~delete_older_than pool
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
          | Ok () ->
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
