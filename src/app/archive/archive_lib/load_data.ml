(* load_data.ml -- load archive db data to "native" OCaml data *)

open Core_kernel
open Async
open Mina_base

(* converts db query result from Deferred.Result.t to Deferred.t
   fail on Error
*)
let query_db ~item ~f pool =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let pk_of_id ~item pool pk_id =
  let%map pk_str =
    query_db pool ~item ~f:(fun db -> Processor.Public_key.find_by_id db pk_id)
  in
  Signature_lib.Public_key.Compressed.of_base58_check_exn pk_str

let token_of_id ~item pool token_id =
  let%map token_str =
    query_db pool ~item ~f:(fun db -> Processor.Token.find_by_id db token_id)
  in
  Token_id.of_string token_str

let get_party_body ~pool body_id =
  let open Zkapp_basic in
  let query_db = query_db pool in
  let pk_of_id = pk_of_id pool in
  let token_of_id = token_of_id pool in
  let%bind { public_key_id
           ; update_id
           ; token_id
           ; balance_change
           ; increment_nonce
           ; events_id
           ; sequence_events_id
           ; call_data_id
           ; call_depth
           ; zkapp_protocol_state_precondition_id
           ; zkapp_account_precondition_id
           ; use_full_commitment
           } =
    query_db ~item:"zkapp fee payer body" ~f:(fun db ->
        Processor.Zkapp_party_body.load db body_id)
  in
  let%bind public_key = pk_of_id public_key_id ~item:"fee payer body pk" in
  let%bind token_id = token_of_id token_id ~item:"body token id" in
  let%bind update =
    let%bind { app_state_id
             ; delegate_id
             ; verification_key_id
             ; permissions_id
             ; zkapp_uri_id
             ; token_symbol
             ; timing_id
             ; voting_for
             } =
      query_db ~item:"zkapp fee payer update" ~f:(fun db ->
          Processor.Zkapp_updates.load db update_id)
    in
    let%bind app_state =
      let%bind field_id_array =
        query_db ~item:"fee payer update app state" ~f:(fun db ->
            Processor.Zkapp_states.load db app_state_id)
      in
      let field_ids = Array.to_list field_id_array in
      let%map field_strs =
        Deferred.List.map field_ids ~f:(fun id_opt ->
            Option.value_map id_opt ~default:(return None) ~f:(fun id ->
                let%map field =
                  query_db ~item:"fee payer update app state field"
                    ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                in
                Some field))
      in
      let fields =
        List.map field_strs ~f:(fun str_opt ->
            Option.value_map str_opt ~default:Set_or_keep.Keep ~f:(fun str ->
                Set_or_keep.Set (F.of_string str)))
      in
      Zkapp_state.V.of_list_exn fields
    in
    let%bind delegate =
      let%map pk_opt =
        Option.value_map delegate_id ~default:(return None) ~f:(fun id ->
            let%map pk = pk_of_id id ~item:"fee payer update delegate" in
            Some pk)
      in
      Set_or_keep.of_option pk_opt
    in
    let%bind verification_key =
      let%map vk_opt =
        Option.value_map verification_key_id ~default:(return None)
          ~f:(fun id ->
            let%map vk =
              query_db ~item:"fee payer update verification key" ~f:(fun db ->
                  Processor.Zkapp_verification_keys.load db id)
            in
            Some vk)
      in
      Set_or_keep.of_option
        (Option.map vk_opt ~f:(fun { verification_key; hash } ->
             match Base64.decode verification_key with
             | Ok s ->
                 let data =
                   Binable.of_string
                     (module Pickles.Side_loaded.Verification_key.Stable.Latest)
                     s
                 in
                 let hash = Pickles.Backend.Tick.Field.of_string hash in
                 { With_hash.data; hash }
             | Error (`Msg err) ->
                 failwithf "Could not Base64-decode verification key: %s" err ()))
    in
    let%bind permissions =
      let%map perms_opt =
        Option.value_map permissions_id ~default:(return None) ~f:(fun id ->
            let%map { edit_state
                    ; send
                    ; receive
                    ; set_delegate
                    ; set_permissions
                    ; set_verification_key
                    ; set_zkapp_uri
                    ; edit_sequence_state
                    ; set_token_symbol
                    ; increment_nonce
                    ; set_voting_for
                    } =
              query_db ~item:"fee payer update permissions" ~f:(fun db ->
                  Processor.Zkapp_permissions.load db id)
            in
            (* same fields, different types *)
            Some
              ( { edit_state
                ; send
                ; receive
                ; set_delegate
                ; set_permissions
                ; set_verification_key
                ; set_zkapp_uri
                ; edit_sequence_state
                ; set_token_symbol
                ; increment_nonce
                ; set_voting_for
                }
                : Permissions.t ))
      in
      Set_or_keep.of_option perms_opt
    in
    let%bind zkapp_uri =
      let%map uri_opt =
        Option.value_map zkapp_uri_id ~default:(return None) ~f:(fun id ->
            let%map uri =
              query_db ~item:"fee payer update zkapp uri" ~f:(fun db ->
                  Processor.Zkapp_uri.load db id)
            in
            Some uri)
      in
      Set_or_keep.of_option uri_opt
    in
    let token_symbol = token_symbol |> Set_or_keep.of_option in
    let%bind timing =
      let%map tm_opt =
        Option.value_map timing_id ~default:(return None) ~f:(fun id ->
            let%map { initial_minimum_balance
                    ; cliff_time
                    ; cliff_amount
                    ; vesting_period
                    ; vesting_increment
                    } =
              query_db ~item:"fee payer update timing" ~f:(fun db ->
                  Processor.Zkapp_timing_info.load db id)
            in
            let initial_minimum_balance =
              initial_minimum_balance |> Unsigned.UInt64.of_int64
              |> Currency.Balance.of_uint64
            in
            let cliff_time =
              cliff_time |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Global_slot.of_uint32
            in
            let cliff_amount =
              cliff_amount |> Unsigned.UInt64.of_int64
              |> Currency.Amount.of_uint64
            in
            let vesting_period =
              vesting_period |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Global_slot.of_uint32
            in
            let vesting_increment =
              vesting_increment |> Unsigned.UInt64.of_int64
              |> Currency.Amount.of_uint64
            in
            Some
              ( { initial_minimum_balance
                ; cliff_time
                ; cliff_amount
                ; vesting_period
                ; vesting_increment
                }
                : Party.Update.Timing_info.t ))
      in
      Set_or_keep.of_option tm_opt
    in
    let voting_for =
      Option.map voting_for ~f:State_hash.of_base58_check_exn
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
        : Party.Update.t )
  in
  let balance_change =
    let magnitude =
      balance_change |> Int64.abs |> Unsigned.UInt64.of_int64
      |> Currency.Amount.of_uint64
    in
    let sgn = if Int64.is_negative balance_change then Sgn.Neg else Sgn.Pos in
    Currency.Amount.Signed.create ~magnitude ~sgn
  in
  let load_events id =
    let%map fields_list =
      (* each id refers to an item in 'zkapp_state_data_array' *)
      let%bind field_array_ids =
        query_db ~item:"events arrays" ~f:(fun db ->
            Processor.Zkapp_events.load db id)
      in
      Deferred.List.map (Array.to_list field_array_ids) ~f:(fun array_id ->
          let%bind field_ids =
            query_db ~item:"events array" ~f:(fun db ->
                Processor.Zkapp_state_data_array.load db array_id)
          in
          Deferred.List.map (Array.to_list field_ids) ~f:(fun field_id ->
              let%map field_str =
                query_db ~item:"event field" ~f:(fun db ->
                    Processor.Zkapp_state_data.load db field_id)
              in
              Zkapp_basic.F.of_string field_str))
    in
    List.map fields_list ~f:Array.of_list
  in
  let%bind events = load_events events_id in
  let%bind sequence_events = load_events sequence_events_id in
  let%bind call_data =
    let%map field_str =
      query_db ~item:"call data" ~f:(fun db ->
          Processor.Zkapp_state_data.load db call_data_id)
    in
    Zkapp_basic.F.of_string field_str
  in
  let%bind protocol_state_precondition =
    let%bind ({ snarked_ledger_hash_id
              ; timestamp_id
              ; blockchain_length_id
              ; min_window_density_id
              ; total_currency_id
              ; curr_global_slot_since_hard_fork
              ; global_slot_since_genesis
              ; staking_epoch_data_id
              ; next_epoch_data_id
              }
               : Processor.Zkapp_precondition_protocol_state.t) =
      query_db ~item:"protocol state precondition" ~f:(fun db ->
          Processor.Zkapp_precondition_protocol_state.load db
            zkapp_protocol_state_precondition_id)
    in
    let%bind snarked_ledger_hash =
      let%map hash_opt =
        Option.value_map snarked_ledger_hash_id ~default:(return None)
          ~f:(fun id ->
            let%map hash =
              query_db ~item:"snarked ledger hash" ~f:(fun db ->
                  Processor.Snarked_ledger_hash.load db id)
            in
            Some (Frozen_ledger_hash.of_base58_check_exn hash))
      in
      Or_ignore.of_option hash_opt
    in
    let%bind timestamp =
      let%map ts_db_opt =
        Option.value_map timestamp_id ~default:(return None) ~f:(fun id ->
            let%map ts =
              query_db ~item:"timestamp bounds" ~f:(fun db ->
                  Processor.Zkapp_timestamp_bounds.load db id)
            in
            Some ts)
      in
      let ts_opt =
        Option.map ts_db_opt
          ~f:(fun { timestamp_lower_bound; timestamp_upper_bound } ->
            let lower = Block_time.of_int64 timestamp_lower_bound in
            let upper = Block_time.of_int64 timestamp_upper_bound in
            ( { lower; upper }
              : Block_time.t Zkapp_precondition.Closed_interval.t ))
      in
      Or_ignore.of_option ts_opt
    in
    let get_length_bounds id_opt =
      let%map bl_db_opt =
        Option.value_map id_opt ~default:(return None) ~f:(fun id ->
            let%map ts =
              query_db ~item:"length bounds" ~f:(fun db ->
                  Processor.Zkapp_length_bounds.load db id)
            in
            Some ts)
      in
      let bl_opt =
        Option.map bl_db_opt
          ~f:(fun { length_lower_bound; length_upper_bound } ->
            let lower = Unsigned.UInt32.of_int64 length_lower_bound in
            let upper = Unsigned.UInt32.of_int64 length_upper_bound in
            ( { lower; upper }
              : Unsigned.UInt32.t Zkapp_precondition.Closed_interval.t ))
      in
      Or_ignore.of_option bl_opt
    in
    let%bind blockchain_length = get_length_bounds blockchain_length_id in
    let%bind min_window_density = get_length_bounds min_window_density_id in
    let get_amount_bounds amount_id =
      let%map amount_db_opt =
        Option.value_map amount_id ~default:(return None) ~f:(fun id ->
            let%map amount =
              query_db ~item:"amount bounds" ~f:(fun db ->
                  Processor.Zkapp_amount_bounds.load db id)
            in
            Some amount)
      in
      let amount_opt =
        Option.map amount_db_opt
          ~f:(fun { amount_lower_bound; amount_upper_bound } ->
            let lower =
              amount_lower_bound |> Unsigned.UInt64.of_int64
              |> Currency.Amount.of_uint64
            in
            let upper =
              amount_upper_bound |> Unsigned.UInt64.of_int64
              |> Currency.Amount.of_uint64
            in
            ( { lower; upper }
              : Currency.Amount.t Zkapp_precondition.Closed_interval.t ))
      in
      Or_ignore.of_option amount_opt
    in
    let%bind total_currency = get_amount_bounds total_currency_id in
    let get_global_slot_bounds id_opt =
      let%map bounds_opt =
        Option.value_map id_opt ~default:(return None) ~f:(fun id ->
            let%map bounds =
              query_db ~item:"slot bounds" ~f:(fun db ->
                  Processor.Zkapp_global_slot_bounds.load db id)
            in
            let slot_of_int64 int64 =
              int64 |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Global_slot.of_uint32
            in
            let lower = slot_of_int64 bounds.global_slot_lower_bound in
            let upper = slot_of_int64 bounds.global_slot_upper_bound in
            Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t))
      in
      Or_ignore.of_option bounds_opt
    in
    let%bind global_slot_since_hard_fork =
      get_global_slot_bounds curr_global_slot_since_hard_fork
    in
    let%bind global_slot_since_genesis =
      get_global_slot_bounds global_slot_since_genesis
    in
    let get_staking_data id =
      let%bind { epoch_ledger_id
               ; epoch_seed
               ; start_checkpoint
               ; lock_checkpoint
               ; epoch_length_id
               } =
        query_db ~item:"epoch data" ~f:(fun db ->
            Processor.Zkapp_epoch_data.load db id)
      in
      let%bind ledger =
        let%bind { hash_id; total_currency_id } =
          query_db ~item:"epoch ledger" ~f:(fun db ->
              Processor.Zkapp_epoch_ledger.load db epoch_ledger_id)
        in
        let%bind hash =
          let%map hash_opt =
            Option.value_map hash_id ~default:(return None) ~f:(fun id ->
                let%map hash_str =
                  query_db ~item:"epoch ledger hash" ~f:(fun db ->
                      Processor.Snarked_ledger_hash.load db id)
                in
                Some (Frozen_ledger_hash.of_base58_check_exn hash_str))
          in
          Or_ignore.of_option hash_opt
        in
        let%bind total_currency = get_amount_bounds total_currency_id in
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
      let%bind epoch_length = get_length_bounds epoch_length_id in
      return
        ( { ledger; seed; start_checkpoint; lock_checkpoint; epoch_length }
          : Zkapp_precondition.Protocol_state.Epoch_data.t )
    in
    let%bind staking_epoch_data = get_staking_data staking_epoch_data_id in
    let%bind next_epoch_data = get_staking_data next_epoch_data_id in
    return
      ( { snarked_ledger_hash
        ; timestamp
        ; blockchain_length
        ; min_window_density
        ; last_vrf_output = ()
        ; total_currency
        ; global_slot_since_hard_fork
        ; global_slot_since_genesis
        ; staking_epoch_data
        ; next_epoch_data
        }
        : Zkapp_precondition.Protocol_state.t )
  in
  let%bind account_precondition =
    let%bind ({ kind; account_id; nonce }
               : Processor.Zkapp_account_precondition.t) =
      query_db ~item:"account precondition" ~f:(fun db ->
          Processor.Zkapp_account_precondition.load db
            zkapp_account_precondition_id)
    in
    match kind with
    | Nonce ->
        assert (Option.is_some nonce) ;
        let nonce =
          Option.value_exn nonce |> Unsigned.UInt32.of_int64
          |> Mina_numbers.Account_nonce.of_uint32
        in
        return @@ Party.Account_precondition.Nonce nonce
    | Accept ->
        return Party.Account_precondition.Accept
    | Full ->
        assert (Option.is_some account_id) ;
        let%bind { balance_id
                 ; nonce_id
                 ; receipt_chain_hash
                 ; public_key_id
                 ; delegate_id
                 ; state_id
                 ; sequence_state_id
                 ; proved_state
                 } =
          query_db ~item:"precondition account" ~f:(fun db ->
              Processor.Zkapp_precondition_account.load db
                (Option.value_exn account_id))
        in
        let%bind balance =
          let%map balance_opt =
            Option.value_map balance_id ~default:(return None) ~f:(fun id ->
                let%map { balance_lower_bound; balance_upper_bound } =
                  query_db ~item:"balance bounds" ~f:(fun db ->
                      Processor.Zkapp_balance_bounds.load db id)
                in
                let balance_of_int64 int64 =
                  int64 |> Unsigned.UInt64.of_int64
                  |> Currency.Balance.of_uint64
                in
                let lower = balance_of_int64 balance_lower_bound in
                let upper = balance_of_int64 balance_upper_bound in
                Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t))
          in
          Or_ignore.of_option balance_opt
        in
        let%bind nonce =
          let%map nonce_opt =
            Option.value_map nonce_id ~default:(return None) ~f:(fun id ->
                let%map { nonce_lower_bound; nonce_upper_bound } =
                  query_db ~item:"nonce bounds" ~f:(fun db ->
                      Processor.Zkapp_nonce_bounds.load db id)
                in
                let balance_of_int64 int64 =
                  int64 |> Unsigned.UInt32.of_int64
                  |> Mina_numbers.Account_nonce.of_uint32
                in
                let lower = balance_of_int64 nonce_lower_bound in
                let upper = balance_of_int64 nonce_upper_bound in
                Some ({ lower; upper } : _ Zkapp_precondition.Closed_interval.t))
          in
          Or_ignore.of_option nonce_opt
        in
        let receipt_chain_hash =
          Option.map receipt_chain_hash
            ~f:Receipt.Chain_hash.of_base58_check_exn
          |> Or_ignore.of_option
        in
        let get_pk ~item id =
          let%map pk_opt =
            Option.value_map id ~default:(return None) ~f:(fun id ->
                let%map pk = pk_of_id id ~item in
                Some pk)
          in
          Or_ignore.of_option pk_opt
        in
        let%bind public_key =
          get_pk ~item:"precondition account pk" public_key_id
        in
        let%bind delegate =
          get_pk ~item:"precondition delegate pk" delegate_id
        in
        let%bind state =
          let%bind field_ids =
            query_db ~item:"precondition account state" ~f:(fun db ->
                Processor.Zkapp_states.load db state_id)
          in
          let%map fields =
            Deferred.List.map (Array.to_list field_ids) ~f:(fun id_opt ->
                Option.value_map id_opt ~default:(return None) ~f:(fun id ->
                    let%map field_str =
                      query_db ~item:"precondition account state field"
                        ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                    in
                    Some (Zkapp_basic.F.of_string field_str)))
          in
          List.map fields ~f:Or_ignore.of_option |> Zkapp_state.V.of_list_exn
        in
        let%bind sequence_state =
          let%map sequence_state_opt =
            Option.value_map sequence_state_id ~default:(return None)
              ~f:(fun id ->
                let%map field_str =
                  query_db ~item:"precondition account sequence state"
                    ~f:(fun db -> Processor.Zkapp_state_data.load db id)
                in
                Some (Zkapp_basic.F.of_string field_str))
          in
          Or_ignore.of_option sequence_state_opt
        in
        let proved_state = Or_ignore.of_option proved_state in
        return
          (Party.Account_precondition.Full
             { balance
             ; nonce
             ; receipt_chain_hash
             ; public_key
             ; delegate
             ; state
             ; sequence_state
             ; proved_state
             })
  in
  return
    ( { public_key
      ; token_id
      ; update
      ; balance_change
      ; increment_nonce
      ; events
      ; sequence_events
      ; call_data
      ; call_depth
      ; protocol_state_precondition
      ; account_precondition
      ; use_full_commitment
      }
      : Party.Body.t )
