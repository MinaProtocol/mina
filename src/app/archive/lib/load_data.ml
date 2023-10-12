(* load_data.ml -- load archive db data to "native" OCaml data *)

open Core_kernel
open Async
open Mina_base

let pk_of_id pool pk_id =
  let%map pk_str =
    Mina_caqti.query pool ~f:(fun db ->
        Processor.Public_key.find_by_id db pk_id )
  in
  Signature_lib.Public_key.Compressed.of_base58_check_exn pk_str

let token_of_id pool token_id =
  let%map { value; _ } =
    Mina_caqti.query pool ~f:(fun db -> Processor.Token.find_by_id db token_id)
  in
  Token_id.of_string value

let account_identifier_of_id pool account_identifier_id =
  let%bind { public_key_id; token_id } =
    Mina_caqti.query pool ~f:(fun db ->
        Processor.Account_identifiers.load db account_identifier_id )
  in
  let%bind pk = pk_of_id pool public_key_id in
  let%map token = token_of_id pool token_id in
  Account_id.create pk token

let get_amount_bounds pool amount_id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let%map amount_db_opt =
    Option.value_map amount_id ~default:(return None) ~f:(fun id ->
        let%map amount =
          query_db ~f:(fun db -> Processor.Zkapp_amount_bounds.load db id)
        in
        Some amount )
  in
  let amount_opt =
    Option.map amount_db_opt
      ~f:(fun { amount_lower_bound; amount_upper_bound } ->
        let lower = Currency.Amount.of_string amount_lower_bound in
        let upper = Currency.Amount.of_string amount_upper_bound in
        ( { lower; upper }
          : Currency.Amount.t Zkapp_precondition.Closed_interval.t ) )
  in
  Or_ignore.of_option amount_opt

let get_global_slot_bounds pool id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let%map bounds_opt =
    Option.value_map id ~default:(return None) ~f:(fun id ->
        let%map bounds =
          query_db ~f:(fun db -> Processor.Zkapp_global_slot_bounds.load db id)
        in
        let slot_of_int64 int64 =
          int64 |> Unsigned.UInt32.of_int64
          |> Mina_numbers.Global_slot_since_genesis.of_uint32
        in
        let lower = slot_of_int64 bounds.global_slot_lower_bound in
        let upper = slot_of_int64 bounds.global_slot_upper_bound in
        Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t) )
  in
  Or_ignore.of_option bounds_opt

let get_length_bounds pool id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let%map bl_db_opt =
    Option.value_map id ~default:(return None) ~f:(fun id ->
        let%map ts =
          query_db ~f:(fun db -> Processor.Zkapp_length_bounds.load db id)
        in
        Some ts )
  in
  let bl_opt =
    Option.map bl_db_opt ~f:(fun { length_lower_bound; length_upper_bound } ->
        let lower = Unsigned.UInt32.of_int64 length_lower_bound in
        let upper = Unsigned.UInt32.of_int64 length_upper_bound in
        ( { lower; upper }
          : Unsigned.UInt32.t Zkapp_precondition.Closed_interval.t ) )
  in
  Or_ignore.of_option bl_opt

let update_of_id pool update_id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let with_pool ~f arg =
    let open Caqti_async in
    Pool.use
      (fun (module Conn : CONNECTION) -> f (module Conn : CONNECTION) arg)
      pool
  in
  let%bind { app_state_id
           ; delegate_id
           ; verification_key_id
           ; permissions_id
           ; zkapp_uri_id
           ; token_symbol_id
           ; timing_id
           ; voting_for_id
           } =
    query_db ~f:(fun db -> Processor.Zkapp_updates.load db update_id)
  in
  let%bind app_state =
    let%bind { element0
             ; element1
             ; element2
             ; element3
             ; element4
             ; element5
             ; element6
             ; element7
             } =
      query_db ~f:(fun db ->
          Processor.Zkapp_states_nullable.load db app_state_id )
    in
    let field_ids =
      [ element0
      ; element1
      ; element2
      ; element3
      ; element4
      ; element5
      ; element6
      ; element7
      ]
    in
    let%map field_strs =
      Deferred.List.map field_ids ~f:(fun id_opt ->
          Option.value_map id_opt ~default:(return None) ~f:(fun id ->
              let%map field =
                query_db ~f:(fun db -> Processor.Zkapp_field.load db id)
              in
              Some field ) )
    in
    let fields =
      List.map field_strs ~f:(fun str_opt ->
          Option.value_map str_opt ~default:Set_or_keep.Keep ~f:(fun str ->
              Set_or_keep.Set (F.of_string str) ) )
    in
    Zkapp_state.V.of_list_exn fields
  in
  let%bind delegate =
    let%map pk_str =
      Mina_caqti.get_opt_item delegate_id
        ~f:(with_pool ~f:Processor.Public_key.find_by_id)
    in
    Option.map pk_str ~f:Signature_lib.Public_key.Compressed.of_base58_check_exn
    |> Set_or_keep.of_option
  in
  let%bind verification_key =
    let%bind vk_opt =
      Option.value_map verification_key_id ~default:(return None) ~f:(fun id ->
          let%map vk =
            query_db ~f:(fun db -> Processor.Zkapp_verification_keys.load db id)
          in
          Some vk )
    in
    match vk_opt with
    | None ->
        return Set_or_keep.Keep
    | Some { verification_key; hash_id } -> (
        match
          Pickles.Side_loaded.Verification_key.of_base64 verification_key
        with
        | Ok vk ->
            let data = vk in
            let%bind hash =
              let%map hash_str =
                query_db ~f:(fun db ->
                    Processor.Zkapp_verification_key_hashes.load db hash_id )
              in
              Pickles.Backend.Tick.Field.of_string hash_str
            in
            return @@ Set_or_keep.Set { With_hash.data; hash }
        | Error err ->
            failwithf "Could not Base64-decode verification key: %s"
              (Error.to_string_hum err) () )
  in
  let%bind permissions =
    let%map perms_opt =
      Option.value_map permissions_id ~default:(return None) ~f:(fun id ->
          let%bind { edit_state
                   ; send
                   ; receive
                   ; access
                   ; set_delegate
                   ; set_permissions
                   ; set_verification_key = verification_key_auth, version_id
                   ; set_zkapp_uri
                   ; edit_action_state
                   ; set_token_symbol
                   ; increment_nonce
                   ; set_voting_for
                   ; set_timing
                   } =
            query_db ~f:(fun db -> Processor.Zkapp_permissions.load db id)
          in
          let%map { transaction; network; patch } =
            query_db ~f:(fun db ->
                Processor.Protocol_versions.load db version_id )
          in
          (* same fields, different types *)
          Some
            ( { edit_state
              ; send
              ; receive
              ; access
              ; set_delegate
              ; set_permissions
              ; set_verification_key =
                  ( verification_key_auth
                  , Protocol_version.create ~transaction ~network ~patch )
              ; set_zkapp_uri
              ; edit_action_state
              ; set_token_symbol
              ; increment_nonce
              ; set_voting_for
              ; set_timing
              }
              : Permissions.t ) )
    in
    Set_or_keep.of_option perms_opt
  in
  let%bind zkapp_uri =
    Mina_caqti.get_zkapp_set_or_keep zkapp_uri_id
      ~f:(with_pool ~f:Processor.Zkapp_uri.load)
  in
  let%bind token_symbol =
    Mina_caqti.get_zkapp_set_or_keep token_symbol_id
      ~f:(with_pool ~f:Processor.Token_symbols.load)
  in
  let%bind timing =
    let%map tm_opt =
      Option.value_map timing_id ~default:(return None) ~f:(fun id ->
          let%map { initial_minimum_balance
                  ; cliff_time
                  ; cliff_amount
                  ; vesting_period
                  ; vesting_increment
                  } =
            query_db ~f:(fun db -> Processor.Zkapp_timing_info.load db id)
          in
          let initial_minimum_balance =
            Currency.Balance.of_string initial_minimum_balance
          in
          let cliff_time =
            cliff_time |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot_since_genesis.of_uint32
          in
          let cliff_amount = Currency.Amount.of_string cliff_amount in
          let vesting_period =
            vesting_period |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot_span.of_uint32
          in
          let vesting_increment = Currency.Amount.of_string vesting_increment in
          Some
            ( { initial_minimum_balance
              ; cliff_time
              ; cliff_amount
              ; vesting_period
              ; vesting_increment
              }
              : Account_update.Update.Timing_info.t ) )
    in
    Set_or_keep.of_option tm_opt
  in
  let%bind voting_for =
    let%map str_opt =
      Mina_caqti.get_opt_item
        ~f:(with_pool ~f:Processor.Voting_for.load)
        voting_for_id
    in
    Option.map str_opt ~f:State_hash.of_base58_check_exn
    |> Set_or_keep.of_option
  in
  return
    ( { app_state
      ; delegate
      ; verification_key
      ; permissions
      ; zkapp_uri
      ; token_symbol
      ; timing
      ; voting_for
      }
      : Account_update.Update.t )

let staking_data_of_id pool id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let%bind { epoch_ledger_id
           ; epoch_seed
           ; start_checkpoint
           ; lock_checkpoint
           ; epoch_length_id
           } =
    query_db ~f:(fun db -> Processor.Zkapp_epoch_data.load db id)
  in
  let%bind ledger =
    let%bind { hash_id; total_currency_id } =
      query_db ~f:(fun db ->
          Processor.Zkapp_epoch_ledger.load db epoch_ledger_id )
    in
    let%bind hash =
      let%map hash_opt =
        Option.value_map hash_id ~default:(return None) ~f:(fun id ->
            let%map hash_str =
              query_db ~f:(fun db -> Processor.Snarked_ledger_hash.load db id)
            in
            Some (Frozen_ledger_hash.of_base58_check_exn hash_str) )
      in
      Or_ignore.of_option hash_opt
    in
    let%bind total_currency = get_amount_bounds pool total_currency_id in
    return
      ( { hash; total_currency }
        : ( Frozen_ledger_hash.t Or_ignore.t
          , Currency.Amount.t Zkapp_precondition.Numeric.t )
          Epoch_ledger.Poly.t )
  in
  let seed =
    Option.map epoch_seed ~f:Snark_params.Tick.Field.of_string
    |> Or_ignore.of_option
  in
  let start_checkpoint =
    Option.map start_checkpoint ~f:State_hash.of_base58_check_exn
    |> Or_ignore.of_option
  in
  let lock_checkpoint =
    Option.map lock_checkpoint ~f:State_hash.of_base58_check_exn
    |> Or_ignore.of_option
  in
  let%map epoch_length = get_length_bounds pool epoch_length_id in
  ( { ledger; seed; start_checkpoint; lock_checkpoint; epoch_length }
    : Zkapp_precondition.Protocol_state.Epoch_data.t )

let protocol_state_precondition_of_id pool id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let%bind ({ snarked_ledger_hash_id
            ; blockchain_length_id
            ; min_window_density_id
            ; total_currency_id
            ; global_slot_since_genesis
            ; staking_epoch_data_id
            ; next_epoch_data_id
            }
             : Processor.Zkapp_network_precondition.t ) =
    query_db ~f:(fun db -> Processor.Zkapp_network_precondition.load db id)
  in
  let%bind snarked_ledger_hash =
    let%map hash_opt =
      Option.value_map snarked_ledger_hash_id ~default:(return None)
        ~f:(fun id ->
          let%map hash =
            query_db ~f:(fun db -> Processor.Snarked_ledger_hash.load db id)
          in
          Some (Frozen_ledger_hash.of_base58_check_exn hash) )
    in
    Or_ignore.of_option hash_opt
  in
  let%bind blockchain_length = get_length_bounds pool blockchain_length_id in
  let%bind min_window_density = get_length_bounds pool min_window_density_id in
  let%bind total_currency = get_amount_bounds pool total_currency_id in
  let%bind global_slot_since_genesis =
    get_global_slot_bounds pool global_slot_since_genesis
  in
  let%bind staking_epoch_data = staking_data_of_id pool staking_epoch_data_id in
  let%map next_epoch_data = staking_data_of_id pool next_epoch_data_id in
  ( { snarked_ledger_hash
    ; blockchain_length
    ; min_window_density
    ; total_currency
    ; global_slot_since_genesis
    ; staking_epoch_data
    ; next_epoch_data
    }
    : Zkapp_precondition.Protocol_state.t )

let load_events pool id =
  let query_db ~f = Mina_caqti.query ~f pool in
  let%map fields_list =
    (* each id refers to an item in 'zkapp_field_array' *)
    let%bind field_array_ids =
      query_db ~f:(fun db -> Processor.Zkapp_events.load db id)
    in
    Deferred.List.map (Array.to_list field_array_ids) ~f:(fun array_id ->
        let%bind field_ids =
          query_db ~f:(fun db -> Processor.Zkapp_field_array.load db array_id)
        in
        Deferred.List.map (Array.to_list field_ids) ~f:(fun field_id ->
            let%map field_str =
              query_db ~f:(fun db -> Processor.Zkapp_field.load db field_id)
            in
            Zkapp_basic.F.of_string field_str ) )
  in
  List.map fields_list ~f:Array.of_list

let get_fee_payer_body ~pool body_id =
  let query_db ~f = Mina_caqti.query ~f pool in
  let%bind { public_key_id; fee; valid_until; nonce } =
    query_db ~f:(fun db -> Processor.Zkapp_fee_payer_body.load db body_id)
  in
  let%bind public_key = pk_of_id pool public_key_id in
  let fee = Currency.Fee.of_string fee in
  let valid_until =
    let open Option.Let_syntax in
    valid_until >>| Unsigned.UInt32.of_int64
    >>| Mina_numbers.Global_slot_since_genesis.of_uint32
  in
  let nonce =
    nonce |> Unsigned.UInt32.of_int64 |> Mina_numbers.Account_nonce.of_uint32
  in
  return
    ({ public_key; fee; valid_until; nonce } : Account_update.Body.Fee_payer.t)

let get_account_update_body ~pool body_id =
  let open Zkapp_basic in
  let query_db ~f = Mina_caqti.query ~f pool in
  let pk_of_id = pk_of_id pool in
  let%bind { account_identifier_id
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
           } =
    query_db ~f:(fun db -> Processor.Zkapp_account_update_body.load db body_id)
  in
  let%bind account_id = account_identifier_of_id pool account_identifier_id in
  let public_key = Account_id.public_key account_id in
  let token_id = Account_id.token_id account_id in
  let%bind update = update_of_id pool update_id in
  let balance_change =
    let magnitude, sgn =
      match String.split balance_change ~on:'-' with
      | [ s ] ->
          (Currency.Amount.of_string s, Sgn.Pos)
      | [ ""; s ] ->
          (Currency.Amount.of_string s, Sgn.Neg)
      | _ ->
          failwith "Ill-formatted string for balance change"
    in
    Currency.Amount.Signed.create ~magnitude ~sgn
  in
  let%bind events = load_events pool events_id in
  let%bind actions = load_events pool actions_id in
  let%bind call_data =
    let%map field_str =
      query_db ~f:(fun db -> Processor.Zkapp_field.load db call_data_id)
    in
    Zkapp_basic.F.of_string field_str
  in
  let%bind protocol_state_precondition =
    protocol_state_precondition_of_id pool zkapp_network_precondition_id
  in
  let%bind account_precondition =
    let%bind ({ balance_id
              ; nonce_id
              ; receipt_chain_hash
              ; delegate_id
              ; state_id
              ; action_state_id
              ; proved_state
              ; is_new
              }
               : Processor.Zkapp_account_precondition.t ) =
      query_db ~f:(fun db ->
          Processor.Zkapp_account_precondition.load db
            zkapp_account_precondition_id )
    in
    let%bind balance =
      let%map balance_opt =
        Option.value_map balance_id ~default:(return None) ~f:(fun id ->
            let%map { balance_lower_bound; balance_upper_bound } =
              query_db ~f:(fun db -> Processor.Zkapp_balance_bounds.load db id)
            in
            let lower = Currency.Balance.of_string balance_lower_bound in
            let upper = Currency.Balance.of_string balance_upper_bound in
            Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t) )
      in
      Or_ignore.of_option balance_opt
    in
    let%bind nonce =
      let%map nonce_opt =
        Option.value_map nonce_id ~default:(return None) ~f:(fun id ->
            let%map { nonce_lower_bound; nonce_upper_bound } =
              query_db ~f:(fun db -> Processor.Zkapp_nonce_bounds.load db id)
            in
            let balance_of_int64 int64 =
              int64 |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Account_nonce.of_uint32
            in
            let lower = balance_of_int64 nonce_lower_bound in
            let upper = balance_of_int64 nonce_upper_bound in
            Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t) )
      in
      Or_ignore.of_option nonce_opt
    in
    let receipt_chain_hash =
      Option.map receipt_chain_hash ~f:Receipt.Chain_hash.of_base58_check_exn
      |> Or_ignore.of_option
    in
    let get_pk id =
      let%map pk_opt =
        Option.value_map id ~default:(return None) ~f:(fun id ->
            let%map pk = pk_of_id id in
            Some pk )
      in
      Or_ignore.of_option pk_opt
    in
    let%bind delegate = get_pk delegate_id in
    let%bind state =
      let%bind { element0
               ; element1
               ; element2
               ; element3
               ; element4
               ; element5
               ; element6
               ; element7
               } =
        query_db ~f:(fun db ->
            Processor.Zkapp_states_nullable.load db state_id )
      in
      let elements =
        [ element0
        ; element1
        ; element2
        ; element3
        ; element4
        ; element5
        ; element6
        ; element7
        ]
      in
      let%map fields =
        Deferred.List.map elements ~f:(fun id_opt ->
            Option.value_map id_opt ~default:(return None) ~f:(fun id ->
                let%map field_str =
                  query_db ~f:(fun db -> Processor.Zkapp_field.load db id)
                in
                Some (Zkapp_basic.F.of_string field_str) ) )
      in
      List.map fields ~f:Or_ignore.of_option |> Zkapp_state.V.of_list_exn
    in
    let%bind action_state =
      let%map action_state_opt =
        Option.value_map action_state_id ~default:(return None) ~f:(fun id ->
            let%map field_str =
              query_db ~f:(fun db -> Processor.Zkapp_field.load db id)
            in
            Some (Zkapp_basic.F.of_string field_str) )
      in
      Or_ignore.of_option action_state_opt
    in
    let proved_state = Or_ignore.of_option proved_state in
    let is_new = Or_ignore.of_option is_new in
    return
      ( { balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; state
        ; action_state
        ; proved_state
        ; is_new
        }
        : Zkapp_precondition.Account.t )
  in
  let%bind valid_while_precondition =
    get_global_slot_bounds pool zkapp_valid_while_precondition_id
  in
  let may_use_token = Account_update.May_use_token.of_string may_use_token in
  let%bind authorization_kind =
    match Control.Tag.of_string_exn authorization_kind with
    | Proof -> (
        match verification_key_hash_id with
        | Some id ->
            let%map vk_hash_str =
              Mina_caqti.query pool ~f:(fun db ->
                  Processor.Zkapp_verification_key_hashes.load db id )
            in
            Account_update.Authorization_kind.Proof
              (Zkapp_basic.F.of_string vk_hash_str)
        | None ->
            failwith
              "Expected non-NULL verification_key_hash_id for Proof \
               authorization kind" )
    | Signature ->
        assert (Option.is_none verification_key_hash_id) ;
        return Account_update.Authorization_kind.Signature
    | None_given ->
        assert (Option.is_none verification_key_hash_id) ;
        return Account_update.Authorization_kind.None_given
  in
  return
    ( { public_key
      ; token_id
      ; update
      ; balance_change
      ; increment_nonce
      ; events
      ; actions
      ; call_data
      ; call_depth
      ; preconditions =
          { Account_update.Preconditions.network = protocol_state_precondition
          ; account = account_precondition
          ; valid_while = valid_while_precondition
          }
      ; use_full_commitment
      ; implicit_account_creation_fee
      ; may_use_token
      ; authorization_kind
      }
      : Account_update.Body.Simple.t )

let get_account_accessed ~pool (account : Processor.Accounts_accessed.t) :
    (int * Account.t) Deferred.t =
  let query_db ~f = Mina_caqti.query ~f pool in
  let with_pool ~f arg =
    let open Caqti_async in
    Pool.use
      (fun (module Conn : CONNECTION) -> f (module Conn : CONNECTION) arg)
      pool
  in
  let pk_of_id = pk_of_id pool in
  let token_of_id = token_of_id pool in
  let ({ ledger_index
       ; block_id = _
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
        : Processor.Accounts_accessed.t ) =
    account
  in
  let%bind ({ public_key_id; token_id } : Processor.Account_identifiers.t) =
    query_db ~f:(fun db ->
        Processor.Account_identifiers.load db account_identifier_id )
  in
  let%bind public_key = pk_of_id public_key_id in
  let%bind token_id = token_of_id token_id in
  let%bind token_symbol =
    query_db ~f:(fun db -> Processor.Token_symbols.load db token_symbol_id)
  in
  let balance = Currency.Balance.of_string balance in
  let nonce = nonce |> Unsigned.UInt32.of_int64 |> Account.Nonce.of_uint32 in
  let receipt_chain_hash =
    receipt_chain_hash |> Receipt.Chain_hash.of_base58_check_exn
  in
  let%bind delegate =
    let%map pk_str_opt =
      Mina_caqti.get_opt_item delegate_id
        ~f:(with_pool ~f:Processor.Public_key.find_by_id)
    in
    Option.map pk_str_opt
      ~f:Signature_lib.Public_key.Compressed.of_base58_check_exn
  in
  let%bind voting_for =
    let%map hash_str =
      query_db ~f:(fun db -> Processor.Voting_for.load db voting_for_id)
    in
    State_hash.of_base58_check_exn hash_str
  in
  let%bind timing =
    match%map
      query_db ~f:(fun db -> Processor.Timing_info.load_opt db timing_id)
    with
    | None ->
        Account_timing.Untimed
    | Some timing ->
        let ({ initial_minimum_balance
             ; cliff_time
             ; cliff_amount
             ; vesting_period
             ; vesting_increment
             ; _
             }
              : Processor.Timing_info.t ) =
          timing
        in
        if
          List.for_all [ cliff_time; vesting_period ] ~f:Int64.(equal zero)
          && List.for_all
               [ initial_minimum_balance; cliff_amount; vesting_increment ]
               ~f:String.(equal "0")
        then Untimed
        else
          let initial_minimum_balance =
            Currency.Balance.of_string initial_minimum_balance
          in
          let cliff_time =
            cliff_time |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot_since_genesis.of_uint32
          in
          let cliff_amount = Currency.Amount.of_string cliff_amount in
          let vesting_period =
            vesting_period |> Unsigned.UInt32.of_int64
            |> Mina_numbers.Global_slot_span.of_uint32
          in
          let vesting_increment = Currency.Amount.of_string vesting_increment in
          Timed
            { initial_minimum_balance
            ; cliff_time
            ; cliff_amount
            ; vesting_period
            ; vesting_increment
            }
  in
  let%bind permissions =
    let%bind { edit_state
             ; send
             ; receive
             ; access
             ; set_delegate
             ; set_permissions
             ; set_verification_key = verification_key_auth, version_id
             ; set_zkapp_uri
             ; edit_action_state
             ; set_token_symbol
             ; increment_nonce
             ; set_voting_for
             ; set_timing
             } =
      query_db ~f:(fun db -> Processor.Zkapp_permissions.load db permissions_id)
    in
    let%map { transaction; network; patch } =
      query_db ~f:(fun db -> Processor.Protocol_versions.load db version_id)
    in

    ( { edit_state
      ; send
      ; receive
      ; access
      ; set_delegate
      ; set_permissions
      ; set_verification_key =
          ( verification_key_auth
          , Protocol_version.create ~transaction ~network ~patch )
      ; set_zkapp_uri
      ; edit_action_state
      ; set_token_symbol
      ; increment_nonce
      ; set_voting_for
      ; set_timing
      }
      : Permissions.t )
  in
  let%bind zkapp_db =
    Mina_caqti.get_opt_item zkapp_id
      ~f:(with_pool ~f:Processor.Zkapp_account.load)
  in
  let%bind zkapp =
    Option.value_map ~default:(return None) zkapp_db
      ~f:(fun
           { app_state_id
           ; verification_key_id
           ; zkapp_version
           ; action_state_id
           ; last_action_slot
           ; proved_state
           ; zkapp_uri_id
           }
         ->
        let%bind { element0
                 ; element1
                 ; element2
                 ; element3
                 ; element4
                 ; element5
                 ; element6
                 ; element7
                 } =
          query_db ~f:(fun db -> Processor.Zkapp_states.load db app_state_id)
        in
        let elements =
          [ element0
          ; element1
          ; element2
          ; element3
          ; element4
          ; element5
          ; element6
          ; element7
          ]
        in
        let%bind app_state =
          let%map field_strs =
            Deferred.List.map elements ~f:(fun id ->
                query_db ~f:(fun db -> Processor.Zkapp_field.load db id) )
          in
          let fields = List.map field_strs ~f:Zkapp_basic.F.of_string in
          Zkapp_state.V.of_list_exn fields
        in
        let%bind verification_key =
          Option.value_map verification_key_id ~default:(return None)
            ~f:(fun id ->
              let%bind { verification_key; hash_id } =
                query_db ~f:(fun db ->
                    Processor.Zkapp_verification_keys.load db id )
              in
              let data =
                match Base64.decode verification_key with
                | Ok s ->
                    Binable.of_string
                      (module Pickles.Side_loaded.Verification_key.Stable.Latest)
                      s
                | Error (`Msg err) ->
                    failwithf "Could not Base64-decode verification key: %s" err
                      ()
              in
              let%map hash =
                let%map hash_str =
                  query_db ~f:(fun db ->
                      Processor.Zkapp_verification_key_hashes.load db hash_id )
                in
                Zkapp_basic.F.of_string hash_str
              in
              Some ({ data; hash } : _ With_hash.t) )
        in
        let zkapp_version =
          zkapp_version |> Unsigned.UInt32.of_int64
          |> Mina_numbers.Zkapp_version.of_uint32
        in
        let%bind { element0; element1; element2; element3; element4 } =
          query_db ~f:(fun db ->
              Processor.Zkapp_action_states.load db action_state_id )
        in
        let elements = [ element0; element1; element2; element3; element4 ] in
        let%bind action_state =
          let%map field_strs =
            Deferred.List.map elements ~f:(fun id ->
                query_db ~f:(fun db -> Processor.Zkapp_field.load db id) )
          in
          let fields = List.map field_strs ~f:Zkapp_basic.F.of_string in
          Pickles_types.Vector.Vector_5.of_list_exn fields
        in
        let last_action_slot =
          last_action_slot |> Unsigned.UInt32.of_int64
          |> Mina_numbers.Global_slot_since_genesis.of_uint32
        in
        let%map zkapp_uri =
          query_db ~f:(fun db -> Processor.Zkapp_uri.load db zkapp_uri_id)
        in
        Some
          ( { app_state
            ; verification_key
            ; zkapp_version
            ; action_state
            ; last_action_slot
            ; proved_state
            ; zkapp_uri
            }
            : Mina_base.Zkapp_account.t ) )
  in
  (* TODO: token permissions is going away *)
  let account =
    ( { public_key
      ; token_id
      ; token_symbol
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing
      ; permissions
      ; zkapp
      }
      : Mina_base.Account.t )
  in
  return (ledger_index, account)
