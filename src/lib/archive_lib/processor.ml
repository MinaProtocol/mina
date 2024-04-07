(* processor.ml -- database processing for archive node *)

(* For each table in the archive database schema, a
   corresponding module contains code to read from and write to
   that table. The module defines a type `t`, a record with fields
   corresponding to columns in the table; typically, the `id` column
   that does not have an associated field.

   The more recently written modules use the Mina_caqti library to
   construct the SQL for those queries. For consistency and
   simplicity, the older modules should probably be refactored to use
   Mina_caqti.

   Module `Account_identifiers` is a good example of how Mina_caqti
   can be used.

   After these table-related modules, there are functions related to
   running the archive process and archive-related apps.
*)

module Archive_rpc = Rpc
open Async
open Core
open Caqti_async
open Mina_base
open Mina_transaction
open Mina_state
open Mina_block
open Pipe_lib
open Signature_lib
open Pickles_types

let applied_str = "applied"

let failed_str = "failed"

let txn_hash_to_base58_check ?(v1_transaction_hash = false) hash =
  if v1_transaction_hash then Transaction_hash.to_base58_check_v1 hash
  else Transaction_hash.to_base58_check hash

module Public_key = struct
  let find (module Conn : CONNECTION) (t : Public_key.Compressed.t) =
    let public_key = Public_key.Compressed.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "SELECT id FROM public_keys WHERE value = ?" )
      public_key

  let find_opt (module Conn : CONNECTION) (t : Public_key.Compressed.t) =
    let public_key = Public_key.Compressed.to_base58_check t in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM public_keys WHERE value = ?" )
      public_key

  let find_by_id (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         "SELECT value FROM public_keys WHERE id = ?" )
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
             "INSERT INTO public_keys (value) VALUES (?) RETURNING id" )
          public_key
end

(* Unlike other modules here, `Token_owners` does not correspond with a database table *)
module Token_owners = struct
  (* hash table of token owners, updated for each block *)
  let owner_tbl : Account_id.t Token_id.Table.t = Token_id.Table.create ()

  let add_if_doesn't_exist token_id owner =
    match Token_id.Table.add owner_tbl ~key:token_id ~data:owner with
    | `Ok | `Duplicate ->
        ()

  let find_owner token_id = Token_id.Table.find owner_tbl token_id
end

module Token = struct
  module T = struct
    type t =
      { value : string
      ; owner_public_key_id : int option
      ; owner_token_id : int option
      }
    [@@deriving hlist, fields, sexp, compare]
  end

  include T
  include Comparable.Make (T)

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; option int; option int ]

  let table_name = "tokens"

  let find_by_id (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id

  let make_finder conn_finder req_finder token_id =
    conn_finder
      (req_finder Caqti_type.string Caqti_type.int
         (Mina_caqti.select_cols ~table_name ~select:"id" ~cols:[ "value" ] ()) )
      (Token_id.to_string token_id)

  let find (module Conn : CONNECTION) = make_finder Conn.find Caqti_request.find

  let find_opt (module Conn : CONNECTION) =
    make_finder Conn.find_opt Caqti_request.find_opt

  let find_no_owner_opt (module Conn : CONNECTION) token_id =
    let value = Token_id.to_string token_id in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         {sql| SELECT id
               FROM tokens
               WHERE value = $1
               AND owner_public_key_id IS NULL
               AND owner_token_id IS NULL
         |sql} )
      value

  let set_owner (module Conn : CONNECTION) ~id ~owner_public_key_id
      ~owner_token_id =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         Caqti_type.int
         {sql| UPDATE tokens
               SET owner_public_key_id = $2, owner_token_id = $3
               WHERE id = $1
               RETURNING id
         |sql} )
      (id, owner_public_key_id, owner_token_id)

  let add_if_doesn't_exist (module Conn : CONNECTION) token_id =
    let open Deferred.Result.Let_syntax in
    let value = Token_id.to_string token_id in
    match Token_owners.find_owner token_id with
    | None ->
        (* not necessarily the default token *)
        Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
          ~table_name ~cols:(Fields.names, typ)
          (module Conn)
          { value; owner_public_key_id = None; owner_token_id = None }
    | Some acct_id -> (
        assert (not @@ Token_id.(equal default) token_id) ;
        assert (
          Token_id.equal (Account_id.derive_token_id ~owner:acct_id) token_id ) ;
        (* we can only add this token if its owner exists
           that means if we add several tokens in a block,
           we must add them in topologically sorted order
        *)
        let%bind owner_public_key_id =
          let owner_pk = Account_id.public_key acct_id in
          Public_key.add_if_doesn't_exist (module Conn) owner_pk
        in
        let%bind owner_token_id =
          let owner_tid = Account_id.token_id acct_id in
          find (module Conn) owner_tid
        in
        match%bind find_no_owner_opt (module Conn) token_id with
        | Some id ->
            (* existing entry, no owner *)
            set_owner (module Conn) ~id ~owner_public_key_id ~owner_token_id
        | None ->
            let owner_public_key_id = Some owner_public_key_id in
            let owner_token_id = Some owner_token_id in
            Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
              ~table_name ~cols:(Fields.names, typ)
              (module Conn)
              { value; owner_public_key_id; owner_token_id } )
end

module Voting_for = struct
  type t = string

  let typ = Caqti_type.string

  let table_name = "voting_for"

  let add_if_doesn't_exist (module Conn : CONNECTION) voting_for =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "value" ], typ)
      (module Conn)
      (State_hash.to_base58_check voting_for)

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "value" ]) )
      id
end

module Token_symbols = struct
  type t = string

  let typ = Caqti_type.string

  let table_name = "token_symbols"

  let add_if_doesn't_exist (module Conn : CONNECTION) token_symbol =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "value" ], typ)
      (module Conn)
      token_symbol

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "value" ]) )
      id
end

module Account_identifiers = struct
  module T = struct
    type t = { public_key_id : int; token_id : int }
    [@@deriving hlist, fields, sexp, compare]
  end

  include T
  include Comparable.Make (T)

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist Caqti_type.[ int; int ]

  let table_name = "account_identifiers"

  let add_if_doesn't_exist (module Conn : CONNECTION) account_id =
    let open Deferred.Result.Let_syntax in
    let pk = Account_id.public_key account_id in
    (* this token_id is Token_id.t *)
    let token_id = Account_id.token_id account_id in
    let%bind public_key_id = Public_key.add_if_doesn't_exist (module Conn) pk in
    (* this token_id is a Postgresql table id *)
    let%bind token_id = Token.add_if_doesn't_exist (module Conn) token_id in
    let t = { public_key_id; token_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let find_opt (module Conn : CONNECTION) account_id =
    let open Deferred.Result.Let_syntax in
    let pk = Account_id.public_key account_id in
    match%bind Public_key.find_opt (module Conn) pk with
    | None ->
        return None
    | Some pk_id -> (
        let token = Account_id.token_id account_id in
        match%bind Token.find_opt (module Conn) token with
        | None ->
            return None
        | Some tok_id ->
            Conn.find_opt
              (Caqti_request.find_opt
                 Caqti_type.(tup2 int int)
                 Caqti_type.int
                 (Mina_caqti.select_cols ~select:"id" ~table_name
                    ~cols:Fields.names () ) )
              (pk_id, tok_id) )

  let find (module Conn : CONNECTION) account_id =
    let open Deferred.Result.Let_syntax in
    let pk = Account_id.public_key account_id in
    let%bind public_key_id = Public_key.find (module Conn) pk in
    let token = Account_id.token_id account_id in
    let%bind token_id = Token.find (module Conn) token in
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup2 int int)
         Caqti_type.int
         (Mina_caqti.select_cols ~select:"id" ~table_name ~cols:Fields.names ()) )
      (public_key_id, token_id)

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_field = struct
  let table_name = "zkapp_field"

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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "field" ]) )
      id
end

module Zkapp_field_array = struct
  let table_name = "zkapp_field_array"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : Pickles.Backend.Tick.Field.t array) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int array) =
      Mina_caqti.deferred_result_list_map (Array.to_list fps)
        ~f:(Zkapp_field.add_if_doesn't_exist (module Conn))
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "element_ids" ]) )
      id
end

module Zkapp_states_nullable = struct
  type t =
    { element0 : int option
    ; element1 : int option
    ; element2 : int option
    ; element3 : int option
    ; element4 : int option
    ; element5 : int option
    ; element6 : int option
    ; element7 : int option
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
        ; option int
        ]

  let table_name = "zkapp_states_nullable"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t option, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int option list) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps)
        ~f:
          ( Mina_caqti.add_if_some
          @@ Zkapp_field.add_if_doesn't_exist (module Conn) )
    in
    let t =
      match element_ids with
      | [ element0
        ; element1
        ; element2
        ; element3
        ; element4
        ; element5
        ; element6
        ; element7
        ] ->
          { element0
          ; element1
          ; element2
          ; element3
          ; element4
          ; element5
          ; element6
          ; element7
          }
      | _ ->
          failwith "Invalid number of nullable app state elements"
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_states = struct
  type t =
    { element0 : int
    ; element1 : int
    ; element2 : int
    ; element3 : int
    ; element4 : int
    ; element5 : int
    ; element6 : int
    ; element7 : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; int; int; int; int; int ]

  let table_name = "zkapp_states"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int list) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps)
        ~f:(Zkapp_field.add_if_doesn't_exist (module Conn))
    in
    let t =
      match element_ids with
      | [ element0
        ; element1
        ; element2
        ; element3
        ; element4
        ; element5
        ; element6
        ; element7
        ] ->
          { element0
          ; element1
          ; element2
          ; element3
          ; element4
          ; element5
          ; element6
          ; element7
          }
      | _ ->
          failwith "Invalid number of app state elements"
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_action_states = struct
  type t =
    { element0 : int
    ; element1 : int
    ; element2 : int
    ; element3 : int
    ; element4 : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; int; int ]

  let table_name = "zkapp_action_states"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (fps : (Pickles.Backend.Tick.Field.t, 'n) Vector.vec) =
    let open Deferred.Result.Let_syntax in
    let%bind (element_ids : int list) =
      Mina_caqti.deferred_result_list_map (Vector.to_list fps) ~f:(fun field ->
          Zkapp_field.add_if_doesn't_exist (module Conn) field )
    in
    let t =
      match element_ids with
      | [ element0; element1; element2; element3; element4 ] ->
          { element0; element1; element2; element3; element4 }
      | _ ->
          failwith "Invalid number of action state elements"
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_verification_key_hashes = struct
  type t = int array

  let typ = Caqti_type.string

  let table_name = "zkapp_verification_key_hashes"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (verification_key_hash : Pickles.Backend.Tick.Field.t) =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "value" ], typ)
      (module Conn)
      (Pickles.Backend.Tick.Field.to_string verification_key_hash)

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "value" ]) )
      id
end

module Zkapp_verification_keys = struct
  type t = { verification_key : string; hash_id : int }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; int ]

  let table_name = "zkapp_verification_keys"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (vk :
        ( Pickles.Side_loaded.Verification_key.t
        , Pickles.Backend.Tick.Field.t )
        With_hash.t ) =
    let open Deferred.Result.Let_syntax in
    let verification_key =
      Pickles.Side_loaded.Verification_key.to_base64 vk.data
    in
    let%bind hash_id =
      Zkapp_verification_key_hashes.add_if_doesn't_exist (module Conn) vk.hash
    in
    let value = { verification_key; hash_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Protocol_versions = struct
  module T = struct
    type t = { transaction : int; network : int; patch : int }
    [@@deriving hlist, fields, compare, sexp, hash]
  end

  include T
  include Comparable.Make (T)

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int ]

  let table_name = "protocol_versions"

  let add_if_doesn't_exist (module Conn : CONNECTION) ~transaction ~network
      ~patch =
    let t = { transaction; network; patch } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      t

  let find (module Conn : CONNECTION) ~transaction ~network ~patch =
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         Caqti_type.int
         (Mina_caqti.select_cols ~select:"id" ~table_name ~cols:Fields.names ()) )
      (transaction, network, patch)

  let find_txn_version (module Conn : CONNECTION) ~transaction =
    Conn.collect_list
      (Caqti_request.collect Caqti_type.int Caqti_type.int
         {sql| SELECT id FROM protocol_versions WHERE transaction = ?
        |sql} )
      transaction

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
    ; access : Permissions.Auth_required.t
    ; set_delegate : Permissions.Auth_required.t
    ; set_permissions : Permissions.Auth_required.t
    ; set_verification_key_auth : Permissions.Auth_required.t
    ; set_verification_key_txn_version : int
    ; set_zkapp_uri : Permissions.Auth_required.t
    ; edit_action_state : Permissions.Auth_required.t
    ; set_token_symbol : Permissions.Auth_required.t
    ; increment_nonce : Permissions.Auth_required.t
    ; set_voting_for : Permissions.Auth_required.t
    ; set_timing : Permissions.Auth_required.t
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
      ; Caqti_type.int
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
      ; access = perms.access
      ; set_delegate = perms.set_delegate
      ; set_permissions = perms.set_permissions
      ; set_verification_key_auth = fst perms.set_verification_key
      ; set_verification_key_txn_version =
          Mina_numbers.Txn_version.to_int @@ snd perms.set_verification_key
      ; set_zkapp_uri = perms.set_zkapp_uri
      ; edit_action_state = perms.edit_action_state
      ; set_token_symbol = perms.set_token_symbol
      ; increment_nonce = perms.increment_nonce
      ; set_voting_for = perms.set_voting_for
      ; set_timing = perms.set_timing
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_timing_info = struct
  type t =
    { initial_minimum_balance : string
    ; cliff_time : int64
    ; cliff_amount : string
    ; vesting_period : int64
    ; vesting_increment : string
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; int64; string; int64; string ]

  let table_name = "zkapp_timing_info"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timing_info : Account_update.Update.Timing_info.t) =
    let initial_minimum_balance =
      Currency.Balance.to_string timing_info.initial_minimum_balance
    in
    let cliff_time =
      Mina_numbers.Global_slot_since_genesis.to_uint32 timing_info.cliff_time
      |> Unsigned.UInt32.to_int64
    in
    let cliff_amount = Currency.Amount.to_string timing_info.cliff_amount in
    let vesting_period =
      Mina_numbers.Global_slot_span.to_uint32 timing_info.vesting_period
      |> Unsigned.UInt32.to_int64
    in
    let vesting_increment =
      Currency.Amount.to_string timing_info.vesting_increment
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_uri = struct
  type t = string

  let typ = Caqti_type.string

  let table_name = "zkapp_uris"

  let add_if_doesn't_exist (module Conn : CONNECTION) zkapp_uri =
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "value" ], typ)
      (module Conn)
      zkapp_uri

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "value" ]) )
      id
end

module Zkapp_updates = struct
  type t =
    { app_state_id : int
    ; delegate_id : int option
    ; verification_key_id : int option
    ; permissions_id : int option
    ; zkapp_uri_id : int option
    ; token_symbol_id : int option
    ; timing_id : int option
    ; voting_for_id : int option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ; option int
        ]

  let table_name = "zkapp_updates"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (update : Account_update.Update.t) =
    let open Deferred.Result.Let_syntax in
    let%bind app_state_id =
      Vector.map ~f:Zkapp_basic.Set_or_keep.to_option update.app_state
      |> Zkapp_states_nullable.add_if_doesn't_exist (module Conn)
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
    let%bind zkapp_uri_id =
      Mina_caqti.add_if_zkapp_set
        (Zkapp_uri.add_if_doesn't_exist (module Conn))
        update.zkapp_uri
    in
    let%bind token_symbol_id =
      Mina_caqti.add_if_zkapp_set
        (Token_symbols.add_if_doesn't_exist (module Conn))
        update.token_symbol
    in
    let%bind voting_for_id =
      Mina_caqti.add_if_zkapp_set
        (Voting_for.add_if_doesn't_exist (module Conn))
        update.voting_for
    in
    let value =
      { app_state_id
      ; delegate_id
      ; verification_key_id
      ; permissions_id
      ; zkapp_uri_id
      ; token_symbol_id
      ; timing_id
      ; voting_for_id
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_balance_bounds = struct
  type t = { balance_lower_bound : string; balance_upper_bound : string }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; string ]

  let table_name = "zkapp_balance_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (balance_bounds :
        Currency.Balance.t Mina_base.Zkapp_precondition.Closed_interval.t ) =
    let balance_lower_bound = Currency.Balance.to_string balance_bounds.lower in
    let balance_upper_bound = Currency.Balance.to_string balance_bounds.upper in
    let value = { balance_lower_bound; balance_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
        Mina_base.Zkapp_precondition.Closed_interval.t ) =
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_account_precondition = struct
  type t =
    { balance_id : int option
    ; nonce_id : int option
    ; receipt_chain_hash : string option
    ; delegate_id : int option
    ; state_id : int
    ; action_state_id : int option
    ; proved_state : bool option
    ; is_new : bool option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ option int
        ; option int
        ; option string
        ; option int
        ; int
        ; option int
        ; option bool
        ; option bool
        ]

  let table_name = "zkapp_account_precondition"

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
    let%bind delegate_id =
      Mina_caqti.add_if_zkapp_check
        (Public_key.add_if_doesn't_exist (module Conn))
        acct.delegate
    in
    let%bind state_id =
      Vector.map ~f:Zkapp_basic.Or_ignore.to_option acct.state
      |> Zkapp_states_nullable.add_if_doesn't_exist (module Conn)
    in
    let%bind action_state_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_field.add_if_doesn't_exist (module Conn))
        acct.action_state
    in
    let receipt_chain_hash =
      Zkapp_basic.Or_ignore.to_option acct.receipt_chain_hash
      |> Option.map ~f:Receipt.Chain_hash.to_base58_check
    in
    let proved_state = Zkapp_basic.Or_ignore.to_option acct.proved_state in
    let is_new = Zkapp_basic.Or_ignore.to_option acct.is_new in
    let value =
      { balance_id
      ; nonce_id
      ; receipt_chain_hash
      ; delegate_id
      ; state_id
      ; action_state_id
      ; proved_state
      ; is_new
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
        Token_id.t Mina_base.Zkapp_precondition.Closed_interval.t ) =
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_timestamp_bounds = struct
  type t = { timestamp_lower_bound : string; timestamp_upper_bound : string }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; string ]

  let table_name = "zkapp_timestamp_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (timestamp_bounds :
        Block_time.t Mina_base.Zkapp_precondition.Closed_interval.t ) =
    let timestamp_lower_bound =
      Block_time.to_string_exn timestamp_bounds.lower
    in
    let timestamp_upper_bound =
      Block_time.to_string_exn timestamp_bounds.upper
    in
    let value = { timestamp_lower_bound; timestamp_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
        Unsigned.uint32 Mina_base.Zkapp_precondition.Closed_interval.t ) =
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_amount_bounds = struct
  type t = { amount_lower_bound : string; amount_upper_bound : string }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; string ]

  let table_name = "zkapp_amount_bounds"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (amount_bounds :
        Currency.Amount.t Mina_base.Zkapp_precondition.Closed_interval.t ) =
    let amount_lower_bound = Currency.Amount.to_string amount_bounds.lower in
    let amount_upper_bound = Currency.Amount.to_string amount_bounds.upper in
    let value = { amount_lower_bound; amount_upper_bound } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
        Mina_numbers.Global_slot_since_genesis.t
        Mina_base.Zkapp_precondition.Closed_interval.t ) =
    let global_slot_lower_bound =
      Mina_numbers.Global_slot_since_genesis.to_uint32 global_slot_bounds.lower
      |> Unsigned.UInt32.to_int64
    in
    let global_slot_upper_bound =
      Mina_numbers.Global_slot_since_genesis.to_uint32 global_slot_bounds.upper
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Timing_info = struct
  type t =
    { account_identifier_id : int
    ; initial_minimum_balance : string
    ; cliff_time : int64
    ; cliff_amount : string
    ; vesting_period : int64
    ; vesting_increment : string
    }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; string; int64; string; int64; string ]

  let table_name = "timing_info"

  let find (module Conn : CONNECTION) (acc : Account.t) =
    let open Deferred.Result.Let_syntax in
    let%bind account_identifier_id =
      let account_id = Account_id.create acc.public_key acc.token_id in
      Account_identifiers.find (module Conn) account_id
    in
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         {sql| SELECT account_identifier_id, initial_minimum_balance,
                      cliff_time, cliff_amount,
                      vesting_period, vesting_increment
               FROM timing_info
               WHERE account_identifier_id = ?
         |sql} )
      account_identifier_id

  let find_by_account_identifier_id_opt (module Conn : CONNECTION)
      account_identifier_id =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.int typ
         {sql| SELECT account_identifier_id, initial_minimum_balance,
                      cliff_time, cliff_amount,
                      vesting_period, vesting_increment
               FROM timing_info
               WHERE account_identifier_id = ?
         |sql} )
      account_identifier_id

  let add_if_doesn't_exist (module Conn : CONNECTION) account_identifier_id
      (timing : Account_timing.t) =
    let open Deferred.Result.Let_syntax in
    let slot_to_int64 x =
      Mina_numbers.Global_slot_since_genesis.to_uint32 x
      |> Unsigned.UInt32.to_int64
    in
    let slot_span_to_int64 x =
      Mina_numbers.Global_slot_span.to_uint32 x |> Unsigned.UInt32.to_int64
    in
    let values =
      match timing with
      | Timed timing ->
          { account_identifier_id
          ; initial_minimum_balance =
              Currency.Balance.to_string timing.initial_minimum_balance
          ; cliff_time = slot_to_int64 timing.cliff_time
          ; cliff_amount = Currency.Amount.to_string timing.cliff_amount
          ; vesting_period = slot_span_to_int64 timing.vesting_period
          ; vesting_increment =
              Currency.Amount.to_string timing.vesting_increment
          }
      | Untimed ->
          let zero = "0" in
          { account_identifier_id
          ; initial_minimum_balance = zero
          ; cliff_time = 0L
          ; cliff_amount = zero
          ; vesting_period = 0L
          ; vesting_increment = zero
          }
    in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt typ Caqti_type.int
           {sql| SELECT id FROM timing_info
                 WHERE account_identifier_id = ?
                 AND initial_minimum_balance = ?
                 AND cliff_time = ?
                 AND cliff_amount = ?
                 AND vesting_period = ?
                 AND vesting_increment = ? |sql} )
        values
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO timing_info
                    (account_identifier_id,initial_minimum_balance,
                     cliff_time, cliff_amount, vesting_period, vesting_increment)
                   VALUES (?, ?, ?, ?, ?, ?)
                   RETURNING id
             |sql} )
          values

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id

  let load_opt (module Conn : CONNECTION) id =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Snarked_ledger_hash = struct
  let find (module Conn : CONNECTION) (t : Frozen_ledger_hash.t) =
    let hash = Frozen_ledger_hash.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "SELECT id FROM snarked_ledger_hashes WHERE value = ?" )
      hash

  let find_by_id (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         "SELECT value FROM snarked_ledger_hashes WHERE id = ?" )
      id

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : Frozen_ledger_hash.t)
      =
    let open Deferred.Result.Let_syntax in
    let hash = Frozen_ledger_hash.to_base58_check t in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM snarked_ledger_hashes WHERE value = ?" )
        hash
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find Caqti_type.string Caqti_type.int
             "INSERT INTO snarked_ledger_hashes (value) VALUES (?) RETURNING id" )
          hash

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Caqti_type.string
         "SELECT value FROM snarked_ledger_hashes WHERE id = ?" )
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_network_precondition = struct
  type t =
    { snarked_ledger_hash_id : int option
    ; blockchain_length_id : int option
    ; min_window_density_id : int option
    ; total_currency_id : int option
    ; global_slot_since_genesis : int option
    ; staking_epoch_data_id : int
    ; next_epoch_data_id : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ option int; option int; option int; option int; option int; int; int ]

  let table_name = "zkapp_network_precondition"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (ps : Mina_base.Zkapp_precondition.Protocol_state.t) =
    let open Deferred.Result.Let_syntax in
    let%bind snarked_ledger_hash_id =
      Mina_caqti.add_if_zkapp_check
        (Snarked_ledger_hash.add_if_doesn't_exist (module Conn))
        ps.snarked_ledger_hash
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
      ; blockchain_length_id
      ; min_window_density_id
      ; total_currency_id
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_events = struct
  type t = int array

  let typ = Mina_caqti.array_int_typ

  let table_name = "zkapp_events"

  module Field_array_map = Map.Make (struct
    type t = int array [@@deriving sexp]

    let compare = Array.compare Int.compare
  end)

  (* Account_update.Body.Events'.t is defined as `field array list`,
     which is ismorphic to a list of list of fields.

     We are batching the insertion of field and field_array to optimize
     the speed of archiving max-cost zkapps.

     1. we flatten the list of list of fields to get all the field elements
     2. insert all the field elements in one query
     3. construct a map "M" from `field_id` to `field` by querying against the zkapp_field table
     4. use "M" and the list of list of fields to compute the list of list of field_ids
     5. insert all list of `list of field_ids` in one query
     6. construct a map "M'" from `field_array_id` to `field_id array` by querying against
        the zkapp_field_array table
     7. use "M'" and the list of list of field_ids to compute the list of field_array_ids
     8. insert the list of field_arrays
  *)
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (events : Account_update.Body.Events'.t) =
    let open Deferred.Result.Let_syntax in
    let%bind field_array_id_list =
      if not @@ List.is_empty events then
        let field_list_list =
          List.map events ~f:(fun field_array ->
              Array.map field_array ~f:Pickles.Backend.Tick.Field.to_string
              |> Array.to_list )
        in
        let fields = field_list_list |> List.concat in
        let%bind field_id_list_list =
          if not @@ List.is_empty fields then
            let%map field_map =
              Mina_caqti.insert_multi_into_col ~table_name:"zkapp_field"
                ~col:("field", Caqti_type.string)
                (module Conn)
                fields
              >>| String.Map.of_alist_exn
            in
            let field_id_list_list =
              List.map field_list_list ~f:(List.map ~f:(Map.find_exn field_map))
            in
            field_id_list_list
          else
            (* if there's no fields, then we must have some list of empty lists *)
            return @@ List.map field_list_list ~f:(fun _ -> [])
        in
        (* this conversion should be done by caqti using `typ`, FIX this in the future *)
        let field_array_list =
          List.map field_id_list_list ~f:(fun id_list ->
              List.map id_list ~f:Int.to_string
              |> String.concat ~sep:", " |> sprintf "{%s}" )
        in
        let%map field_array_map =
          Mina_caqti.insert_multi_into_col ~table_name:"zkapp_field_array"
            ~col:("element_ids", Mina_caqti.array_int_typ)
            (module Conn)
            field_array_list
          >>| Field_array_map.of_alist_exn
        in
        let field_array_id_list =
          List.map field_id_list_list ~f:(fun field_id_list ->
              Map.find_exn field_array_map (Array.of_list field_id_list) )
          |> Array.of_list
        in
        field_array_id_list
      else return @@ Array.of_list []
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~cols:([ "element_ids" ], Mina_caqti.array_int_typ)
      ~tannot:(function "element_ids" -> Some "int[]" | _ -> None)
      (module Conn)
      field_array_id_list

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int Mina_caqti.array_int_typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:[ "element_ids" ]) )
      id
end

module Zkapp_account_update_body = struct
  type t =
    { account_identifier_id : int
    ; update_id : int
    ; balance_change : string
    ; increment_nonce : bool
    ; events_id : int
    ; actions_id : int
    ; call_data_id : int
    ; call_depth : int
    ; zkapp_network_precondition_id : int
    ; zkapp_account_precondition_id : int
    ; zkapp_valid_while_precondition_id : int option
    ; use_full_commitment : bool
    ; implicit_account_creation_fee : bool
    ; may_use_token : string
    ; authorization_kind : string
    ; verification_key_hash_id : int option
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.
        [ int
        ; int
        ; string
        ; bool
        ; int
        ; int
        ; int
        ; int
        ; int
        ; int
        ; option int
        ; bool
        ; bool
        ; string
        ; string
        ; option int
        ]

  let table_name = "zkapp_account_update_body"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (body : Account_update.Body.Simple.t) =
    let open Deferred.Result.Let_syntax in
    let account_identifier = Account_id.create body.public_key body.token_id in
    let%bind account_identifier_id =
      Account_identifiers.add_if_doesn't_exist (module Conn) account_identifier
    in
    let%bind update_id =
      Metrics.time ~label:"zkapp_updates.add"
      @@ fun () -> Zkapp_updates.add_if_doesn't_exist (module Conn) body.update
    in
    let increment_nonce = body.increment_nonce in
    let%bind events_id =
      Metrics.time ~label:"Zkapp_events.add"
      @@ fun () -> Zkapp_events.add_if_doesn't_exist (module Conn) body.events
    in
    let%bind actions_id =
      Metrics.time ~label:"Zkapp_actions.add"
      @@ fun () -> Zkapp_events.add_if_doesn't_exist (module Conn) body.actions
    in
    let%bind call_data_id =
      Zkapp_field.add_if_doesn't_exist (module Conn) body.call_data
    in
    let%bind zkapp_network_precondition_id =
      Zkapp_network_precondition.add_if_doesn't_exist
        (module Conn)
        body.preconditions.network
    in
    let%bind zkapp_account_precondition_id =
      Zkapp_account_precondition.add_if_doesn't_exist
        (module Conn)
        body.preconditions.account
    in
    let%bind zkapp_valid_while_precondition_id =
      Mina_caqti.add_if_zkapp_check
        (Zkapp_global_slot_bounds.add_if_doesn't_exist (module Conn))
        body.preconditions.valid_while
    in
    let balance_change =
      let magnitude = Currency.Amount.to_string body.balance_change.magnitude in
      match body.balance_change.sgn with
      | Sgn.Pos ->
          magnitude
      | Sgn.Neg ->
          "-" ^ magnitude
    in
    let call_depth = body.call_depth in
    let use_full_commitment = body.use_full_commitment in
    let implicit_account_creation_fee = body.implicit_account_creation_fee in
    let may_use_token =
      Account_update.May_use_token.to_string body.may_use_token
    in
    let authorization_kind =
      Account_update.Authorization_kind.to_control_tag body.authorization_kind
      |> Control.Tag.to_string
    in
    let%bind verification_key_hash_id =
      match body.authorization_kind with
      | Account_update.Authorization_kind.Proof vk_hash ->
          let%map id =
            Zkapp_verification_key_hashes.add_if_doesn't_exist
              (module Conn)
              vk_hash
          in
          Some id
      | _ ->
          return None
    in
    let value =
      { account_identifier_id
      ; update_id
      ; balance_change
      ; increment_nonce
      ; events_id
      ; actions_id
      ; call_data_id
      ; call_depth
      ; zkapp_network_precondition_id
      ; zkapp_account_precondition_id
      ; zkapp_valid_while_precondition_id
      ; use_full_commitment
      ; implicit_account_creation_fee
      ; may_use_token
      ; authorization_kind
      ; verification_key_hash_id
      }
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      ~tannot:(function
        | "events_ids" | "actions_ids" ->
            Some "int[]"
        | "may_use_token" ->
            Some "may_use_token"
        | "authorization_kind" ->
            Some "authorization_kind_type"
        | _ ->
            None )
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_account_update = struct
  type t = { body_id : int } [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist Caqti_type.[ int ]

  let table_name = "zkapp_account_update"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (account_update : Account_update.Simple.t) =
    let open Deferred.Result.Let_syntax in
    let%bind body_id =
      Metrics.time ~label:"Zkapp_account_update_body.add"
      @@ fun () ->
      Zkapp_account_update_body.add_if_doesn't_exist
        (module Conn)
        account_update.body
    in
    let value = { body_id } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Zkapp_fee_payer_body = struct
  type t =
    { public_key_id : int
    ; fee : string
    ; valid_until : int64 option
    ; nonce : int64
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; string; option int64; int64 ]

  let table_name = "zkapp_fee_payer_body"

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (body : Account_update.Body.Fee_payer.t) =
    let open Deferred.Result.Let_syntax in
    let%bind public_key_id =
      Public_key.add_if_doesn't_exist (module Conn) body.public_key
    in
    let valid_until =
      let open Option.Let_syntax in
      body.valid_until >>| Mina_numbers.Global_slot_since_genesis.to_uint32
      >>| Unsigned.UInt32.to_int64
    in
    let nonce =
      body.nonce |> Mina_numbers.Account_nonce.to_uint32
      |> Unsigned.UInt32.to_int64
    in
    let fee = Currency.Fee.to_string body.fee in
    let value = { public_key_id; fee; valid_until; nonce } in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      value

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Epoch_data = struct
  module T = struct
    type t =
      { seed : string
      ; ledger_hash_id : int
      ; total_currency : string
      ; start_checkpoint : string
      ; lock_checkpoint : string
      ; epoch_length : int64
      }
    [@@deriving sexp, compare, equal, hlist, fields]
  end

  include T
  include Comparable.Make (T)

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; int; string; string; string; int64 ]

  let table_name = "epoch_data"

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
    let total_currency = Currency.Amount.to_string total_currency in
    let start_checkpoint = t.start_checkpoint |> State_hash.to_base58_check in
    let lock_checkpoint = t.lock_checkpoint |> State_hash.to_base58_check in
    let epoch_length =
      t.epoch_length |> Mina_numbers.Length.to_uint32
      |> Unsigned.UInt32.to_int64
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name ~cols:(Fields.names, typ)
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
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module User_command = struct
  module Signed_command = struct
    type t =
      { command_type : string
      ; fee_payer_id : int
      ; source_id : int
      ; receiver_id : int
      ; nonce : int64
      ; amount : string option
      ; fee : string
      ; valid_until : int64 option
      ; memo : string
      ; hash : string
      }
    [@@deriving hlist, fields]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.
          [ string
          ; int
          ; int
          ; int
          ; int64
          ; option string
          ; string
          ; option int64
          ; string
          ; string
          ]

    let table_name = "user_commands"

    let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
        ~v1_transaction_hash =
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           (Mina_caqti.select_cols ~select:"id" ~table_name ~cols:[ "hash" ] ()) )
        (txn_hash_to_base58_check transaction_hash ~v1_transaction_hash)

    let load (module Conn : CONNECTION) ~(id : int) =
      Conn.find
        (Caqti_request.find Caqti_type.int typ
           (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
        id

    type balance_public_key_ids = { fee_payer_id : int; receiver_id : int }

    let add_account_ids_if_don't_exist (module Conn : CONNECTION)
        (t : Signed_command.t) =
      let open Deferred.Result.Let_syntax in
      let%bind fee_payer_id =
        let pk = Signed_command.fee_payer_pk t in
        Public_key.add_if_doesn't_exist (module Conn) pk
      in
      let%map receiver_id =
        let pk = Signed_command.receiver_pk t in
        Public_key.add_if_doesn't_exist (module Conn) pk
      in
      { fee_payer_id; receiver_id }

    let add_if_doesn't_exist ?(via = `Ident) (module Conn : CONNECTION)
        (t : Signed_command.t) ~v1_transaction_hash =
      let open Deferred.Result.Let_syntax in
      let transaction_hash = Transaction_hash.hash_command (Signed_command t) in
      match%bind find (module Conn) ~transaction_hash ~v1_transaction_hash with
      | Some user_command_id ->
          return user_command_id
      | None ->
          let%bind { fee_payer_id; receiver_id } =
            add_account_ids_if_don't_exist (module Conn) t
          in
          let valid_until =
            let open Mina_numbers in
            let slot = Signed_command.valid_until t in
            if
              Global_slot_since_genesis.equal slot
                Global_slot_since_genesis.max_value
            then None
            else
              Some
                ( slot |> Mina_numbers.Global_slot_since_genesis.to_uint32
                |> Unsigned.UInt32.to_int64 )
          in
          (* TODO: Converting these uint64s to int64 can overflow; see #5419 *)
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               (Mina_caqti.insert_into_cols ~returning:"id" ~table_name
                  ~tannot:(function
                    | "command_type" -> Some "user_command_type" | _ -> None )
                  ~cols:Fields.names () ) )
            { command_type =
                ( match via with
                | `Ident ->
                    Signed_command.tag_string t
                | `Zkapp_command ->
                    "zkapp" )
            ; fee_payer_id
            ; source_id = fee_payer_id
            ; receiver_id
            ; nonce = Signed_command.nonce t |> Unsigned.UInt32.to_int64
            ; amount =
                Option.map (Signed_command.amount t)
                  ~f:Currency.Amount.to_string
            ; fee = Currency.Fee.to_string (Signed_command.fee t)
            ; valid_until
            ; memo =
                Signed_command.memo t |> Signed_command_memo.to_base58_check
            ; hash =
                transaction_hash
                |> txn_hash_to_base58_check ~v1_transaction_hash
            }

    let add_extensional_if_doesn't_exist (module Conn : CONNECTION)
        ?(v1_transaction_hash = false) (user_cmd : Extensional.User_command.t) =
      let open Deferred.Result.Let_syntax in
      match%bind
        find (module Conn) ~transaction_hash:user_cmd.hash ~v1_transaction_hash
      with
      | Some id ->
          return id
      | None ->
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
            (Caqti_request.find typ Caqti_type.int
               (Mina_caqti.insert_into_cols ~returning:"id" ~table_name
                  ~tannot:(function
                    | "command_type" -> Some "user_command_type" | _ -> None )
                  ~cols:Fields.names () ) )
            { command_type = user_cmd.command_type
            ; fee_payer_id
            ; source_id
            ; receiver_id
            ; nonce = user_cmd.nonce |> Unsigned.UInt32.to_int64
            ; amount = Option.map user_cmd.amount ~f:Currency.Amount.to_string
            ; fee = Currency.Fee.to_string user_cmd.fee
            ; valid_until =
                Option.map user_cmd.valid_until
                  ~f:
                    (Fn.compose Unsigned.UInt32.to_int64
                       Mina_numbers.Global_slot_since_genesis.to_uint32 )
            ; memo = user_cmd.memo |> Signed_command_memo.to_base58_check
            ; hash =
                user_cmd.hash |> txn_hash_to_base58_check ~v1_transaction_hash
            }
  end

  module Zkapp_command = struct
    type t =
      { zkapp_fee_payer_body_id : int
      ; zkapp_account_updates_ids : int array
      ; memo : string
      ; hash : string
      }
    [@@deriving fields, hlist]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ int; Mina_caqti.array_int_typ; string; string ]

    let table_name = "zkapp_commands"

    let find_opt (module Conn : CONNECTION)
        ~(transaction_hash : Transaction_hash.t) =
      Conn.find_opt
        ( Caqti_request.find_opt Caqti_type.string Caqti_type.int
        @@ Mina_caqti.select_cols ~select:"id" ~table_name ~cols:[ "hash" ] ()
        )
        (Transaction_hash.to_base58_check transaction_hash)

    let load (module Conn : CONNECTION) id =
      Conn.find
        ( Caqti_request.find Caqti_type.int typ
        @@ Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names )
        id

    let add_if_doesn't_exist (module Conn : CONNECTION) (ps : Zkapp_command.t) =
      let open Deferred.Result.Let_syntax in
      let zkapp_command = Zkapp_command.to_simple ps in
      let%bind zkapp_fee_payer_body_id =
        Metrics.time ~label:"Zkapp_fee_payer_body.add"
        @@ fun () ->
        Zkapp_fee_payer_body.add_if_doesn't_exist
          (module Conn)
          zkapp_command.fee_payer.body
      in
      let%bind zkapp_account_updates_ids =
        Metrics.time ~label:"Zkapp_account_update.add"
        @@ fun () ->
        Mina_caqti.deferred_result_list_map zkapp_command.account_updates
          ~f:(Zkapp_account_update.add_if_doesn't_exist (module Conn))
        >>| Array.of_list
      in
      let memo = ps.memo |> Signed_command_memo.to_base58_check in
      let hash =
        Transaction_hash.hash_command (Zkapp_command ps)
        |> Transaction_hash.to_base58_check
      in
      Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
        ~table_name:"zkapp_commands" ~cols:(Fields.names, typ)
        ~tannot:(function
          | "zkapp_account_updates_ids" -> Some "int[]" | _ -> None )
        (module Conn)
        { zkapp_fee_payer_body_id; zkapp_account_updates_ids; memo; hash }
  end

  let via (t : User_command.t) : [ `Zkapp_command | `Ident ] =
    match t with
    | Signed_command _ ->
        `Ident
    | Zkapp_command _ ->
        `Zkapp_command

  let add_if_doesn't_exist conn (t : User_command.t) ~v1_transaction_hash =
    match t with
    | Signed_command sc ->
        Signed_command.add_if_doesn't_exist conn ~via:(via t)
          ~v1_transaction_hash sc
    | Zkapp_command ps ->
        Zkapp_command.add_if_doesn't_exist conn ps

  let find conn ~(transaction_hash : Transaction_hash.t) ~v1_transaction_hash =
    let open Deferred.Result.Let_syntax in
    let%bind signed_command_id =
      Signed_command.find conn ~transaction_hash ~v1_transaction_hash
      >>| Option.map ~f:(fun id -> `Signed_command_id id)
    in
    let%map zkapp_command_id =
      Zkapp_command.find_opt conn ~transaction_hash
      >>| Option.map ~f:(fun id -> `Zkapp_command_id id)
    in
    Option.first_some signed_command_id zkapp_command_id
end

module Internal_command = struct
  type t =
    { command_type : string; receiver_id : int; fee : string; hash : string }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; int; string; string ]

  let table_name = "internal_commands"

  let find_opt (module Conn : CONNECTION) ~(v1_transaction_hash : bool)
      ~(transaction_hash : Transaction_hash.t) ~(command_type : string) =
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup2 string string)
         Caqti_type.int
         (Mina_caqti.select_cols ~select:"id" ~table_name
            ~tannot:(function
              | "command_type" -> Some "internal_command_type" | _ -> None )
            ~cols:[ "hash"; "command_type" ] () ) )
      ( txn_hash_to_base58_check ~v1_transaction_hash transaction_hash
      , command_type )

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id

  let add_extensional_if_doesn't_exist (module Conn : CONNECTION)
      ?(v1_transaction_hash = false)
      (internal_cmd : Extensional.Internal_command.t) =
    let open Deferred.Result.Let_syntax in
    match%bind
      find_opt
        (module Conn)
        ~v1_transaction_hash ~transaction_hash:internal_cmd.hash
        ~command_type:internal_cmd.command_type
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist (module Conn) internal_cmd.receiver
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             (Mina_caqti.insert_into_cols ~returning:"id" ~table_name
                ~tannot:(function
                  | "command_type" -> Some "internal_command_type" | _ -> None
                  )
                ~cols:Fields.names () ) )
          { command_type = internal_cmd.command_type
          ; receiver_id
          ; fee = Currency.Fee.to_string internal_cmd.fee
          ; hash =
              internal_cmd.hash |> txn_hash_to_base58_check ~v1_transaction_hash
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

  type t = { kind : Kind.t; receiver_id : int; fee : int64; hash : string }

  let typ =
    let encode t =
      let kind = Kind.to_string t.kind in
      Ok (kind, t.receiver_id, t.fee, t.hash)
    in
    let decode (kind, receiver_id, fee, hash) =
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
      Ok { kind; receiver_id; fee; hash }
    in
    let rep = Caqti_type.(tup4 string int int64 string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      ?(v1_transaction_hash = false) (t : Fee_transfer.Single.t)
      (kind : [ `Normal | `Via_coinbase ]) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_fee_transfer t in
    match%bind
      Internal_command.find_opt
        (module Conn)
        ~v1_transaction_hash ~transaction_hash
        ~command_type:(Kind.to_string kind)
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          let pk = Fee_transfer.Single.receiver_pk t in
          Public_key.add_if_doesn't_exist (module Conn) pk
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO internal_commands
                    (command_type, receiver_id, fee, hash)
                   VALUES (?::internal_command_type, ?, ?, ?)
                   RETURNING id
             |sql} )
          { kind
          ; receiver_id
          ; fee =
              Fee_transfer.Single.fee t |> Currency.Fee.to_uint64
              |> Unsigned.UInt64.to_int64
          ; hash =
              transaction_hash |> txn_hash_to_base58_check ~v1_transaction_hash
          }
end

module Coinbase = struct
  type t = { receiver_id : int; amount : int64; hash : string }

  let coinbase_command_type = "coinbase"

  let typ =
    let encode t =
      Ok (coinbase_command_type, t.receiver_id, t.amount, t.hash)
    in
    let decode (_, receiver_id, amount, hash) =
      Ok { receiver_id; amount; hash }
    in
    let rep = Caqti_type.(tup4 string int int64 string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      ?(v1_transaction_hash = false) (t : Coinbase.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_coinbase t in
    match%bind
      Internal_command.find_opt
        (module Conn)
        ~v1_transaction_hash ~transaction_hash
        ~command_type:coinbase_command_type
    with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          let pk = Coinbase.receiver_pk t in
          Public_key.add_if_doesn't_exist (module Conn) pk
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {sql| INSERT INTO internal_commands
                    (command_type, receiver_id, fee, hash)
                   VALUES (?::internal_command_type, ?, ?, ?)
                   RETURNING id
             |sql} )
          { receiver_id
          ; amount =
              Coinbase.amount t |> Currency.Amount.to_uint64
              |> Unsigned.UInt64.to_int64
          ; hash =
              transaction_hash |> txn_hash_to_base58_check ~v1_transaction_hash
          }
end

module Block_and_internal_command = struct
  type t =
    { block_id : int
    ; internal_command_id : int
    ; sequence_no : int
    ; secondary_sequence_no : int
    ; status : string
    ; failure_reason : string option
    }
  [@@deriving hlist, fields]

  let table_name = "blocks_internal_commands"

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; int; string; option string ]

  let add (module Conn : CONNECTION) ~block_id ~internal_command_id ~sequence_no
      ~secondary_sequence_no ~status
      ~(failure_reason : Transaction_status.Failure.t option) =
    let failure_reason =
      Option.map ~f:Transaction_status.Failure.to_string failure_reason
    in
    Conn.exec
      (Caqti_request.exec typ
         {sql| INSERT INTO blocks_internal_commands
                 (block_id,
                 internal_command_id,
                 sequence_no,
                 secondary_sequence_no,
                 status,
                 failure_reason)
               VALUES (?, ?, ?, ?, ?::transaction_status, ?)
         |sql} )
      { block_id
      ; internal_command_id
      ; sequence_no
      ; secondary_sequence_no
      ; status
      ; failure_reason
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
         |sql} )
      (block_id, internal_command_id, sequence_no, secondary_sequence_no)

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id
      ~internal_command_id ~sequence_no ~secondary_sequence_no ~status
      ~failure_reason =
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
          ~status ~failure_reason

  let load (module Conn : CONNECTION) ~block_id ~internal_command_id
      ~sequence_no ~secondary_sequence_no =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup4 int int int int)
         typ
         (sprintf
            {sql| SELECT %s FROM blocks_internal_commands
               WHERE block_id = $1
               AND internal_command_id = $2
               AND sequence_no = $3
               AND secondary_sequence_no = $4
           |sql}
            comma_cols ) )
      (block_id, internal_command_id, sequence_no, secondary_sequence_no)
end

module Block_and_signed_command = struct
  type t =
    { block_id : int
    ; user_command_id : int
    ; sequence_no : int
    ; status : string
    ; failure_reason : string option
    }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; string; option string ]

  let table_name = "blocks_user_commands"

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
               VALUES (?, ?, ?, ?::transaction_status, ?)
         |sql} )
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
           |sql} )
        (block_id, user_command_id, sequence_no)
    with
    | Some _ ->
        return ()
    | None ->
        add
          (module Conn)
          ~block_id ~user_command_id ~sequence_no ~status ~failure_reason

  let load (module Conn : CONNECTION) ~block_id ~user_command_id ~sequence_no =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         typ
         (sprintf
            {sql| SELECT %s FROM blocks_user_commands
               WHERE block_id = $1
               AND user_command_id = $2
               AND sequence_no = $3
           |sql}
            comma_cols ) )
      (block_id, user_command_id, sequence_no)
end

module Zkapp_account_update_failures = struct
  type t = { index : int; failures : string array } [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; Mina_caqti.array_string_typ ]

  let table_name = "zkapp_account_update_failures"

  let add_if_doesn't_exist (module Conn : CONNECTION) index failures =
    let failures =
      List.map failures ~f:Transaction_status.Failure.to_string |> Array.of_list
    in
    Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
      ~table_name
      ~tannot:(function "failures" -> Some "text[]" | _ -> None)
      ~cols:([ "index"; "failures" ], typ)
      (module Conn)
      { index; failures }

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name
            ~cols:[ "index"; "failures" ] ) )
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
  [@@deriving hlist, fields]

  let table_name = "blocks_zkapp_commands"

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int; string; option Mina_caqti.array_int_typ ]

  let add_if_doesn't_exist (module Conn : CONNECTION) ~block_id
      ~zkapp_command_id ~sequence_no ~status
      ~(failure_reasons : Transaction_status.Failure.Collection.Display.t option)
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
                Zkapp_account_update_failures.add_if_doesn't_exist
                  (module Conn)
                  ndx failure_reasons )
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
      ~tannot:(function
        | "status" ->
            Some "transaction_status"
        | "failure_reasons_ids" ->
            Some "int[]"
        | _ ->
            None )
      (module Conn)
      { block_id; zkapp_command_id; sequence_no; status; failure_reasons_ids }

  let load (module Conn : CONNECTION) ~block_id ~zkapp_command_id ~sequence_no =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.find
      (Caqti_request.find
         Caqti_type.(tup3 int int int)
         typ
         (Mina_caqti.select_cols ~table_name ~select:comma_cols
            ~cols:[ "block_id"; "zkapp_command_id"; "sequence_no" ]
            () ) )
      (block_id, zkapp_command_id, sequence_no)

  let all_from_block (module Conn : CONNECTION) ~block_id =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.collect_list
      (Caqti_request.collect Caqti_type.int typ
         (Mina_caqti.select_cols ~table_name ~select:comma_cols
            ~cols:[ "block_id" ] () ) )
      block_id
end

module Zkapp_account = struct
  type t =
    { app_state_id : int
    ; verification_key_id : int option
    ; zkapp_version : int64
    ; action_state_id : int
    ; last_action_slot : int64
    ; proved_state : bool
    ; zkapp_uri_id : int
    }
  [@@deriving fields, hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; option int; int64; int; int64; bool; int ]

  let table_name = "zkapp_accounts"

  let add_if_doesn't_exist (module Conn : CONNECTION) zkapp_account =
    let open Deferred.Result.Let_syntax in
    let ({ app_state
         ; verification_key
         ; zkapp_version
         ; action_state
         ; last_action_slot
         ; proved_state
         ; zkapp_uri
         }
          : Mina_base.Zkapp_account.t ) =
      zkapp_account
    in
    let%bind app_state_id =
      Zkapp_states.add_if_doesn't_exist (module Conn) app_state
    in
    let%bind verification_key_id =
      Option.value_map verification_key ~default:(return None) ~f:(fun vk ->
          let%map id =
            Zkapp_verification_keys.add_if_doesn't_exist (module Conn) vk
          in
          Some id )
    in
    let zkapp_version = zkapp_version |> Unsigned.UInt32.to_int64 in
    let%bind action_state_id =
      Zkapp_action_states.add_if_doesn't_exist (module Conn) action_state
    in
    let last_action_slot =
      Mina_numbers.Global_slot_since_genesis.to_uint32 last_action_slot
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
      ; action_state_id
      ; last_action_slot
      ; proved_state
      ; zkapp_uri_id
      }

  let load (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
end

module Accounts_accessed = struct
  type t =
    { ledger_index : int
    ; block_id : int
    ; account_identifier_id : int
    ; token_symbol_id : int
    ; balance : string
    ; nonce : int64
    ; receipt_chain_hash : string
    ; delegate_id : int option
    ; voting_for_id : int
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
        ; int
        ; string
        ; int64
        ; string
        ; option int
        ; int
        ; int
        ; int
        ; option int
        ]

  let table_name = "accounts_accessed"

  let find_opt (module Conn : CONNECTION) ~block_id ~account_identifier_id =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.find_opt
      (Caqti_request.find_opt
         Caqti_type.(tup2 int int)
         typ
         (sprintf
            {sql| SELECT %s
                  FROM %s
                  WHERE block_id = $1
                  AND   account_identifier_id = $2
            |sql}
            comma_cols table_name ) )
      (block_id, account_identifier_id)

  let add_if_doesn't_exist (module Conn : CONNECTION) block_id
      (ledger_index, (account : Account.t)) =
    let open Deferred.Result.Let_syntax in
    let account_id = Account_id.create account.public_key account.token_id in
    let%bind account_identifier_id =
      Account_identifiers.add_if_doesn't_exist (module Conn) account_id
    in
    match%bind find_opt (module Conn) ~block_id ~account_identifier_id with
    | Some result ->
        return (result.block_id, result.account_identifier_id)
    | None ->
        let%bind token_symbol_id =
          Token_symbols.add_if_doesn't_exist (module Conn) account.token_symbol
        in
        let balance = Currency.Balance.to_string account.balance in
        let nonce =
          account.nonce |> Account.Nonce.to_uint32 |> Unsigned.UInt32.to_int64
        in
        let receipt_chain_hash =
          account.receipt_chain_hash |> Receipt.Chain_hash.to_base58_check
        in
        let%bind delegate_id =
          Mina_caqti.add_if_some
            (Public_key.add_if_doesn't_exist (module Conn))
            account.delegate
        in
        let%bind voting_for_id =
          Voting_for.add_if_doesn't_exist (module Conn) account.voting_for
        in
        let%bind timing_id =
          Timing_info.add_if_doesn't_exist
            (module Conn)
            account_identifier_id account.timing
        in
        let%bind permissions_id =
          Zkapp_permissions.add_if_doesn't_exist
            (module Conn)
            account.permissions
        in
        let%bind zkapp_id =
          Mina_caqti.add_if_some
            (Zkapp_account.add_if_doesn't_exist (module Conn))
            account.zkapp
        in
        let account_accessed : t =
          { ledger_index
          ; block_id
          ; account_identifier_id
          ; token_symbol_id
          ; balance
          ; nonce
          ; receipt_chain_hash
          ; delegate_id
          ; voting_for_id
          ; timing_id
          ; permissions_id
          ; zkapp_id
          }
        in
        Mina_caqti.select_insert_into_cols
          ~select:("block_id,account_identifier_id", Caqti_type.(tup2 int int))
          ~table_name ~cols:(Fields.names, typ)
          (module Conn)
          account_accessed

  let add_accounts_if_don't_exist (module Conn : CONNECTION) block_id
      (accounts : (int * Account.t) list) =
    let%map results =
      Deferred.List.map accounts ~f:(fun account ->
          add_if_doesn't_exist (module Conn) block_id account )
    in
    Result.all results

  let all_from_block (module Conn : CONNECTION) block_id =
    let comma_cols = String.concat Fields.names ~sep:"," in
    Conn.collect_list
      (Caqti_request.collect Caqti_type.int typ
         (Mina_caqti.select_cols ~select:comma_cols ~table_name
            ~cols:[ "block_id" ] () ) )
      block_id
end

module Accounts_created = struct
  type t =
    { block_id : int; account_identifier_id : int; creation_fee : string }
  [@@deriving hlist, fields]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; string ]

  let table_name = "accounts_created"

  let add_if_doesn't_exist (module Conn : CONNECTION) block_id account_id
      creation_fee =
    let open Deferred.Result.Let_syntax in
    let%bind account_identifier_id =
      Account_identifiers.add_if_doesn't_exist (module Conn) account_id
    in
    let creation_fee = Currency.Fee.to_string creation_fee in
    Mina_caqti.select_insert_into_cols
      ~select:("block_id,account_identifier_id", Caqti_type.(tup2 int int))
      ~table_name ~cols:(Fields.names, typ)
      (module Conn)
      { block_id; account_identifier_id; creation_fee }

  let add_accounts_created_if_don't_exist (module Conn : CONNECTION) block_id
      accounts_created =
    let%map results =
      Deferred.List.map accounts_created ~f:(fun (pk, creation_fee) ->
          add_if_doesn't_exist (module Conn) block_id pk creation_fee )
    in
    Result.all results

  let all_from_block (module Conn : CONNECTION) block_id =
    Conn.collect_list
      (Caqti_request.collect Caqti_type.int typ
         {sql| SELECT block_id, account_identifier_id, creation_fee
               FROM accounts_created
               WHERE block_id = ?
         |sql} )
      block_id
end

module Block = struct
  type t =
    { state_hash : string
    ; parent_id : int option
    ; parent_hash : string
    ; creator_id : int
    ; block_winner_id : int
    ; last_vrf_output : string
    ; snarked_ledger_hash_id : int
    ; staking_epoch_data_id : int
    ; next_epoch_data_id : int
    ; min_window_density : int64
    ; sub_window_densities : int64 array
    ; total_currency : string
    ; ledger_hash : string
    ; height : int64
    ; global_slot_since_hard_fork : int64
    ; global_slot_since_genesis : int64
    ; protocol_version_id : int
    ; proposed_protocol_version_id : int option
    ; timestamp : string
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
        ; string
        ; int
        ; int
        ; int
        ; int64
        ; Mina_caqti.array_int64_typ
        ; string
        ; string
        ; int64
        ; int64
        ; int64
        ; int
        ; option int
        ; string
        ; string
        ]

  let table_name = "blocks"

  let make_finder conn_finder req_finder ~state_hash =
    conn_finder
      (req_finder Caqti_type.string Caqti_type.int
         "SELECT id FROM blocks WHERE state_hash = ?" )
      (State_hash.to_base58_check state_hash)

  let find (module Conn : CONNECTION) = make_finder Conn.find Caqti_request.find

  let find_opt (module Conn : CONNECTION) =
    make_finder Conn.find_opt Caqti_request.find_opt

  let load (module Conn : CONNECTION) ~id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name:"blocks" ~cols:Fields.names) )
      id

  let add_parts_if_doesn't_exist (module Conn : CONNECTION)
      ~constraint_constants ~protocol_state ~staged_ledger_diff
      ~protocol_version ~proposed_protocol_version ~hash ~v1_transaction_hash =
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
        let last_vrf_output =
          (* encode as base64, same as in precomputed blocks JSON *)
          Consensus.Data.Consensus_state.last_vrf_output consensus_state
          |> Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet
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
        let global_slot_since_hard_fork =
          Mina_numbers.Global_slot_since_hard_fork.to_uint32
          @@ Consensus.Data.Consensus_state.curr_global_slot consensus_state
          |> Unsigned.UInt32.to_int64
        in
        let%bind protocol_version_id =
          let transaction = Protocol_version.transaction protocol_version in
          let network = Protocol_version.network protocol_version in
          let patch = Protocol_version.patch protocol_version in
          Protocol_versions.add_if_doesn't_exist
            (module Conn)
            ~transaction ~network ~patch
        in
        let%bind proposed_protocol_version_id =
          Option.value_map proposed_protocol_version ~default:(return None)
            ~f:(fun ppv ->
              let transaction = Protocol_version.transaction ppv in
              let network = Protocol_version.network ppv in
              let patch = Protocol_version.patch ppv in
              let%map id =
                Protocol_versions.add_if_doesn't_exist
                  (module Conn)
                  ~transaction ~network ~patch
              in
              Some id )
        in
        let chain_status =
          if Int64.equal global_slot_since_hard_fork 0L then
            (* at-launch genesis block, or genesis block at hard fork *)
            Chain_status.(to_string Canonical)
          else Chain_status.(to_string Pending)
        in
        let consensus_state = Protocol_state.consensus_state protocol_state in
        let blockchain_state = Protocol_state.blockchain_state protocol_state in
        let%bind block_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               (Mina_caqti.insert_into_cols ~returning:"id" ~table_name
                  ~tannot:(function
                    | "chain_status" ->
                        Some "chain_status_type"
                    | "sub_window_densities" ->
                        Some "bigint[]"
                    | _ ->
                        None )
                  ~cols:Fields.names () ) )
            { state_hash = hash |> State_hash.to_base58_check
            ; parent_id
            ; parent_hash =
                Protocol_state.previous_state_hash protocol_state
                |> State_hash.to_base58_check
            ; creator_id
            ; block_winner_id
            ; last_vrf_output
            ; snarked_ledger_hash_id
            ; staking_epoch_data_id
            ; next_epoch_data_id
            ; min_window_density =
                consensus_state
                |> Consensus.Data.Consensus_state.min_window_density
                |> Mina_numbers.Length.to_uint32 |> Unsigned.UInt32.to_int64
            ; sub_window_densities =
                consensus_state
                |> Consensus.Data.Consensus_state.sub_window_densities
                |> List.map ~f:(fun length ->
                       Mina_numbers.Length.to_uint32 length
                       |> Unsigned.UInt32.to_int64 )
                |> Array.of_list
            ; total_currency =
                consensus_state |> Consensus.Data.Consensus_state.total_currency
                |> Currency.Amount.to_string
            ; ledger_hash =
                blockchain_state |> Blockchain_state.staged_ledger_hash
                |> Staged_ledger_hash.ledger_hash |> Ledger_hash.to_base58_check
            ; height
            ; global_slot_since_hard_fork
            ; global_slot_since_genesis =
                consensus_state
                |> Consensus.Data.Consensus_state.global_slot_since_genesis
                |> Mina_numbers.Global_slot_since_genesis.to_uint32
                |> Unsigned.UInt32.to_int64
            ; protocol_version_id
            ; proposed_protocol_version_id
            ; timestamp =
                blockchain_state |> Blockchain_state.timestamp
                |> Block_time.to_string_exn
            ; chain_status
            }
        in
        let applied_status = (applied_str, None) in
        let failure_reasons status =
          match status with
          | Transaction_status.Applied ->
              applied_status
          | Failed failures ->
              let display =
                Transaction_status.Failure.Collection.to_display failures
              in
              (failed_str, Some display)
        in
        let%bind _seq_no =
          Metrics.time ~label:"adding_transactions"
          @@ fun () ->
          Mina_caqti.deferred_result_list_fold transactions ~init:0
            ~f:(fun sequence_no -> function
            | { Mina_base.With_status.status
              ; data = Transaction.Command command
              } ->
                let user_command =
                  { Mina_base.With_status.status; data = command }
                in
                let%bind id =
                  User_command.add_if_doesn't_exist
                    (module Conn)
                    ~v1_transaction_hash user_command.data
                in
                let%map () =
                  match command with
                  | Signed_command _ ->
                      Block_and_signed_command.add_with_status
                        (module Conn)
                        ~block_id ~user_command_id:id ~sequence_no
                        ~status:user_command.status
                      >>| ignore
                  | Zkapp_command _ ->
                      let status, failure_reasons =
                        failure_reasons user_command.status
                      in
                      Metrics.time
                        ~label:"block_and_zkapp_command.add_if_doesn't_exist"
                      @@ fun () ->
                      Block_and_zkapp_command.add_if_doesn't_exist
                        (module Conn)
                        ~block_id ~zkapp_command_id:id ~sequence_no ~status
                        ~failure_reasons
                      >>| ignore
                in
                sequence_no + 1
            | { data = Fee_transfer fee_transfer_bundled; status } ->
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
                      :: acc )
                in
                let fee_transfer_infos_with_balances =
                  (*Structure of the failure status:
                    I. Only one fee transfer in the transaction (`One) and it fails:
                        [[failure]]
                    II. Two fee transfers in the transaction (`Two)-
                        Both fee transfers fail:
                          [[failure-of-first-fee-transfer]; [failure-of-second-fee-transfer]]
                        First succeeds and second one fails:
                          [[];[failure-of-second-fee-transfer]]
                        First fails and second succeeds:
                          [[failure-of-first-fee-transfer];[]]
                  *)
                  match fee_transfer_infos with
                  | [ id ] ->
                      let status =
                        match status with
                        | Applied ->
                            (applied_str, None)
                        | Failed failures -> (
                            (* for a single fee transfer, there's exactly one failure *)
                            match failures with
                            | [ [ failure ] ] ->
                                (failed_str, Some failure)
                            | _ ->
                                failwithf
                                  !"Invalid failure status %{sexp: \
                                    Transaction_status.Failure.Collection.t} \
                                    for fee transfer %{sexp: \
                                    Mina_base.Fee_transfer.t}"
                                  failures fee_transfer_bundled () )
                      in
                      [ (id, status) ]
                  | [ id2; id1 ] ->
                      (* the fold reverses the order of the infos from the fee transfers *)
                      let status1, status2 =
                        match status with
                        | Applied ->
                            (applied_status, applied_status)
                        | Failed failures -> (
                            (* at most two failures for a fee transfer *)
                            match failures with
                            | [ [ failure1 ]; [ failure2 ] ] ->
                                ( (failed_str, Some failure1)
                                , (failed_str, Some failure2) )
                            | [ [ failure1 ]; [] ] ->
                                ((failed_str, Some failure1), applied_status)
                            | [ []; [ failure2 ] ] ->
                                (applied_status, (failed_str, Some failure2))
                            | _ ->
                                failwithf
                                  !"Invalid failure status %{sexp: \
                                    Transaction_status.Failure.Collection.t} \
                                    for fee transfer %{sexp: \
                                    Mina_base.Fee_transfer.t}"
                                  failures fee_transfer_bundled () )
                      in
                      [ (id1, status1); (id2, status2) ]
                  | _ ->
                      failwithf
                        !"Unexpected number of single fee transfers in a fee \
                          transfer transaction %{sexp: \
                          Mina_base.Fee_transfer.t}"
                        fee_transfer_bundled ()
                in
                let%map () =
                  Mina_caqti.deferred_result_list_fold
                    fee_transfer_infos_with_balances ~init:()
                    ~f:(fun
                         ()
                         ( (fee_transfer_id, secondary_sequence_no, _, _)
                         , (status, failure_reason) )
                       ->
                      Block_and_internal_command.add
                        (module Conn)
                        ~block_id ~internal_command_id:fee_transfer_id
                        ~sequence_no ~secondary_sequence_no ~status
                        ~failure_reason
                      >>| ignore )
                in
                sequence_no + 1
            | { data = Coinbase coinbase; status } ->
                let fee_transfer_via_coinbase =
                  Mina_base.Coinbase.fee_transfer coinbase
                in
                (*Structure of the failure status:
                  I. No fee transfer and coinbase transfer fails: [[failure]]
                  II. With fee transfer-
                    Both fee transfer and coinbase fails:
                      [[failure-of-fee-transfer]; [failure-of-coinbase]]
                    Fee transfer succeeds and coinbase fails:
                      [[];[failure-of-coinbase]]
                    Fee transfer fails and coinbase succeeds:
                      [[failure-of-fee-transfer];[]]
                *)
                let%bind () =
                  match fee_transfer_via_coinbase with
                  | None ->
                      return ()
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
                      let status, failure_reason =
                        match status with
                        | Applied ->
                            (applied_str, None)
                        | Failed failures -> (
                            (* at most two failures in a coinbase transaction First one for the fee transfer and the second for reward transfer*)
                            match failures with
                            | [ []; _ ] ->
                                applied_status
                            | [ [ failure1 ]; _ ] ->
                                (failed_str, Some failure1)
                            | _ ->
                                failwithf
                                  !"Invalid failure status %{sexp: \
                                    Transaction_status.Failure.Collection.t} \
                                    for fee transfer in a coinbase transaction \
                                    %{sexp: Mina_base.Coinbase.t}"
                                  failures coinbase () )
                      in
                      Block_and_internal_command.add
                        (module Conn)
                        ~block_id ~internal_command_id:id ~sequence_no
                        ~secondary_sequence_no:0 ~status ~failure_reason
                in
                let%bind id =
                  Coinbase.add_if_doesn't_exist (module Conn) coinbase
                in
                let status, failure_reason =
                  match status with
                  | Applied ->
                      (applied_str, None)
                  | Failed failures -> (
                      (* at most two failures in a coinbase transaction First one for the fee transfer (if any) and the second for reward transfer*)
                      match
                        (failures, Option.is_none fee_transfer_via_coinbase)
                      with
                      | [ [] ], true ->
                          failwithf
                            !"Expecting the status to be Applied if there are \
                              no failures in coinbase transaction %{sexp: \
                              Mina_base.Coinbase.t}"
                            coinbase ()
                      | [ _; [] ], false ->
                          applied_status
                      | [ [ failure2 ] ], true ->
                          (failed_str, Some failure2)
                      | [ _; [ failure2 ] ], false ->
                          (failed_str, Some failure2)
                      | _ ->
                          failwithf
                            !"Invalid failure status %{sexp: \
                              Transaction_status.Failure.Collection.t} for \
                              reward transfer in coinbase transaction %{sexp: \
                              Mina_base.Coinbase.t}"
                            failures coinbase () )
                in
                let%map () =
                  Block_and_internal_command.add
                    (module Conn)
                    ~block_id ~internal_command_id:id ~sequence_no
                    ~secondary_sequence_no:0 ~status ~failure_reason
                  >>| ignore
                in
                sequence_no + 1 )
        in
        return block_id

  let add_if_doesn't_exist conn ~constraint_constants
      ({ data = t; hash = { state_hash = hash; _ } } :
        Mina_block.t State_hash.With_state_hashes.t ) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:(Header.protocol_state @@ Mina_block.header t)
      ~staged_ledger_diff:(Body.staged_ledger_diff @@ Mina_block.body t)
      ~protocol_version:(Header.current_protocol_version @@ Mina_block.header t)
      ~proposed_protocol_version:
        (Header.proposed_protocol_version_opt @@ Mina_block.header t)
      ~hash ~v1_transaction_hash:false

  let add_from_precomputed conn ~constraint_constants (t : Precomputed.t) =
    add_parts_if_doesn't_exist conn ~constraint_constants
      ~protocol_state:t.protocol_state ~staged_ledger_diff:t.staged_ledger_diff
      ~protocol_version:t.protocol_version
      ~proposed_protocol_version:t.proposed_protocol_version
      ~hash:(Protocol_state.hashes t.protocol_state).state_hash
      ~v1_transaction_hash:false

  (* NB: this batching logic an lead to partial writes; it is acceptable to be used with the
     migration tool, but not acceptable to be used with the archive node in its current form *)
  let add_from_extensional_batch (module Conn : CONNECTION)
      ?(v1_transaction_hash = false) (blocks : Extensional.Block.t list) =
    let open Deferred.Result.Let_syntax in
    (* zkapps are currently unsupported in the batch implementation of this function *)
    assert (List.for_all blocks ~f:(fun block -> List.is_empty block.zkapp_cmds)) ;

    let epoch_data_to_repr (e : Mina_base.Epoch_data.t)
        ~(find_ledger_hash_id : Ledger_hash.t -> int) : Epoch_data.t =
      { seed = Epoch_seed.to_base58_check e.seed
      ; ledger_hash_id = find_ledger_hash_id e.ledger.hash
      ; total_currency = Currency.Amount.to_string e.ledger.total_currency
      ; start_checkpoint = State_hash.to_base58_check e.start_checkpoint
      ; lock_checkpoint = State_hash.to_base58_check e.lock_checkpoint
      ; epoch_length =
          Unsigned_extended.UInt32.to_int64
          @@ Mina_numbers.Length.to_uint32 e.epoch_length
      }
    in
    (* TODO: this doesn't handle non-default tokens, and doesn't cache token owners like the old implementation *)
    let token_id_to_repr (id : Token_id.t) : Token.t =
      assert (Token_id.equal id Token_id.default) ;
      { value = Token_id.to_string id
      ; owner_public_key_id = None
      ; owner_token_id = None
      }
    in
    let user_cmd_to_repr (c : Extensional.User_command.t)
        ~(find_public_key_id : Signature_lib.Public_key.Compressed.t -> int) :
        User_command.Signed_command.t =
      let hash = txn_hash_to_base58_check c.hash ~v1_transaction_hash in
      (* let fee_payer_id = find_account_id (Account_id.create c.fee_payer Token_id.default) in *)
      (* let receiver_id = find_account_id (Account_id.create c.receiver Token_id.default) in *)
      let fee_payer_id = find_public_key_id c.fee_payer in
      let receiver_id = find_public_key_id c.receiver in
      { command_type = c.command_type
      ; hash
      ; fee_payer_id
      ; source_id = fee_payer_id
      ; receiver_id
      ; nonce = Unsigned_extended.UInt32.to_int64 c.nonce
      ; amount = Option.map c.amount ~f:Currency.Amount.to_string
      ; fee = Currency.Fee.to_string c.fee
      ; valid_until =
          Option.map c.valid_until
            ~f:
              (Fn.compose Unsigned.UInt32.to_int64
                 Mina_numbers.Global_slot_since_genesis.to_uint32 )
      ; memo = Mina_base.Signed_command_memo.to_base58_check c.memo
      }
    in
    let internal_cmd_to_repr (c : Extensional.Internal_command.t)
        ~(find_public_key_id : Signature_lib.Public_key.Compressed.t -> int) :
        Internal_command.t =
      let hash = txn_hash_to_base58_check c.hash ~v1_transaction_hash in
      { command_type = c.command_type
      ; hash
      ; receiver_id = find_public_key_id c.receiver
      ; fee = Currency.Fee.to_string c.fee
      }
    in

    (* we don't need to specify all types here, just the ones that sql may infer incorrectly *)
    let field_name : type a. a Caqti_type.Field.t -> string option =
      let open Caqti_type in
      function
      | Bool ->
          Some "BOOL"
      | Int ->
          Some "INT"
      | Int16 ->
          Some "SMALLINT"
      | Int32 ->
          Some "INT"
      | Int64 ->
          Some "BIGINT"
      | Float ->
          Some "FLOAT"
      | Enum name ->
          Some name
      | _ ->
          None
    in

    let rec type_field_names : type a. a Caqti_type.t -> string option list =
      function
      | Unit ->
          []
      | Field f ->
          [ field_name f ]
      | Option t ->
          type_field_names t
      | Tup2 (at, bt) ->
          List.concat [ type_field_names at; type_field_names bt ]
      | Tup3 (at, bt, ct) ->
          List.concat
            [ type_field_names at; type_field_names bt; type_field_names ct ]
      | Tup4 (at, bt, ct, dt) ->
          List.concat
            [ type_field_names at
            ; type_field_names bt
            ; type_field_names ct
            ; type_field_names dt
            ]
      | Custom custom ->
          type_field_names custom.rep
    in

    let rec render_field : type a. a Caqti_type.Field.t -> a -> string =
     fun typ value ->
      let open Caqti_type in
      match typ with
      | Bool ->
          Bool.to_string value
      | Int ->
          Int.to_string value
      | Int16 ->
          Int.to_string value
      | Int32 ->
          Int32.to_string value
      | Int64 ->
          Int64.to_string value
      | Float ->
          Float.to_string value
      | String ->
          "'" ^ value ^ "'"
      | Octets ->
          failwith "todo: support caqti octets"
      | Pdate ->
          failwith "todo: support caqti date"
      | Ptime ->
          failwith "todo: support caqti ptime"
      | Ptime_span ->
          failwith "todo: support caqti ptime_span"
      | Enum _ ->
          (* we are ignoring the enum annotation in this context because it's not always valid to apply *)
          (* NOTE: we assume enum values do not contain special characters (eg "'") *)
          "'" ^ value ^ "'"
      | _ -> (
          match Caqti_type.Field.coding Conn.driver_info typ with
          | None ->
              failwithf "unable to render caqti field: %s"
                (Caqti_type.Field.to_string typ)
                ()
          | Some (Coding coding) ->
              render_field coding.rep
                (Result.ok_or_failwith @@ coding.encode value) )
    in
    let rec render_type : type a. a Caqti_type.t -> a -> string list =
     fun typ value ->
      match typ with
      | Unit ->
          []
      | Field f ->
          [ render_field f value ]
      | Option t -> (
          match value with
          | None ->
              List.init (Caqti_type.length typ) ~f:(Fn.const "NULL")
          | Some x ->
              render_type t x )
      | Tup2 (at, bt) ->
          let a, b = value in
          List.concat [ render_type at a; render_type bt b ]
      | Tup3 (at, bt, ct) ->
          let a, b, c = value in
          List.concat [ render_type at a; render_type bt b; render_type ct c ]
      | Tup4 (at, bt, ct, dt) ->
          let a, b, c, d = value in
          List.concat
            [ render_type at a
            ; render_type bt b
            ; render_type ct c
            ; render_type dt d
            ]
      | Custom custom ->
          render_type custom.rep (Result.ok_or_failwith @@ custom.encode value)
    in
    let render_row (type a) (typ : a Caqti_type.t) (value : a) : string =
      "(" ^ String.concat ~sep:"," (render_type typ value) ^ ")"
    in

    let load_index (type a cmp) (comparator : (a, cmp) Map.comparator)
        (typ : a Caqti_type.t) (values : a list) ~table ~(fields : string list)
        : ((a, int, cmp) Map.t, 'err) Deferred.Result.t =
      assert (Caqti_type.length typ = List.length fields) ;
      if List.is_empty values then return (Map.empty comparator)
      else
        let fields_sql = String.concat ~sep:"," fields in
        let query =
          if List.length fields > 1 then
            let src_fields_sql =
              String.concat ~sep:","
              @@ List.map fields ~f:(fun field -> sprintf "src.%s" field)
            in
            let join_on_sql =
              (* we use distinction instead of equality here, as NULL != NULL, but NULL IS NOT DISTINCT FROM NULL *)
              List.zip_exn fields (type_field_names typ)
              |> List.map ~f:(fun (field, type_name_opt) ->
                     match type_name_opt with
                     | None ->
                         sprintf "src.%s IS NOT DISTINCT FROM data.%s" field
                           field
                     | Some type_name ->
                         sprintf
                           "src.%s IS NOT DISTINCT FROM CAST(data.%s AS %s)"
                           field field type_name )
              |> String.concat ~sep:" AND "
            in
            let values_sql =
              String.concat ~sep:"," @@ List.map values ~f:(render_row typ)
            in
            sprintf
              "SELECT %s, src.id FROM %s AS src JOIN (VALUES %s) as data (%s) \
               ON %s"
              src_fields_sql table values_sql fields_sql join_on_sql
          else
            let values_sql =
              "("
              ^ String.concat ~sep:"," (List.bind values ~f:(render_type typ))
              ^ ")"
            in
            sprintf "SELECT %s, id FROM %s WHERE %s IN %s" fields_sql table
              fields_sql values_sql
        in
        let%map entries =
          Conn.collect_list
            (Caqti_request.collect Caqti_type.unit
               Caqti_type.(tup2 typ int)
               query )
            ()
        in
        Map.of_alist_exn comparator entries
    in

    let bulk_insert (type value) (typ : value Caqti_type.t)
        (values : value list) ~(fields : string list) ~(table : string) :
        (int list, 'err) Deferred.Result.t =
      if List.is_empty values then return []
      else (
        assert (Caqti_type.length typ = List.length fields) ;
        let fields_sql = String.concat ~sep:"," fields in
        let values_sql =
          String.concat ~sep:"," @@ List.map ~f:(render_row typ) values
        in
        Conn.collect_list
          (Caqti_request.collect Caqti_type.unit Caqti_type.int
             (sprintf "INSERT INTO %s (%s) VALUES %s RETURNING id" table
                fields_sql values_sql ) )
          () )
    in

    let partition_existing (type a key key_cmp) (entries : a list)
        ~(get_key : a -> key)
        ~(load_index :
           key list -> ((key, int, key_cmp) Map.t, 'err) Deferred.Result.t ) :
        ( [ `Existing of (key, int, key_cmp) Map.t ] * [ `Missing of a list ]
        , 'err )
        Deferred.Result.t =
      let%map ids = load_index (List.map entries ~f:get_key) in
      let missing =
        List.filter entries ~f:(fun value -> not (Map.mem ids (get_key value)))
      in
      (`Existing ids, `Missing missing)
    in
    (* TODO: undo the unused key vs value abstraction *)
    let differential_insert (type a value key key_cmp)
        (key_comparator : (key, key_cmp) Map.comparator) (entries : a list)
        ~(get_key : a -> key) ~(get_value : a -> value)
        ~(load_index :
           key list -> ((key, int, key_cmp) Map.t, 'err) Deferred.Result.t )
        ~(insert_values : value list -> (int list, 'err) Deferred.Result.t) :
        ((key, int, key_cmp) Map.t, 'err) Deferred.Result.t =
      let%bind `Existing existing_entries, `Missing missing_entries =
        partition_existing entries ~get_key ~load_index
      in
      let missing_values = List.map missing_entries ~f:get_value in
      let%map created_ids = insert_values missing_values in
      let new_entries =
        Map.of_alist_exn key_comparator
          (List.zip_exn (List.map ~f:get_key missing_entries) created_ids)
      in
      Map.merge existing_entries new_entries ~f:(fun ~key:_ conflict ->
          match conflict with
          | `Both _ ->
              failwith "duplicate data loaded during differential insertion"
          | `Left x | `Right x ->
              Some x )
    in

    let state_hash_typ : State_hash.t Caqti_type.t =
      let encode h = Ok (State_hash.to_base58_check h) in
      let decode s =
        Result.map_error ~f:Error.to_string_hum (State_hash.of_base58_check s)
      in
      Caqti_type.custom ~encode ~decode Caqti_type.string
    in
    let public_key_typ : Signature_lib.Public_key.Compressed.t Caqti_type.t =
      let encode h =
        Ok (Signature_lib.Public_key.Compressed.to_base58_check h)
      in
      let decode s =
        Result.map_error ~f:Error.to_string_hum
          (Signature_lib.Public_key.Compressed.of_base58_check s)
      in
      Caqti_type.custom ~encode ~decode Caqti_type.string
    in
    let ledger_hash_typ : Ledger_hash.t Caqti_type.t =
      let encode h = Ok (Ledger_hash.to_base58_check h) in
      let decode s =
        Result.map_error ~f:Error.to_string_hum (Ledger_hash.of_base58_check s)
      in
      Caqti_type.custom ~encode ~decode Caqti_type.string
    in

    let external_block_hashes =
      let block_hashes =
        State_hash.Set.of_list
        @@ List.map blocks ~f:(fun { state_hash; _ } -> state_hash)
      in
      let dependency_hashes =
        State_hash.Set.of_list
        @@ List.map blocks ~f:(fun { parent_hash; _ } -> parent_hash)
      in
      Set.diff dependency_hashes block_hashes
    in
    let%bind `Existing existing_block_ids, `Missing missing_blocks =
      partition_existing
        ~get_key:(fun { state_hash; _ } -> state_hash)
        ~load_index:
          (load_index
             (module State_hash)
             state_hash_typ ~table:table_name ~fields:[ "state_hash" ] )
        blocks
    in
    ( match Set.find external_block_hashes ~f:(Map.mem existing_block_ids) with
    | Some state_hash ->
        failwithf
          "Missing external dependency from batch: failed to find block with \
           state hash %s"
          (State_hash.to_base58_check state_hash)
          ()
    | None ->
        () ) ;
    let%bind external_block_ids =
      load_index
        (module State_hash)
        state_hash_typ
        (Set.to_list external_block_hashes)
        ~table:table_name ~fields:[ "state_hash" ]
    in

    let missing_block_staking_epochs =
      List.map missing_blocks ~f:(fun { staking_epoch_data; _ } ->
          staking_epoch_data )
    in
    let missing_block_next_epochs =
      List.map missing_blocks ~f:(fun { next_epoch_data; _ } -> next_epoch_data)
    in
    let all_missing_epochs =
      Staged.unstage
        (List.stable_dedup_staged ~compare:Mina_base.Epoch_data.compare)
        (missing_block_staking_epochs @ missing_block_next_epochs)
    in

    let missing_snarked_ledger_hashes =
      List.map missing_blocks ~f:(fun { snarked_ledger_hash; _ } ->
          snarked_ledger_hash )
    in
    let missing_epoch_ledger_hashes =
      List.map all_missing_epochs ~f:(fun { ledger = { hash; _ }; _ } -> hash)
    in
    let all_missing_ledger_hashes =
      Staged.unstage
        (List.stable_dedup_staged ~compare:Ledger_hash.compare)
        (missing_snarked_ledger_hashes @ missing_epoch_ledger_hashes)
    in

    (* TODO: move user_cmd and internal_cmd portions down directly into public_keys requirements (we don't need their account ids allocated) *)
    let missing_user_cmd_accounts =
      List.bind missing_blocks ~f:(fun { user_cmds; _ } ->
          List.bind user_cmds ~f:Extensional.User_command.accounts_referenced )
    in
    let missing_internal_cmd_accounts =
      List.bind missing_blocks ~f:(fun { internal_cmds; _ } ->
          List.map internal_cmds
            ~f:Extensional.Internal_command.account_referenced )
    in
    let missing_zkapp_cmd_accounts =
      List.bind missing_blocks ~f:(fun { zkapp_cmds; _ } ->
          List.bind zkapp_cmds ~f:Extensional.Zkapp_command.accounts_referenced )
    in
    let all_missing_accounts =
      Staged.unstage
        (List.stable_dedup_staged ~compare:Account_id.compare)
        ( missing_user_cmd_accounts @ missing_internal_cmd_accounts
        @ missing_zkapp_cmd_accounts )
    in

    (* TODO *)
    let all_missing_tokens = [ Token_id.default ] in

    let missing_block_creators =
      List.map missing_blocks ~f:(fun { creator; _ } -> creator)
    in
    let missing_block_winners =
      List.map missing_blocks ~f:(fun { block_winner; _ } -> block_winner)
    in
    let missing_account_keys =
      List.map all_missing_accounts ~f:Account_id.public_key
    in
    let all_missing_public_keys =
      Staged.unstage
        (List.stable_dedup_staged
           ~compare:Signature_lib.Public_key.Compressed.compare )
        (missing_block_creators @ missing_block_winners @ missing_account_keys)
    in

    let%bind public_key_ids =
      differential_insert
        (module Signature_lib.Public_key.Compressed)
        all_missing_public_keys ~get_key:Fn.id ~get_value:Fn.id
        ~load_index:
          (load_index
             (module Signature_lib.Public_key.Compressed)
             public_key_typ ~table:"public_keys" ~fields:[ "value" (* TODO *) ] )
        ~insert_values:
          (bulk_insert public_key_typ ~table:"public_keys"
             ~fields:[ "value" (* TODO *) ] )
    in
    let%bind ledger_hash_ids =
      differential_insert
        (module Ledger_hash)
        all_missing_ledger_hashes ~get_key:Fn.id ~get_value:Fn.id
        ~load_index:
          (load_index
             (module Ledger_hash)
             ledger_hash_typ ~table:"snarked_ledger_hashes"
             ~fields:[ "value" (* TODO *) ] )
        ~insert_values:
          (bulk_insert ledger_hash_typ ~table:"snarked_ledger_hashes"
             ~fields:[ "value" (* TODO *) ] )
    in
    let%bind epoch_ids =
      let all_missing_epoch_reprs =
        List.map all_missing_epochs
          ~f:
            (epoch_data_to_repr
               ~find_ledger_hash_id:(Map.find_exn ledger_hash_ids) )
      in
      (* TODO: avoid this silly repr type in between, just go directly to and from Mina_base.Epoch_data *)
      differential_insert
        (module Epoch_data)
        all_missing_epoch_reprs ~get_key:Fn.id ~get_value:Fn.id
        ~load_index:
          (load_index
             (module Epoch_data)
             Epoch_data.typ ~table:Epoch_data.table_name
             ~fields:Epoch_data.Fields.names )
        ~insert_values:
          (bulk_insert Epoch_data.typ ~table:Epoch_data.table_name
             ~fields:Epoch_data.Fields.names )
    in
    let%bind _token_ids =
      let tokens =
        List.map all_missing_tokens ~f:(fun token ->
            (token, token_id_to_repr token) )
      in
      let%map token_repr_ids =
        differential_insert
          (module Token)
          tokens ~get_key:snd ~get_value:snd
          ~load_index:
            (load_index
               (module Token)
               Token.typ ~table:Token.table_name ~fields:Token.Fields.names )
          ~insert_values:
            (bulk_insert Token.typ ~table:Token.table_name
               ~fields:Token.Fields.names )
      in
      Token_id.Map.of_alist_exn
      @@ List.map tokens ~f:(fun (token, token_repr) ->
             (token, Map.find_exn token_repr_ids token_repr) )
    in

    (* We only expect a single protocol version at any migration, so we use the old non-batched functions here (which already cache ids) *)
    let all_protocol_versions =
      Staged.unstage
        (List.stable_dedup_staged ~compare:Protocol_version.compare)
        (List.map blocks ~f:(fun block -> block.protocol_version))
    in
    let%bind protocol_version_ids =
      Mina_stdlib.Deferred.Result.List.fold all_protocol_versions
        ~init:Protocol_version.Map.empty ~f:(fun acc version ->
          let transaction = Protocol_version.transaction version in
          let network = Protocol_version.network version in
          let patch = Protocol_version.patch version in
          let%map id =
            Protocol_versions.add_if_doesn't_exist
              (module Conn)
              ~transaction ~network ~patch
          in
          Map.add_exn acc ~key:version ~data:id )
    in

    (* pre-allocate some block rows for missing blocks so that we can resolve references between blocks *)
    (* TODO: share insert-and-index code with other functions *)
    let%bind new_block_ids =
      let partial_missing_blocks =
        List.map missing_blocks ~f:(fun block ->
            let last_vrf_output =
              (* encode as base64, same as in precomputed blocks JSON *)
              block.last_vrf_output
              |> Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet
            in
            { state_hash = block.state_hash |> State_hash.to_base58_check
            ; parent_id =
                None (* NB: this field gets filled in after this step *)
            ; parent_hash = block.parent_hash |> State_hash.to_base58_check
            ; creator_id = Map.find_exn public_key_ids block.creator
            ; block_winner_id = Map.find_exn public_key_ids block.block_winner
            ; last_vrf_output
            ; snarked_ledger_hash_id =
                Map.find_exn ledger_hash_ids block.snarked_ledger_hash
            ; staking_epoch_data_id =
                Map.find_exn epoch_ids
                  (epoch_data_to_repr block.staking_epoch_data
                     ~find_ledger_hash_id:(Map.find_exn ledger_hash_ids) )
            ; next_epoch_data_id =
                Map.find_exn epoch_ids
                  (epoch_data_to_repr block.next_epoch_data
                     ~find_ledger_hash_id:(Map.find_exn ledger_hash_ids) )
            ; min_window_density =
                block.min_window_density |> Mina_numbers.Length.to_uint32
                |> Unsigned.UInt32.to_int64
            ; sub_window_densities =
                block.sub_window_densities
                |> List.map ~f:(fun length ->
                       Mina_numbers.Length.to_uint32 length
                       |> Unsigned.UInt32.to_int64 )
                |> Array.of_list
            ; total_currency = Currency.Amount.to_string block.total_currency
            ; ledger_hash = block.ledger_hash |> Ledger_hash.to_base58_check
            ; height = block.height |> Unsigned.UInt32.to_int64
            ; global_slot_since_hard_fork =
                block.global_slot_since_hard_fork
                |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
                |> Unsigned.UInt32.to_int64
            ; global_slot_since_genesis =
                block.global_slot_since_genesis
                |> Mina_numbers.Global_slot_since_genesis.to_uint32
                |> Unsigned.UInt32.to_int64
            ; protocol_version_id =
                Map.find_exn protocol_version_ids block.protocol_version
            ; proposed_protocol_version_id =
                Option.map block.proposed_protocol_version
                  ~f:(Map.find_exn protocol_version_ids)
            ; timestamp = Block_time.to_string_exn block.timestamp
            ; chain_status = Chain_status.to_string block.chain_status
            } )
      in
      let%map ids =
        bulk_insert typ partial_missing_blocks ~table:table_name
          ~fields:Fields.names
      in
      State_hash.Map.of_alist_exn
      @@ List.zip_exn
           (List.map missing_blocks ~f:(fun { state_hash; _ } -> state_hash))
           ids
    in
    let block_ids =
      let check_conflict ~key:_ conflict =
        match conflict with
        | `Both _ ->
            failwith "duplicate data loaded during differential insertion"
        | `Left x | `Right x ->
            Some x
      in
      Map.merge existing_block_ids new_block_ids ~f:check_conflict
      |> Map.merge external_block_ids ~f:check_conflict
    in
    let%bind () =
      (* filter out direct descendants of the genesis block, as those maintain the NULL parent reference *)
      let ids, parent_ids =
        missing_blocks
        |> List.filter ~f:(fun block ->
               (*
            not (State_hash.equal block.parent_hash genesis_block_hash))
            *)
               Unsigned.UInt32.to_int block.height > 1 )
        |> List.map ~f:(fun block ->
               ( Int.to_string @@ Map.find_exn block_ids block.state_hash
               , Int.to_string @@ Map.find_exn block_ids block.parent_hash ) )
        |> List.unzip
      in
      let ids_sql = String.concat ~sep:"," ids in
      let parent_ids_sql = String.concat ~sep:"," parent_ids in
      Conn.exec
        (Caqti_request.exec Caqti_type.unit
           (sprintf
              "UPDATE %s AS b SET parent_id = data.parent_id FROM (SELECT \
               unnest(array[%s]) as id, unnest(array[%s]) as parent_id) AS \
               data WHERE b.id = data.id"
              table_name ids_sql parent_ids_sql ) )
        ()
    in

    let%bind user_cmd_ids =
      let compare_by_hash (a : User_command.Signed_command.t)
          (b : User_command.Signed_command.t) =
        String.compare a.hash b.hash
      in
      List.bind missing_blocks ~f:(fun block ->
          List.map
            ~f:
              (user_cmd_to_repr
                 ~find_public_key_id:(Map.find_exn public_key_ids) )
            block.user_cmds )
      |> Staged.unstage (List.stable_dedup_staged ~compare:compare_by_hash)
      |> differential_insert
           (module String)
           ~get_key:(fun { hash; _ } -> hash)
           ~get_value:Fn.id
           ~load_index:
             (load_index
                (module String)
                Caqti_type.string ~table:User_command.Signed_command.table_name
                ~fields:[ "hash" ] )
           ~insert_values:
             (bulk_insert User_command.Signed_command.typ
                ~table:User_command.Signed_command.table_name
                ~fields:User_command.Signed_command.Fields.names )
    in
    let%bind () =
      let joins =
        List.bind missing_blocks ~f:(fun block ->
            List.map block.user_cmds
              ~f:(fun { sequence_no; hash; status; failure_reason; _ } ->
                { Block_and_signed_command.block_id =
                    Map.find_exn block_ids block.state_hash
                ; user_command_id =
                    Map.find_exn user_cmd_ids
                      (txn_hash_to_base58_check ~v1_transaction_hash hash)
                ; sequence_no
                ; status
                ; failure_reason =
                    Option.map ~f:Transaction_status.Failure.to_string
                      failure_reason
                } ) )
      in
      Conn.populate Block_and_signed_command.typ
        (Caqti_async.Stream.of_list joins)
        ~table:Block_and_signed_command.table_name
        ~columns:Block_and_signed_command.Fields.names
    in

    let module Internal_command_primary_key = struct
      module T = struct
        type t = { hash : string; command_type : string }
        [@@deriving compare, fields, hlist, sexp]
      end

      include T
      include Comparable.Make (T)

      let typ =
        let command_type =
          let encode = Fn.id in
          let decode = Result.return in
          Caqti_type.enum ~encode ~decode "internal_command_type"
        in
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.[ string; command_type ]

      let of_command : Internal_command.t -> t =
       fun { hash; command_type; _ } -> { hash; command_type }
    end in
    let%bind internal_cmd_ids =
      let compare_by_primary_key (a : Internal_command.t)
          (b : Internal_command.t) =
        Internal_command_primary_key.compare
          (Internal_command_primary_key.of_command a)
          (Internal_command_primary_key.of_command b)
      in
      List.bind missing_blocks ~f:(fun block ->
          List.map
            ~f:
              (internal_cmd_to_repr
                 ~find_public_key_id:(Map.find_exn public_key_ids) )
            block.internal_cmds )
      |> Staged.unstage
           (List.stable_dedup_staged ~compare:compare_by_primary_key)
      |> differential_insert
           (module Internal_command_primary_key)
           ~get_key:Internal_command_primary_key.of_command ~get_value:Fn.id
           ~load_index:
             (load_index
                (module Internal_command_primary_key)
                Internal_command_primary_key.typ
                ~table:Internal_command.table_name
                ~fields:Internal_command_primary_key.Fields.names )
           ~insert_values:
             (bulk_insert Internal_command.typ
                ~table:Internal_command.table_name
                ~fields:Internal_command.Fields.names )
    in
    let%bind () =
      let joins =
        List.bind missing_blocks ~f:(fun block ->
            List.map block.internal_cmds
              ~f:(fun
                   { hash
                   ; sequence_no
                   ; secondary_sequence_no
                   ; status
                   ; failure_reason
                   ; command_type
                   ; fee = _
                   ; receiver = _
                   }
                 ->
                { Block_and_internal_command.block_id =
                    Map.find_exn block_ids block.state_hash
                ; internal_command_id =
                    Map.find_exn internal_cmd_ids
                      { hash =
                          txn_hash_to_base58_check ~v1_transaction_hash hash
                      ; command_type
                      }
                ; sequence_no
                ; secondary_sequence_no
                ; status
                ; failure_reason =
                    Option.map ~f:Transaction_status.Failure.to_string
                      failure_reason
                } ) )
      in
      Conn.populate Block_and_internal_command.typ
        (Caqti_async.Stream.of_list joins)
        ~table:Block_and_internal_command.table_name
        ~columns:Block_and_internal_command.Fields.names
    in

    (* TODO: currently unsupported *)
    assert (List.for_all blocks ~f:(fun block -> List.is_empty block.zkapp_cmds)) ;
    let _zkapp_cmd_ids = () in

    return ()

  let add_from_extensional (module Conn : CONNECTION)
      ?(v1_transaction_hash = false) (block : Extensional.Block.t) =
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
          let last_vrf_output =
            (* encode as base64, same as in precomputed blocks JSON *)
            block.last_vrf_output
            |> Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet
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
          let%bind protocol_version_id =
            let transaction =
              Protocol_version.transaction block.protocol_version
            in
            let network = Protocol_version.network block.protocol_version in
            let patch = Protocol_version.patch block.protocol_version in
            Protocol_versions.add_if_doesn't_exist
              (module Conn)
              ~transaction ~network ~patch
          in
          let%bind proposed_protocol_version_id =
            Option.value_map block.proposed_protocol_version
              ~default:(return None) ~f:(fun ppv ->
                let transaction = Protocol_version.transaction ppv in
                let network = Protocol_version.network ppv in
                let patch = Protocol_version.patch ppv in
                let%map id =
                  Protocol_versions.add_if_doesn't_exist
                    (module Conn)
                    ~transaction ~network ~patch
                in
                Some id )
          in
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               (Mina_caqti.insert_into_cols ~returning:"id" ~table_name
                  ~tannot:(function
                    | "sub_window_densities" ->
                        Some "bigint[]"
                    | "chain_status" ->
                        Some "chain_status_type"
                    | _ ->
                        None )
                  ~cols:Fields.names () ) )
            { state_hash = block.state_hash |> State_hash.to_base58_check
            ; parent_id
            ; parent_hash = block.parent_hash |> State_hash.to_base58_check
            ; creator_id
            ; block_winner_id
            ; last_vrf_output
            ; snarked_ledger_hash_id
            ; staking_epoch_data_id
            ; next_epoch_data_id
            ; min_window_density =
                block.min_window_density |> Mina_numbers.Length.to_uint32
                |> Unsigned.UInt32.to_int64
            ; sub_window_densities =
                block.sub_window_densities
                |> List.map ~f:(fun length ->
                       Mina_numbers.Length.to_uint32 length
                       |> Unsigned.UInt32.to_int64 )
                |> Array.of_list
            ; total_currency = Currency.Amount.to_string block.total_currency
            ; ledger_hash = block.ledger_hash |> Ledger_hash.to_base58_check
            ; height = block.height |> Unsigned.UInt32.to_int64
            ; global_slot_since_hard_fork =
                block.global_slot_since_hard_fork
                |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
                |> Unsigned.UInt32.to_int64
            ; global_slot_since_genesis =
                block.global_slot_since_genesis
                |> Mina_numbers.Global_slot_since_genesis.to_uint32
                |> Unsigned.UInt32.to_int64
            ; protocol_version_id
            ; proposed_protocol_version_id
            ; timestamp = Block_time.to_string_exn block.timestamp
            ; chain_status = Chain_status.to_string block.chain_status
            }
    in
    (* add user commands *)
    let%bind user_cmds_with_ids =
      let%map user_cmd_ids_rev =
        Mina_caqti.deferred_result_list_fold block.user_cmds ~init:[]
          ~f:(fun acc user_cmd ->
            let%map cmd_id =
              User_command.Signed_command.add_extensional_if_doesn't_exist
                (module Conn)
                user_cmd ~v1_transaction_hash
            in
            cmd_id :: acc )
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
            ~failure_reason:user_command.failure_reason )
    in
    (* add internal commands *)
    let%bind internal_cmds_ids_and_seq_nos =
      let%map internal_cmds_and_ids_rev =
        Mina_caqti.deferred_result_list_fold block.internal_cmds ~init:[]
          ~f:(fun acc internal_cmd ->
            let%map cmd_id =
              Internal_command.add_extensional_if_doesn't_exist
                (module Conn)
                internal_cmd ~v1_transaction_hash
            in
            (internal_cmd, cmd_id) :: acc )
      in
      let sequence_nos =
        List.map block.internal_cmds ~f:(fun internal_cmd ->
            (internal_cmd.sequence_no, internal_cmd.secondary_sequence_no) )
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
          Block_and_internal_command.add_if_doesn't_exist
            (module Conn)
            ~block_id ~internal_command_id ~sequence_no ~secondary_sequence_no
            ~status:internal_command.status
            ~failure_reason:internal_command.failure_reason )
    in
    (* add zkApp commands *)
    let%bind zkapp_cmds_ids_and_seq_nos =
      let%map zkapp_cmds_and_ids_rev =
        Mina_caqti.deferred_result_list_fold block.zkapp_cmds ~init:[]
          ~f:(fun acc ({ fee_payer; account_updates; memo; _ } as zkapp_cmd) ->
            (* add authorizations, not stored in the db *)
            let (fee_payer : Account_update.Fee_payer.t) =
              { body = fee_payer; authorization = Signature.dummy }
            in
            let (account_updates : Account_update.Simple.t list) =
              List.map account_updates
                ~f:(fun
                     (body : Account_update.Body.Simple.t)
                     :
                     Account_update.Simple.t
                   -> { body; authorization = None_given } )
            in
            let%map cmd_id =
              User_command.Zkapp_command.add_if_doesn't_exist
                (module Conn)
                (Zkapp_command.of_simple { fee_payer; account_updates; memo })
            in
            (zkapp_cmd, cmd_id) :: acc )
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
          () )
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
         |sql} )
      (parent_id, State_hash.to_base58_check parent_hash)

  let get_subchain (module Conn : CONNECTION) ~start_block_id ~end_block_id =
    (* derive query from type `t` *)
    let concat = String.concat ~sep:"," in
    let columns_with_id = concat ("id" :: Fields.names) in
    let b_columns_with_id =
      concat (List.map ("id" :: Fields.names) ~f:(fun s -> "b." ^ s))
    in
    let columns = concat Fields.names in
    Conn.collect_list
      (Caqti_request.collect
         Caqti_type.(tup2 int int)
         typ
         (sprintf
            {sql| WITH RECURSIVE chain AS (
              SELECT %s
              FROM blocks b WHERE b.id = $1

              UNION ALL

              SELECT %s
              FROM blocks b

              INNER JOIN chain

              ON b.id = chain.parent_id AND (chain.id <> $2 OR b.id = $2)

           )

           SELECT %s
           FROM chain ORDER BY height ASC
         |sql}
            columns_with_id b_columns_with_id columns ) )
      (end_block_id, start_block_id)

  let get_highest_canonical_block_opt (module Conn : CONNECTION) =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.unit
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' ORDER BY \
          height DESC LIMIT 1" )

  let get_nearest_canonical_block_above (module Conn : CONNECTION) height =
    Conn.find
      (Caqti_request.find Caqti_type.int64
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' AND \
          height > ? ORDER BY height ASC LIMIT 1" )
      height

  let get_nearest_canonical_block_below (module Conn : CONNECTION) height =
    Conn.find
      (Caqti_request.find Caqti_type.int64
         Caqti_type.(tup2 int int64)
         "SELECT id,height FROM blocks WHERE chain_status='canonical' AND \
          height < ? ORDER BY height DESC LIMIT 1" )
      height

  let mark_as_canonical (module Conn : CONNECTION) ~state_hash =
    Conn.exec
      (Caqti_request.exec Caqti_type.string
         "UPDATE blocks SET chain_status='canonical' WHERE state_hash = ?" )
      state_hash

  let mark_as_orphaned (module Conn : CONNECTION) ~state_hash ~height =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 string int64)
         {sql| UPDATE blocks SET chain_status='orphaned'
               WHERE height = $2
               AND state_hash <> $1
         |sql} )
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
            Metrics.time ~label:"get_subchain (> canonical_height + k)"
              (fun () ->
                get_subchain
                  (module Conn)
                  ~start_block_id:highest_canonical_block_id
                  ~end_block_id:block_id )
          in
          let block_height_less_k_int64 = Int64.( - ) block.height k_int64 in
          (* mark canonical, orphaned blocks in subchain at least k behind the new block *)
          let canonical_blocks =
            List.filter subchain_blocks ~f:(fun subchain_block ->
                Int64.( <= ) subchain_block.height block_height_less_k_int64 )
          in
          Metrics.time ~label:"mark_as_canonical (> canonical_height + k)"
            (fun () ->
              Mina_caqti.deferred_result_list_fold canonical_blocks ~init:()
                ~f:(fun () block ->
                  let%bind () =
                    mark_as_canonical (module Conn) ~state_hash:block.state_hash
                  in
                  mark_as_orphaned
                    (module Conn)
                    ~state_hash:block.state_hash ~height:block.height ) )
        else if Int64.( < ) block.height greatest_canonical_height then
          (* a missing block added in the middle of canonical chain *)
          let%bind canonical_block_above_id, _above_height =
            Metrics.time ~label:"get_nearest_canonical_block_above" (fun () ->
                get_nearest_canonical_block_above (module Conn) block.height )
          in
          let%bind canonical_block_below_id, _below_height =
            Metrics.time ~label:"get_neareast_canonical_block_below" (fun () ->
                get_nearest_canonical_block_below (module Conn) block.height )
          in
          (* we can always find this chain: the genesis block should be marked as canonical, and we've found a
             canonical block above this one *)
          let%bind canonical_blocks =
            Metrics.time ~label:"get_subchain (< canonical_height)" (fun () ->
                get_subchain
                  (module Conn)
                  ~start_block_id:canonical_block_below_id
                  ~end_block_id:canonical_block_above_id )
          in
          Metrics.time ~label:"mark_as_canonical (< canonical_height)"
            (fun () ->
              Mina_caqti.deferred_result_list_fold canonical_blocks ~init:()
                ~f:(fun () block ->
                  let%bind () =
                    mark_as_canonical (module Conn) ~state_hash:block.state_hash
                  in
                  mark_as_orphaned
                    (module Conn)
                    ~state_hash:block.state_hash ~height:block.height ) )
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
                 "SELECT MAX(height) FROM blocks" )
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
              WHERE (blocks.height < ? OR blocks.timestamp < ?))" )
          (height, timestamp)
      in
      let%bind () =
        (* Delete old blocks. *)
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(tup2 int int64)
             "DELETE FROM blocks WHERE blocks.height < ? OR blocks.timestamp < \
              ?" )
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
              internal_command_id = internal_commands.id)" )
          ()
      in
      let%bind () =
        (* Delete orphaned snarked ledger hashes. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM snarked_ledger_hashes\n\
              WHERE id NOT IN\n\
              (SELECT snarked_ledger_hash_id FROM blocks)" )
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
              AND id NOT IN (SELECT creator_id FROM blocks)" )
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
    ~delete_older_than ~accounts_accessed ~accounts_created ~tokens_used block =
  let state_hash = hash block in

  (* the block itself is added in a single transaction with a transaction block

     once that transaction is committed, we can get a block id

     so we add accounts accessed, accounts created, contained in another
     transaction block
  *)
  let add () =
    [%log info]
      "Populating token owners table for block with state hash $state_hash"
      ~metadata:[ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ] ;
    List.iter tokens_used ~f:(fun (token_id, owner) ->
        match owner with
        | None ->
            ()
        | Some acct_id ->
            Token_owners.add_if_doesn't_exist token_id acct_id ) ;
    Caqti_async.Pool.use
      (fun (module Conn : CONNECTION) ->
        let%bind res =
          let open Deferred.Result.Let_syntax in
          let%bind () = Conn.start () in
          [%log info] "Attempting to add block data for $state_hash"
            ~metadata:
              [ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ] ;
          let%bind block_id =
            O1trace.thread "archive_processor.add_block"
            @@ fun () ->
            Metrics.time ~label:"add_block"
            @@ fun () -> add_block (module Conn : CONNECTION) block
          in
          (* if an existing block has a parent hash that's for the block just added,
             set its parent id
          *)
          let%bind () =
            Block.set_parent_id_if_null
              (module Conn)
              ~parent_hash:(hash block) ~parent_id:block_id
          in
          (* update chain status for existing blocks *)
          let%bind () =
            Metrics.time ~label:"update_chain_status" (fun () ->
                Block.update_chain_status (module Conn) ~block_id )
          in
          let%bind () =
            match delete_older_than with
            | Some num_blocks ->
                Block.delete_if_older_than ~num_blocks (module Conn)
            | None ->
                return ()
          in
          return block_id
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
        | Ok block_id -> (
            match%bind Conn.commit () with
            | Error err ->
                [%log warn]
                  "Could not commit data for block with state hash \
                   $state_hash, rolling back transaction: $error"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson state_hash)
                    ; ("error", `String (Caqti_error.show err))
                    ] ;
                Conn.rollback ()
            | Ok () -> (
                (* added block data, now add accounts accessed *)
                [%log info]
                  "Added block with state hash $state_hash to archive database"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson state_hash)
                    ; ( "num_accounts_accessed"
                      , `Int (List.length accounts_accessed) )
                    ] ;
                let%bind.Deferred.Result () = Conn.start () in
                match%bind
                  Caqti_async.Pool.use
                    (fun (module Conn : CONNECTION) ->
                      Accounts_accessed.add_accounts_if_don't_exist
                        (module Conn)
                        block_id accounts_accessed )
                    pool
                with
                | Error err ->
                    [%log error]
                      "Could not add accounts accessed in block with state \
                       hash $state_hash to archive database: $error"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ("error", `String (Caqti_error.show err))
                        ] ;
                    Conn.rollback ()
                | Ok _block_and_account_ids -> (
                    [%log info]
                      "Added accounts accessed for block with state hash \
                       $state_hash to archive database"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ( "num_accounts_accessed"
                          , `Int (List.length accounts_accessed) )
                        ] ;
                    match%bind
                      Caqti_async.Pool.use
                        (fun (module Conn : CONNECTION) ->
                          Accounts_created.add_accounts_created_if_don't_exist
                            (module Conn)
                            block_id accounts_created )
                        pool
                    with
                    | Ok _block_and_public_key_ids ->
                        [%log info]
                          "Added accounts created for block with state hash \
                           $state_hash to archive database"
                          ~metadata:
                            [ ( "state_hash"
                              , Mina_base.State_hash.to_yojson (hash block) )
                            ; ( "num_accounts_created"
                              , `Int (List.length accounts_created) )
                            ] ;
                        Conn.commit ()
                    | Error err ->
                        [%log warn]
                          "Could not add accounts created in block with state \
                           hash $state_hash to archive database: $error"
                          ~metadata:
                            [ ("state_hash", State_hash.to_yojson state_hash)
                            ; ("error", `String (Caqti_error.show err))
                            ] ;

                        Conn.rollback () ) ) ) )
      pool
  in
  retry ~f:add ~logger ~error_str:"add_block_aux" retries

(* used by `archive_blocks` app *)
let add_block_aux_precomputed ~constraint_constants ~logger ?retries ~pool
    ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:(Block.add_from_precomputed ~constraint_constants)
    ~hash:(fun block ->
      (block.Precomputed.protocol_state |> Protocol_state.hashes).state_hash )
    ~accounts_accessed:block.Precomputed.accounts_accessed
    ~accounts_created:block.Precomputed.accounts_created
    ~tokens_used:block.Precomputed.tokens_used block

(* used by `archive_blocks` app *)
let add_block_aux_extensional ~logger ?retries ~pool ~delete_older_than block =
  add_block_aux ~logger ?retries ~pool ~delete_older_than
    ~add_block:(Block.add_from_extensional ~v1_transaction_hash:false)
    ~hash:(fun (block : Extensional.Block.t) -> block.state_hash)
    ~accounts_accessed:block.Extensional.Block.accounts_accessed
    ~accounts_created:block.Extensional.Block.accounts_created
    ~tokens_used:block.Extensional.Block.tokens_used block

(* receive blocks from a daemon, write them to the database *)
let run pool reader ~constraint_constants ~logger ~delete_older_than :
    unit Deferred.t =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier
        (Breadcrumb_added
          { block; accounts_accessed; accounts_created; tokens_used; _ } ) -> (
        let add_block = Block.add_if_doesn't_exist ~constraint_constants in
        let hash = State_hash.With_state_hashes.state_hash in
        match%bind
          add_block_aux ~logger ~pool ~delete_older_than ~hash ~add_block
            ~accounts_accessed ~accounts_created ~tokens_used block
        with
        | Error e ->
            let state_hash = hash block in
            [%log warn]
              ~metadata:
                [ ("state_hash", State_hash.to_yojson state_hash)
                ; ("error", `String (Caqti_error.show e))
                ]
              "Failed to archive block with state hash $state_hash, see $error" ;
            Deferred.unit
        | Ok () ->
            Deferred.unit )
    | Transition_frontier _ ->
        Deferred.unit )

(* [add_genesis_accounts] is called when starting the archive process *)
let add_genesis_accounts ~logger ~(runtime_config_opt : Runtime_config.t option)
    pool =
  match runtime_config_opt with
  | None ->
      Deferred.unit
  | Some runtime_config -> (
      match runtime_config.ledger with
      | None ->
          [%log fatal] "Runtime config does not contain a ledger" ;
          failwith
            "Runtime config does not contain a ledger, could not add genesis \
             accounts"
      | Some runtime_config_ledger -> (
          let proof_level = Genesis_constants.Proof_level.compiled in
          let%bind precomputed_values =
            match%map
              Genesis_ledger_helper.init_from_config_file ~logger
                ~proof_level:(Some proof_level) runtime_config
            with
            | Ok (precomputed_values, _) ->
                precomputed_values
            | Error err ->
                failwithf "Could not get precomputed values, error: %s"
                  (Error.to_string_hum err) ()
          in
          (* code modeled on replayer ledger initialization *)
          let%bind padded_accounts =
            match
              Genesis_ledger_helper.Ledger
              .padded_accounts_from_runtime_config_opt ~logger ~proof_level
                runtime_config_ledger ~ledger_name_prefix:"genesis_ledger"
            with
            | None ->
                [%log fatal]
                  "Could not load accounts from runtime config ledger" ;
                exit 1
            | Some accounts ->
                return accounts
          in
          let constraint_constants =
            Genesis_constants.Constraint_constants.compiled
          in
          let packed_ledger =
            Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
              ~depth:constraint_constants.ledger_depth padded_accounts
          in
          let ledger = Lazy.force @@ Genesis_ledger.Packed.t packed_ledger in
          let%bind account_ids =
            let%map account_id_set = Mina_ledger.Ledger.accounts ledger in
            Account_id.Set.to_list account_id_set
          in
          let genesis_block =
            let With_hash.{ data = block; hash = the_hash }, _ =
              Mina_block.genesis ~precomputed_values
            in
            With_hash.{ data = block; hash = the_hash }
          in
          let add_accounts () =
            Caqti_async.Pool.use
              (fun (module Conn : CONNECTION) ->
                let%bind.Deferred.Result genesis_block_id =
                  Block.add_if_doesn't_exist
                    (module Conn)
                    ~constraint_constants genesis_block
                in
                let%bind.Deferred.Result { ledger_hash; _ } =
                  Block.load (module Conn) ~id:genesis_block_id
                in
                let db_ledger_hash =
                  Ledger_hash.of_base58_check_exn ledger_hash
                in
                let actual_ledger_hash =
                  Mina_ledger.Ledger.merkle_root ledger
                in
                if Ledger_hash.equal db_ledger_hash actual_ledger_hash then
                  [%log info]
                    "Archived genesis block ledger hash equals actual genesis \
                     ledger hash"
                    ~metadata:
                      [ ("ledger_hash", Ledger_hash.to_yojson actual_ledger_hash)
                      ]
                else (
                  [%log error]
                    "Archived genesis block ledger hash different than actual \
                     genesis ledger hash"
                    ~metadata:
                      [ ( "archived_ledger_hash"
                        , Ledger_hash.to_yojson db_ledger_hash )
                      ; ( "actual_ledger_hash"
                        , Ledger_hash.to_yojson actual_ledger_hash )
                      ] ;
                  exit 1 ) ;
                let%bind.Deferred.Result () = Conn.start () in
                let open Deferred.Let_syntax in
                let%bind () =
                  Deferred.List.iter account_ids ~f:(fun acct_id ->
                      match
                        Mina_ledger.Ledger.location_of_account ledger acct_id
                      with
                      | None ->
                          [%log error] "Could not get location for account"
                            ~metadata:
                              [ ("account_id", Account_id.to_yojson acct_id) ] ;
                          failwith "Could not get location for genesis account"
                      | Some loc -> (
                          let index =
                            Mina_ledger.Ledger.index_of_account_exn ledger
                              acct_id
                          in
                          let acct =
                            match Mina_ledger.Ledger.get ledger loc with
                            | None ->
                                [%log error]
                                  "Could not get account, given a location"
                                  ~metadata:
                                    [ ( "account_id"
                                      , Account_id.to_yojson acct_id )
                                    ] ;
                                failwith
                                  "Could not get genesis account, given a \
                                   location"
                            | Some acct ->
                                acct
                          in
                          match%bind
                            Accounts_accessed.add_if_doesn't_exist
                              (module Conn)
                              genesis_block_id (index, acct)
                          with
                          | Ok _ ->
                              return ()
                          | Error err ->
                              [%log error] "Could not add genesis account"
                                ~metadata:
                                  [ ("account_id", Account_id.to_yojson acct_id)
                                  ; ("error", `String (Caqti_error.show err))
                                  ] ;
                              failwith "Could not add add genesis account" ) )
                in
                Conn.commit () )
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
              () ) )

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

(* for running the archive process *)
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
          Strict_pipe.Writer.write writer archive_diff )
    ; Async.Rpc.Rpc.implement Archive_rpc.precomputed_block
        (fun () precomputed_block ->
          Strict_pipe.Writer.write precomputed_block_writer precomputed_block )
    ; Async.Rpc.Rpc.implement Archive_rpc.extensional_block
        (fun () extensional_block ->
          Strict_pipe.Writer.write extensional_block_writer extensional_block )
    ]
  in
  match Caqti_async.connect_pool ~max_size:30 postgres_address with
  | Error e ->
      [%log error]
        "Failed to create a Caqti pool for Postgresql, see error: $error"
        ~metadata:[ ("error", `String (Caqti_error.show e)) ] ;
      Deferred.unit
  | Ok pool ->
      [%log info]
        "Starting archive process; built with commit $commit on branch $branch"
        ~metadata:
          [ ("commit", `String Mina_version.commit_id)
          ; ("branch", `String Mina_version.branch)
          ; ("commit_date", `String Mina_version.commit_date)
          ] ;
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
              () )
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
              () )
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
                     ] ) )
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             Async.Rpc.Connection.server_with_close reader writer
               ~implementations:
                 (Async.Rpc.Implementations.create_exn ~implementations
                    ~on_unknown_rpc:`Raise )
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
                     Deferred.unit ) ) )
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
