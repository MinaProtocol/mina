(* extract_blocks.ml -- dump extensional blocks from archive db *)

open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Signature_lib
open Archive_lib

let query_db pool ~f ~item =
  match%bind Caqti_async.Pool.use f pool with
  | Ok v ->
      return v
  | Error msg ->
      failwithf "Error getting %s from db, error: %s" item
        (Caqti_error.show msg) ()

let epoch_data_of_raw_epoch_data ~pool (raw_epoch_data : Processor.Epoch_data.t)
    =
  let%bind hash_str =
    query_db pool
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db raw_epoch_data.ledger_hash_id)
      ~item:"epoch ledger hash"
  in
  let hash = Frozen_ledger_hash.of_base58_check_exn hash_str in
  let total_currency =
    raw_epoch_data.total_currency |> Unsigned.UInt64.of_int64
    |> Currency.Amount.of_uint64
  in
  let ledger = { Mina_base.Epoch_ledger.Poly.hash; total_currency } in
  let seed = raw_epoch_data.seed |> Epoch_seed.of_base58_check_exn in
  let start_checkpoint =
    raw_epoch_data.start_checkpoint |> State_hash.of_base58_check_exn
  in
  let lock_checkpoint =
    raw_epoch_data.lock_checkpoint |> State_hash.of_base58_check_exn
  in
  let epoch_length =
    raw_epoch_data.epoch_length |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Length.of_uint32
  in
  return
    { Mina_base.Epoch_data.Poly.ledger
    ; seed
    ; start_checkpoint
    ; lock_checkpoint
    ; epoch_length
    }

let fill_in_block pool (block : Archive_lib.Processor.Block.t) :
    Extensional.Block.t Deferred.t =
  let query_db ~item ~f = query_db pool ~item ~f in
  let state_hash = State_hash.of_base58_check_exn block.state_hash in
  let parent_hash = State_hash.of_base58_check_exn block.parent_hash in
  let open Deferred.Let_syntax in
  let%bind creator_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.creator_id)
      ~item:"creator public key"
  in
  let creator = Public_key.Compressed.of_base58_check_exn creator_str in
  let%bind block_winner_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.block_winner_id)
      ~item:"block winner public key"
  in
  let block_winner =
    Public_key.Compressed.of_base58_check_exn block_winner_str
  in
  let%bind snarked_ledger_hash_str =
    query_db
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db block.snarked_ledger_hash_id)
      ~item:"snarked ledger hash"
  in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
  in
  let%bind staking_epoch_data_raw =
    query_db
      ~f:(fun db -> Processor.Epoch_data.load db block.staking_epoch_data_id)
      ~item:"staking epoch data"
  in
  let%bind staking_epoch_data =
    epoch_data_of_raw_epoch_data ~pool staking_epoch_data_raw
  in
  let%bind next_epoch_data_raw =
    query_db
      ~f:(fun db -> Processor.Epoch_data.load db block.next_epoch_data_id)
      ~item:"staking epoch data"
  in
  let%bind next_epoch_data =
    epoch_data_of_raw_epoch_data ~pool next_epoch_data_raw
  in
  let min_window_density =
    block.min_window_density |> Unsigned.UInt32.of_int64
    |> Mina_numbers.Length.of_uint32
  in
  let total_currency =
    Unsigned.UInt64.of_int64 block.total_currency |> Currency.Amount.of_uint64
  in
  let ledger_hash = Ledger_hash.of_base58_check_exn block.ledger_hash in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot_since_hard_fork =
    Unsigned.UInt32.of_int64 block.global_slot_since_hard_fork
  in
  let global_slot_since_genesis =
    Unsigned.UInt32.of_int64 block.global_slot_since_genesis
  in
  let timestamp = Block_time.of_int64 block.timestamp in
  let chain_status = Chain_status.of_string block.chain_status in
  (* commands, accounts_accessed, accounts_created to be filled in later *)
  return
    { Extensional.Block.state_hash
    ; parent_hash
    ; creator
    ; block_winner
    ; snarked_ledger_hash
    ; staking_epoch_data
    ; next_epoch_data
    ; min_window_density
    ; total_currency
    ; ledger_hash
    ; height
    ; global_slot_since_hard_fork
    ; global_slot_since_genesis
    ; timestamp
    ; user_cmds = []
    ; internal_cmds = []
    ; zkapp_cmds = []
    ; chain_status
    ; accounts_accessed = []
    ; accounts_created = []
    }

let fill_in_accounts_accessed pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind accounts_accessed =
    query_db ~item:"accounts_accessed" ~f:(fun db ->
        Processor.Accounts_accessed.all_from_block db block_id)
  in
  Deferred.List.map accounts_accessed ~f:(fun acct_accessed ->
      let ({ ledger_index
           ; block_id = _
           ; account_identifier_id
           ; token_symbol
           ; balance
           ; nonce
           ; receipt_chain_hash
           ; delegate
           ; voting_for
           ; timing_id
           ; permissions_id
           ; zkapp_id
           ; zkapp_uri_id
           }
            : Processor.Accounts_accessed.t) =
        acct_accessed
      in
      let%bind (account_id : Processor.Account_identifiers.t) =
        query_db ~item:"account_id" ~f:(fun db ->
            Processor.Account_identifiers.load db account_identifier_id)
      in
      let%bind public_key =
        let ({ public_key_id; _ } : Processor.Account_identifiers.t) =
          account_id
        in
        let%map pk_str =
          query_db
            ~f:(fun db -> Sql.Public_key.run db public_key_id)
            ~item:"public key"
        in
        Public_key.Compressed.of_base58_check_exn pk_str
      in
      let%bind token_id =
        let ({ token_id; _ } : Processor.Account_identifiers.t) = account_id in
        let%map token_id_str =
          query_db
            ~f:(fun db -> Processor.Token.find_by_id db token_id)
            ~item:"token id"
        in
        Token_id.of_string token_id_str
      in
      let balance =
        balance |> Unsigned.UInt64.of_int64 |> Currency.Balance.of_uint64
      in
      let nonce =
        nonce |> Unsigned.UInt32.of_int64 |> Account.Nonce.of_uint32
      in
      let receipt_chain_hash =
        receipt_chain_hash |> Receipt.Chain_hash.of_base58_check_exn
      in
      let delegate =
        Option.map delegate ~f:Public_key.Compressed.of_base58_check_exn
      in
      let voting_for = voting_for |> State_hash.of_base58_check_exn in
      let%bind timing =
        match%map
          query_db ~item:"timing" ~f:(fun db ->
              Processor.Timing_info.find_by_pk_id_opt db timing_id)
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
                  : Processor.Timing_info.t) =
              timing
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
            Timed
              { initial_minimum_balance
              ; cliff_time
              ; cliff_amount
              ; vesting_period
              ; vesting_increment
              }
      in
      let%bind permissions =
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
          query_db ~item:"permissions" ~f:(fun db ->
              Processor.Zkapp_permissions.load db permissions_id)
        in
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
          : Permissions.t )
      in
      let%bind zkapp_db =
        Option.value_map zkapp_id ~default:(return None) ~f:(fun id ->
            let%map zkapp =
              query_db ~item:"zkapp" ~f:(fun db ->
                  Processor.Zkapp_account.load db id)
            in
            Some zkapp)
      in
      let%bind zkapp =
        Option.value_map ~default:(return None) zkapp_db
          ~f:(fun
               { app_state_id
               ; verification_key_id
               ; zkapp_version
               ; sequence_state_id
               ; last_sequence_slot
               ; proved_state (* TODO : we'll have this at some point *)
               ; zkapp_uri_id = _
               }
             ->
            let%bind app_state_ints =
              query_db ~item:"app state" ~f:(fun db ->
                  Processor.Zkapp_states.load db app_state_id)
            in
            (* for app state, all elements are non-NULL *)
            assert (Array.for_all app_state_ints ~f:Option.is_some) ;
            let%bind app_state =
              let%map field_strs =
                Deferred.List.init (Array.length app_state_ints) ~f:(fun ndx ->
                    let id = Option.value_exn app_state_ints.(ndx) in
                    query_db ~item:"app state element" ~f:(fun db ->
                        Processor.Zkapp_state_data.load db id))
              in
              let fields = List.map field_strs ~f:Zkapp_basic.F.of_string in
              Zkapp_state.V.of_list_exn fields
            in
            let%bind verification_key =
              Option.value_map verification_key_id ~default:(return None)
                ~f:(fun id ->
                  let%map { verification_key; hash } =
                    query_db ~item:"verification key" ~f:(fun db ->
                        Processor.Zkapp_verification_keys.load db id)
                  in
                  let data =
                    Side_loaded_verification_key.of_base58_check_exn
                      verification_key
                  in
                  let hash = Zkapp_basic.F.of_string hash in
                  Some ({ data; hash } : _ With_hash.t))
            in
            let zkapp_version =
              zkapp_version |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Zkapp_version.of_uint32
            in
            let%bind sequence_state_ints =
              query_db ~item:"sequence state" ~f:(fun db ->
                  Processor.Zkapp_sequence_states.load db sequence_state_id)
            in
            let%map sequence_state =
              let%map field_strs =
                Deferred.List.init (Array.length sequence_state_ints)
                  ~f:(fun ndx ->
                    let id = Option.value_exn app_state_ints.(ndx) in
                    query_db ~item:"sequence state element" ~f:(fun db ->
                        Processor.Zkapp_state_data.load db id))
              in
              let fields = List.map field_strs ~f:Zkapp_basic.F.of_string in
              Pickles_types.Vector.Vector_5.of_list_exn fields
            in
            let last_sequence_slot =
              last_sequence_slot |> Unsigned.UInt32.of_int64
              |> Mina_numbers.Global_slot.of_uint32
            in
            Some
              ( { app_state
                ; verification_key
                ; zkapp_version
                ; sequence_state
                ; last_sequence_slot
                ; proved_state
                }
                : Mina_base.Zkapp_account.t ))
      in
      let%bind zkapp_uri =
        query_db ~item:"zkapp uri" ~f:(fun db ->
            Processor.Zkapp_uri.load db zkapp_uri_id)
      in
      (* TODO: token permissions is going away *)
      let account =
        ( { public_key
          ; token_id
          ; token_permissions =
              Token_permissions.Not_owned { account_disabled = false }
          ; token_symbol
          ; balance
          ; nonce
          ; receipt_chain_hash
          ; delegate
          ; voting_for
          ; timing
          ; permissions
          ; zkapp
          ; zkapp_uri
          }
          : Mina_base.Account.t )
      in
      return (ledger_index, account))

let fill_in_accounts_created pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind accounts_created =
    query_db ~item:"accounts_created" ~f:(fun db ->
        Processor.Accounts_created.all_from_block db block_id)
  in
  Deferred.List.map accounts_created ~f:(fun acct_created ->
      let ({ block_id = _; account_identifier_id; creation_fee }
            : Processor.Accounts_created.t) =
        acct_created
      in
      let%bind ({ public_key_id; token_id; _ }
                 : Processor.Account_identifiers.t) =
        query_db ~item:"account_id" ~f:(fun db ->
            Processor.Account_identifiers.load db account_identifier_id)
      in
      let%bind pk =
        let%map pk_str =
          query_db
            ~f:(fun db -> Sql.Public_key.run db public_key_id)
            ~item:"public key"
        in
        Public_key.Compressed.of_base58_check_exn pk_str
      in
      let%bind token_id =
        let%map token_id_str =
          query_db
            ~f:(fun db -> Processor.Token.find_by_id db token_id)
            ~item:"token id"
        in
        Token_id.of_string token_id_str
      in
      let account_id = Account_id.create pk token_id in
      let fee =
        creation_fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      return (account_id, fee))

let fill_in_user_commands pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let token_of_id id ~item =
    let%map token_str =
      query_db ~f:(fun db -> Processor.Token.find_by_id db id) ~item
    in
    Token_id.of_string token_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind user_command_ids_and_sequence_nos =
    query_db ~item:"user command id, sequence no" ~f:(fun db ->
        Sql.Blocks_and_user_commands.run db ~block_id)
  in
  (* create extensional user command for each id, seq no *)
  Deferred.List.map user_command_ids_and_sequence_nos
    ~f:(fun (user_command_id, sequence_no) ->
      let%bind user_cmd =
        query_db ~item:"user commands" ~f:(fun db ->
            Processor.User_command.Signed_command.load db ~id:user_command_id)
      in
      let typ = user_cmd.typ in
      let%bind fee_payer = pk_of_id ~item:"fee payer" user_cmd.fee_payer_id in
      let%bind source = pk_of_id ~item:"source" user_cmd.source_id in
      let%bind receiver = pk_of_id ~item:"receiver" user_cmd.receiver_id in
      let%bind fee_token =
        token_of_id ~item:"fee token" user_cmd.fee_token_id
      in
      let%bind token = token_of_id ~item:"token" user_cmd.token_id in
      let nonce = user_cmd.nonce |> Account.Nonce.of_int in
      let amount =
        Option.map user_cmd.amount ~f:(fun amt ->
            Unsigned.UInt64.of_int64 amt |> Currency.Amount.of_uint64)
      in
      let fee =
        user_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let valid_until =
        Option.map user_cmd.valid_until ~f:(fun valid ->
            Unsigned.UInt32.of_int64 valid |> Mina_numbers.Global_slot.of_uint32)
      in
      let memo = user_cmd.memo |> Signed_command_memo.of_base58_check_exn in
      let hash = user_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_user_cmd =
        query_db ~item:"block user commands" ~f:(fun db ->
            Processor.Block_and_signed_command.load db ~block_id
              ~user_command_id ~sequence_no)
      in
      let status = block_user_cmd.status in
      let failure_reason =
        Option.map block_user_cmd.failure_reason ~f:(fun s ->
            match Transaction_status.Failure.of_string s with
            | Ok s ->
                s
            | Error err ->
                failwithf "Not a transaction status failure: %s, error: %s" s
                  err ())
      in
      return
        { Extensional.User_command.sequence_no
        ; typ
        ; fee_payer
        ; source
        ; receiver
        ; fee_token
        ; token
        ; nonce
        ; amount
        ; fee
        ; valid_until
        ; memo
        ; hash
        ; status
        ; failure_reason
        })

let fill_in_internal_commands pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let token_of_id id ~item =
    let%map token_str =
      query_db ~f:(fun db -> Processor.Token.find_by_id db id) ~item
    in
    Token_id.of_string token_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind internal_cmd_info =
    query_db
      ~item:
        "internal command id, global_slot, sequence no, secondary sequence no, \
         receiver_balance_id" ~f:(fun db ->
        Sql.Blocks_and_internal_commands.run db ~block_id)
  in
  Deferred.List.map internal_cmd_info
    ~f:(fun { internal_command_id; sequence_no; secondary_sequence_no } ->
      (* pieces from the internal_commands table *)
      let%bind internal_cmd =
        query_db ~item:"blocks internal commands" ~f:(fun db ->
            Processor.Internal_command.load db ~id:internal_command_id)
      in
      let typ = internal_cmd.typ in
      let%bind receiver = pk_of_id ~item:"receiver" internal_cmd.receiver_id in
      let fee =
        internal_cmd.fee |> Unsigned.UInt64.of_int64 |> Currency.Fee.of_uint64
      in
      let%bind token = token_of_id ~item:"token" internal_cmd.token_id in
      let hash = internal_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let cmd =
        { Extensional.Internal_command.sequence_no
        ; secondary_sequence_no
        ; typ
        ; receiver
        ; fee
        ; token
        ; hash
        }
      in
      return cmd)

let fill_in_zkapp_commands pool block_state_hash =
  let query_db ~item ~f = query_db pool ~item ~f in
  let pk_of_id id ~item =
    let%map pk_str = query_db ~f:(fun db -> Sql.Public_key.run db id) ~item in
    Public_key.Compressed.of_base58_check_exn pk_str
  in
  let open Deferred.Let_syntax in
  let%bind block_id =
    query_db ~item:"blocks" ~f:(fun db ->
        Processor.Block.find db ~state_hash:block_state_hash)
  in
  let%bind zkapp_command_ids_and_sequence_nos =
    query_db ~item:"zkapp command id, sequence no" ~f:(fun db ->
        Sql.Blocks_and_zkapp_commands.run db ~block_id)
  in
  (* create extensional zkapp command for each id, seq no *)
  Deferred.List.map zkapp_command_ids_and_sequence_nos
    ~f:(fun (zkapp_command_id, sequence_no) ->
      let open Zkapp_basic in
      let%bind zkapp_cmd =
        query_db ~item:"zkapp commands" ~f:(fun db ->
            Processor.User_command.Zkapp_command.load db zkapp_command_id)
      in
      let get_party_body body_id =
        let%bind body =
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
          let%bind public_key =
            pk_of_id public_key_id ~item:"fee payer body pk"
          in
          let%bind token_id =
            let%map token_str =
              query_db
                ~f:(fun db -> Processor.Token.find_by_id db token_id)
                ~item:"token"
            in
            Token_id.of_string token_str
          in
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
                    Option.value_map str_opt ~default:Set_or_keep.Keep
                      ~f:(fun str -> Set_or_keep.Set (F.of_string str)))
              in
              Zkapp_state.V.of_list_exn fields
            in
            let%bind delegate =
              let%map pk_opt =
                Option.value_map delegate_id ~default:(return None)
                  ~f:(fun id ->
                    let%map pk =
                      pk_of_id id ~item:"fee payer update delegate"
                    in
                    Some pk)
              in
              Set_or_keep.of_option pk_opt
            in
            let%bind verification_key =
              let%map vk_opt =
                Option.value_map verification_key_id ~default:(return None)
                  ~f:(fun id ->
                    let%map vk =
                      query_db ~item:"fee payer update verification key"
                        ~f:(fun db ->
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
                             ( module Pickles.Side_loaded.Verification_key.Stable
                                      .Latest )
                             s
                         in
                         let hash = Pickles.Backend.Tick.Field.of_string hash in
                         { With_hash.data; hash }
                     | Error (`Msg err) ->
                         failwithf
                           "Could not Base64-decode verification key: %s" err ()))
            in
            let%bind permissions =
              let%map perms_opt =
                Option.value_map permissions_id ~default:(return None)
                  ~f:(fun id ->
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
                      query_db ~item:"fee payer update permissions"
                        ~f:(fun db -> Processor.Zkapp_permissions.load db id)
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
                Option.value_map zkapp_uri_id ~default:(return None)
                  ~f:(fun id ->
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
            let sgn =
              if Int64.is_negative balance_change then Sgn.Neg else Sgn.Pos
            in
            Currency.Amount.Signed.create ~magnitude ~sgn
          in
          let load_events id =
            let%map fields_list =
              (* each id refers to an item in 'zkapp_state_data_array' *)
              let%bind field_array_ids =
                query_db ~item:"events arrays" ~f:(fun db ->
                    Processor.Zkapp_events.load db id)
              in
              Deferred.List.map (Array.to_list field_array_ids)
                ~f:(fun array_id ->
                  let%bind field_ids =
                    query_db ~item:"events array" ~f:(fun db ->
                        Processor.Zkapp_state_data_array.load db array_id)
                  in
                  Deferred.List.map (Array.to_list field_ids)
                    ~f:(fun field_id ->
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
                    Some (Mina_base.Frozen_ledger_hash.of_base58_check_exn hash))
              in
              Or_ignore.of_option hash_opt
            in
            let%bind timestamp =
              let%map ts_db_opt =
                Option.value_map timestamp_id ~default:(return None)
                  ~f:(fun id ->
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
                      : Block_time.t
                        Mina_base.Zkapp_precondition.Closed_interval.t ))
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
                      : Unsigned.UInt32.t
                        Mina_base.Zkapp_precondition.Closed_interval.t ))
              in
              Or_ignore.of_option bl_opt
            in
            let%bind blockchain_length =
              get_length_bounds blockchain_length_id
            in
            let%bind min_window_density =
              get_length_bounds min_window_density_id
            in
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
                      : Currency.Amount.t
                        Mina_base.Zkapp_precondition.Closed_interval.t ))
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
                    Some
                      ( { lower; upper }
                        : _ Mina_base.Zkapp_precondition.Closed_interval.t ))
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
                    Option.value_map hash_id ~default:(return None)
                      ~f:(fun id ->
                        let%map hash_str =
                          query_db ~item:"epoch ledger hash" ~f:(fun db ->
                              Processor.Snarked_ledger_hash.load db id)
                        in
                        Some
                          (Mina_base.Frozen_ledger_hash.of_base58_check_exn
                             hash_str))
                  in
                  Or_ignore.of_option hash_opt
                in
                let%bind total_currency = get_amount_bounds total_currency_id in
                return
                  ( { hash; total_currency }
                    : ( Frozen_ledger_hash.t Or_ignore.t
                      , Currency.Amount.t Zkapp_precondition.Numeric.t )
                      Mina_base.Epoch_ledger.Poly.t )
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
                ( { ledger
                  ; seed
                  ; start_checkpoint
                  ; lock_checkpoint
                  ; epoch_length
                  }
                  : Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.t )
            in
            let%bind staking_epoch_data =
              get_staking_data staking_epoch_data_id
            in
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
                : Mina_base.Zkapp_precondition.Protocol_state.t )
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
                    Option.value_map balance_id ~default:(return None)
                      ~f:(fun id ->
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
                        Some
                          ( { lower; upper }
                            : _ Zkapp_precondition.Closed_interval.t ))
                  in
                  Or_ignore.of_option balance_opt
                in
                let%bind nonce =
                  let%map nonce_opt =
                    Option.value_map nonce_id ~default:(return None)
                      ~f:(fun id ->
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
                        Some
                          ( { lower; upper }
                            : _ Zkapp_precondition.Closed_interval.t ))
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
                    Deferred.List.map (Array.to_list field_ids)
                      ~f:(fun id_opt ->
                        Option.value_map id_opt ~default:(return None)
                          ~f:(fun id ->
                            let%map field_str =
                              query_db ~item:"precondition account state field"
                                ~f:(fun db ->
                                  Processor.Zkapp_state_data.load db id)
                            in
                            Some (Zkapp_basic.F.of_string field_str)))
                  in
                  List.map fields ~f:Or_ignore.of_option
                  |> Zkapp_state.V.of_list_exn
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
        in
        return (body : Party.Body.t)
      in
      let%bind fee_payer =
        let%bind body_id =
          query_db ~item:"zkapp fee payer" ~f:(fun db ->
              Processor.Zkapp_fee_payers.load db zkapp_cmd.zkapp_fee_payer_id)
        in
        let%bind ({ public_key
                  ; token_id = _
                  ; update
                  ; balance_change
                  ; increment_nonce = _
                  ; events
                  ; sequence_events
                  ; call_data
                  ; call_depth
                  ; protocol_state_precondition
                  ; account_precondition
                  ; use_full_commitment = _
                  }
                   : Party.Body.t) =
          get_party_body body_id
        in
        (* convert Party.Body.t to Party.Body.Fee_payer.t *)
        let balance_change =
          Currency.Fee.of_uint64
            (balance_change.magnitude |> Currency.Amount.to_uint64)
        in
        let account_precondition =
          match account_precondition with
          | Nonce nonce ->
              Mina_numbers.Account_nonce.of_uint32 nonce
          | Full _ | Accept ->
              failwith "Expected a nonce for fee payer account precondition"
        in
        return
          ( { public_key
            ; token_id = ()
            ; update
            ; balance_change
            ; increment_nonce = ()
            ; events
            ; sequence_events
            ; call_data
            ; call_depth
            ; protocol_state_precondition
            ; account_precondition
            ; use_full_commitment = ()
            }
            : Party.Body.Fee_payer.t )
      in
      let%bind other_parties =
        Deferred.List.map
          (Array.to_list zkapp_cmd.zkapp_other_parties_ids)
          ~f:get_party_body
      in
      let memo = zkapp_cmd.memo |> Signed_command_memo.of_base58_check_exn in
      let hash = zkapp_cmd.hash |> Transaction_hash.of_base58_check_exn in
      let%bind block_zkapp_cmd =
        query_db ~item:"block zkapp commands" ~f:(fun db ->
            Processor.Block_and_zkapp_command.load db ~block_id
              ~zkapp_command_id ~sequence_no)
      in
      let status = block_zkapp_cmd.status in
      let%bind failure_reasons =
        Option.value_map block_zkapp_cmd.failure_reasons_ids
          ~default:(return None) ~f:(fun ids ->
            let%map display =
              Deferred.List.map (Array.to_list ids) ~f:(fun id ->
                  let%map { index; failures } =
                    query_db ~item:"party failures" ~f:(fun db ->
                        Processor.Zkapp_party_failures.load db id)
                  in
                  ( index
                  , List.map (Array.to_list failures) ~f:(fun s ->
                        match Transaction_status.Failure.of_string s with
                        | Ok failure ->
                            failure
                        | Error err ->
                            failwithf
                              "Invalid party transaction status, error: %s" err
                              ()) ))
            in
            Some display)
      in
      return
        { Extensional.Zkapp_command.sequence_no
        ; fee_payer
        ; other_parties
        ; memo
        ; hash
        ; status
        ; failure_reasons
        })

let check_state_hash ~logger state_hash_opt =
  match state_hash_opt with
  | None ->
      ()
  | Some state_hash -> (
      match State_hash.of_base58_check state_hash with
      | Ok _ ->
          ()
      | Error err ->
          [%log error] "Error decoding state hash"
            ~metadata:
              [ ("state_hash", `String state_hash)
              ; ("error", Error_json.error_to_yojson err)
              ] ;
          Core.exit 1 )

let main ~archive_uri ~start_state_hash_opt ~end_state_hash_opt ~all_blocks () =
  ( match (start_state_hash_opt, end_state_hash_opt, all_blocks) with
  | None, None, true | None, Some _, false | Some _, Some _, false ->
      ()
  | Some _, None, true ->
      failwith "If --all-blocks is given, do not also give --start-state-hash"
  | _, None, false | _, Some _, true ->
      failwith "Must specify exactly one of --end-state-hash and --all-blocks"
  ) ;
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  (* sanity-check input state hashes *)
  check_state_hash ~logger start_state_hash_opt ;
  check_state_hash ~logger end_state_hash_opt ;
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      let%bind blocks =
        if all_blocks then (
          [%log info] "Querying for all blocks" ;
          query_db pool
            ~f:(fun db -> Sql.Subchain.all_blocks db)
            ~item:"all blocks" )
        else
          match (start_state_hash_opt, end_state_hash_opt) with
          | None, Some end_state_hash ->
              [%log info]
                "Querying for subchain to end block with given state hash" ;
              let%map blocks =
                query_db pool
                  ~f:(fun db ->
                    Sql.Subchain.start_from_unparented db ~end_state_hash)
                  ~item:"blocks starting from unparented"
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash)
              in
              if not end_block_found then (
                [%log error]
                  "No subchain available from an unparented block (possibly \
                   the genesis block) to block with given end state hash" ;
                Core.exit 1 ) ;
              blocks
          | Some start_state_hash, Some end_state_hash ->
              [%log info]
                "Querying for subchain from start block to end block with \
                 given state hashes" ;
              let%map blocks =
                query_db pool
                  ~f:(fun db ->
                    Sql.Subchain.start_from_specified db ~start_state_hash
                      ~end_state_hash)
                  ~item:"blocks starting from specified"
              in
              let start_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash start_state_hash)
              in
              let end_block_found =
                List.exists blocks ~f:(fun block ->
                    String.equal block.state_hash end_state_hash)
              in
              if not (start_block_found && end_block_found) then (
                [%log error]
                  "No subchain with given start and end state hashes \
                   available; try omitting the start state hash, to get a \
                   chain from an unparented block to the block with the end \
                   state hash" ;
                Core.exit 1 ) ;
              blocks
          | _ ->
              (* unreachable *)
              failwith "Unexpected flag combination"
      in
      let%bind extensional_blocks =
        Deferred.List.map blocks ~f:(fill_in_block pool)
      in
      let num_blocks = List.length extensional_blocks in
      if all_blocks then [%log info] "Found %d blocks" num_blocks
      else [%log info] "Found a subchain of length %d" num_blocks ;
      [%log info] "Querying for user commands in blocks" ;
      let%bind blocks_with_user_cmds =
        Deferred.List.map extensional_blocks ~f:(fun block ->
            let%map unsorted_user_cmds =
              fill_in_user_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let user_cmds =
              List.sort unsorted_user_cmds
                ~compare:(fun (cmd1 : Extensional.User_command.t) cmd2 ->
                  Int.compare cmd1.sequence_no cmd2.sequence_no)
            in
            { block with user_cmds })
      in
      [%log info] "Querying for internal commands in blocks" ;
      let%bind blocks_with_internal_cmds =
        Deferred.List.map blocks_with_user_cmds ~f:(fun block ->
            let%map unsorted_internal_cmds =
              fill_in_internal_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let internal_cmds =
              List.sort unsorted_internal_cmds
                ~compare:(fun (cmd1 : Extensional.Internal_command.t) cmd2 ->
                  [%compare: int * int]
                    (cmd1.sequence_no, cmd1.secondary_sequence_no)
                    (cmd2.sequence_no, cmd2.secondary_sequence_no))
            in
            { block with internal_cmds })
      in
      let%bind blocks_with_zkapp_cmds =
        Deferred.List.map blocks_with_internal_cmds ~f:(fun block ->
            let%map unsorted_zkapp_cmds =
              fill_in_zkapp_commands pool block.state_hash
            in
            (* sort, to give block a canonical representation *)
            let zkapp_cmds =
              List.sort unsorted_zkapp_cmds
                ~compare:(fun (cmd1 : Extensional.Zkapp_command.t) cmd2 ->
                  Int.compare cmd1.sequence_no cmd2.sequence_no)
            in
            { block with zkapp_cmds })
      in
      [%log info] "Querying for zkapp commands in blocks" ;
      let%bind blocks_with_accounts_accessed =
        Deferred.List.map blocks_with_zkapp_cmds ~f:(fun block ->
            let%map accounts_accessed =
              fill_in_accounts_accessed pool block.state_hash
            in
            { block with accounts_accessed })
      in
      let%bind blocks_with_accounts_created =
        Deferred.List.map blocks_with_accounts_accessed ~f:(fun block ->
            let%map accounts_created =
              fill_in_accounts_created pool block.state_hash
            in
            { block with accounts_created })
      in
      [%log info] "Writing blocks" ;
      let%map () =
        Deferred.List.iter blocks_with_accounts_created ~f:(fun block ->
            [%log info] "Writing block with $state_hash"
              ~metadata:
                [ ("state_hash", State_hash.to_yojson block.state_hash) ] ;
            let output_file =
              State_hash.to_base58_check block.state_hash ^ ".json"
            in
            Async_unix.Writer.with_file output_file ~f:(fun writer ->
                return
                  (Async.fprintf writer "%s\n%!"
                     ( Extensional.Block.to_yojson block
                     |> Yojson.Safe.pretty_to_string ))))
      in
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Extract blocks from an archive db, either all blocks, or from a \
           subchain"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and start_state_hash_opt =
           Param.flag "--start-state-hash"
             ~doc:
               "State hash of the block that begins a chain (default: start at \
                the block closest to the end block without a parent, possibly \
                the genesis block)"
             Param.(optional string)
         and end_state_hash_opt =
           Param.flag "--end-state-hash"
             ~doc:"State hash of the block that ends a chain"
             Param.(optional string)
         and all_blocks =
           Param.flag "--all-blocks" Param.no_arg
             ~doc:"Extract all blocks in the archive database"
         in
         main ~archive_uri ~start_state_hash_opt ~end_state_hash_opt ~all_blocks)))
