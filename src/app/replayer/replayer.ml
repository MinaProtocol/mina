(* replayer.ml -- replay transactions from archive node database *)

open Core
open Async
open Mina_base
module Ledger = Mina_ledger.Ledger
module Processor = Archive_lib.Processor
module Load_data = Archive_lib.Load_data
module Account_comparables = Comparable.Make_binable (Account.Stable.Latest)
module Account_set = Account_comparables.Set

(* identify a target block B containing staking and next epoch ledgers
   to be used in a hard fork, by giving its state hash

   from B, we choose a predecessor block B_fork, which is the block to
   fork from

   we replay all commands, one by one, from the genesis block through
   B_fork

   when the Merkle root of the replay ledger matches one of the
   epoch ledger hashes, we make a copy of the replay ledger to
   become that target epoch ledger

   when all commands from a block have been replayed, we verify
   that the Merkle root of the replay ledger matches the stored
   ledger hash in the archive database
*)

type input =
  { target_epoch_ledgers_state_hash : State_hash.t option [@default None]
  ; start_slot_since_genesis : int64 [@default 0L]
  ; genesis_ledger : Runtime_config.Ledger.t
  ; first_pass_ledger_hashes : Ledger_hash.t list [@default []]
  ; last_snarked_ledger_hash : Ledger_hash.t option [@default None]
  }
[@@deriving yojson]

type output =
  { target_epoch_ledgers_state_hash : State_hash.t
  ; target_fork_state_hash : State_hash.t
  ; target_genesis_ledger : Runtime_config.Ledger.t
  ; target_epoch_data : Runtime_config.Epoch_data.t
  }
[@@deriving yojson]

module type Get_command_ids = sig
  val run :
       Caqti_async.connection
    -> state_hash:string
    -> start_slot:int64
    -> (int list, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t
end

let error_count = ref 0

let json_ledger_hash_of_ledger ledger =
  Ledger_hash.to_yojson @@ Ledger.merkle_root ledger

let create_ledger_as_list ledger =
  let%map accounts = Ledger.to_list ledger in
  List.map accounts ~f:(fun acc ->
      Genesis_ledger_helper.Accounts.Single.of_account acc None )

module First_pass_ledger_hashes = struct
  (* ledger hashes after 1st pass, indexed by order of occurrence *)

  module T = struct
    type t = Ledger_hash.Stable.Latest.t * int
    [@@deriving bin_io_unversioned, compare, sexp, hash]
  end

  include T
  include Hashable.Make_binable (T)

  let hash_set = Hash_set.create ()

  let add =
    let count = ref 0 in
    fun ledger_hash ->
      Base.Hash_set.add hash_set (ledger_hash, !count) ;
      incr count

  let find ledger_hash =
    Base.Hash_set.find hash_set ~f:(fun (hash, _n) ->
        Ledger_hash.equal hash ledger_hash )

  (* once we find a snarked ledger hash corresponding to a ledger hash, don't need to store earlier ones *)
  let flush_older_than ndx =
    let elts = Base.Hash_set.to_list hash_set in
    List.iter elts ~f:(fun ((_hash, n) as elt) ->
        if n < ndx then Base.Hash_set.remove hash_set elt )

  let get_last_snarked_hash, set_last_snarked_hash =
    let last_snarked_hash = ref Ledger_hash.empty_hash in
    let getter () = !last_snarked_hash in
    let setter hash = last_snarked_hash := hash in
    (getter, setter)
end

let create_output ~target_epoch_ledgers_state_hash ~target_fork_state_hash
    ~ledger ~staking_epoch_ledger ~staking_seed ~next_epoch_ledger ~next_seed
    (input_genesis_ledger : Runtime_config.Ledger.t) =
  let%bind genesis_ledger_as_list = create_ledger_as_list ledger in
  let target_genesis_ledger =
    { input_genesis_ledger with base = Accounts genesis_ledger_as_list }
  in
  let%bind staking_epoch_ledger_as_list =
    create_ledger_as_list staking_epoch_ledger
  in
  let%map next_epoch_ledger_as_list = create_ledger_as_list next_epoch_ledger in
  let target_staking_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      { input_genesis_ledger with base = Accounts staking_epoch_ledger_as_list }
    in
    { ledger; seed = staking_seed }
  in
  let target_next_epoch_data : Runtime_config.Epoch_data.Data.t =
    let ledger =
      { input_genesis_ledger with base = Accounts next_epoch_ledger_as_list }
    in
    { ledger; seed = next_seed }
  in
  let target_epoch_data : Runtime_config.Epoch_data.t =
    { staking = target_staking_epoch_data; next = Some target_next_epoch_data }
  in
  { target_fork_state_hash
  ; target_epoch_ledgers_state_hash
  ; target_genesis_ledger
  ; target_epoch_data
  }

let create_replayer_checkpoint ~ledger ~start_slot_since_genesis :
    input Deferred.t =
  let%map accounts = create_ledger_as_list ledger in
  let genesis_ledger : Runtime_config.Ledger.t =
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = Some (Ledger.merkle_root ledger |> Ledger_hash.to_base58_check)
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some true
    }
  in
  let first_pass_ledger_hashes =
    let elts = Base.Hash_set.to_list First_pass_ledger_hashes.hash_set in
    List.sort elts ~compare:(fun (_h1, n1) (_h2, n2) -> Int.compare n1 n2)
    |> List.map ~f:(fun (h, _n) -> h)
  in
  let last_snarked_ledger_hash =
    Some (First_pass_ledger_hashes.get_last_snarked_hash ())
  in
  { target_epoch_ledgers_state_hash = None
  ; start_slot_since_genesis
  ; genesis_ledger
  ; first_pass_ledger_hashes
  ; last_snarked_ledger_hash
  }

(* map from global slots (since genesis) to state hash, ledger hash, snarked ledger hash triples *)
let global_slot_hashes_tbl :
    (Int64.t, State_hash.t * Ledger_hash.t * Frozen_ledger_hash.t) Hashtbl.t =
  Int64.Table.create ()

let get_slot_hashes slot = Hashtbl.find global_slot_hashes_tbl slot

let process_block_infos_of_state_hash ~logger pool ~state_hash ~start_slot ~f =
  match%bind
    Caqti_async.Pool.use
      (fun db -> Sql.Block_info.run db ~state_hash ~start_slot)
      pool
  with
  | Ok block_infos ->
      f block_infos
  | Error msg ->
      [%log error] "Error getting block information for state hash"
        ~metadata:
          [ ("error", `String (Caqti_error.show msg))
          ; ("state_hash", `String state_hash)
          ] ;
      exit 1

let update_epoch_ledger ~logger ~name ~ledger ~epoch_ledger epoch_ledger_hash =
  let epoch_ledger_hash = Ledger_hash.of_base58_check_exn epoch_ledger_hash in
  let curr_ledger_hash = Ledger.merkle_root ledger in
  if Frozen_ledger_hash.equal epoch_ledger_hash curr_ledger_hash then (
    [%log info]
      "Creating %s epoch ledger from ledger with Merkle root matching epoch \
       ledger hash %s"
      name
      (Ledger_hash.to_base58_check epoch_ledger_hash) ;
    (* Ledger.copy doesn't actually copy, roll our own here *)
    let%map accounts = Ledger.to_list ledger in
    let epoch_ledger = Ledger.create ~depth:(Ledger.depth ledger) () in
    List.iter accounts ~f:(fun account ->
        let pk = Account.public_key account in
        let token = Account.token_id account in
        let account_id = Account_id.create pk token in
        match Ledger.get_or_create_account epoch_ledger account_id account with
        | Ok (`Added, _loc) ->
            ()
        | Ok (`Existed, _loc) ->
            failwithf
              "When creating epoch ledger, account with public key %s and \
               token %s already existed"
              (Signature_lib.Public_key.Compressed.to_string pk)
              (Token_id.to_string token) ()
        | Error err ->
            Error.tag_arg err
              "When creating epoch ledger, error when adding account"
              (("public_key", pk), ("token", token))
              [%sexp_of:
                (string * Signature_lib.Public_key.Compressed.t)
                * (string * Token_id.t)]
            |> Error.raise ) ;
    epoch_ledger )
  else return epoch_ledger

let update_staking_epoch_data ~logger pool ~ledger ~last_block_id
    ~staking_epoch_ledger ~staking_seed =
  let query_db = Mina_caqti.query pool in
  let%bind state_hash =
    query_db ~f:(fun db -> Sql.Block.get_state_hash db last_block_id)
  in
  let%bind staking_epoch_id =
    query_db ~f:(fun db ->
        Sql.Epoch_data.get_staking_epoch_data_id db state_hash )
  in
  let%bind { epoch_ledger_hash; epoch_data_seed } =
    query_db ~f:(fun db -> Sql.Epoch_data.get_epoch_data db staking_epoch_id)
  in
  let%map ledger =
    update_epoch_ledger ~logger ~name:"staking" ~ledger
      ~epoch_ledger:!staking_epoch_ledger epoch_ledger_hash
  in
  staking_epoch_ledger := ledger ;
  staking_seed := epoch_data_seed

let update_next_epoch_data ~logger pool ~ledger ~last_block_id
    ~next_epoch_ledger ~next_seed =
  let query_db = Mina_caqti.query pool in
  let%bind state_hash =
    query_db ~f:(fun db -> Sql.Block.get_state_hash db last_block_id)
  in
  let%bind next_epoch_id =
    query_db ~f:(fun db -> Sql.Epoch_data.get_next_epoch_data_id db state_hash)
  in
  let%bind { epoch_ledger_hash; epoch_data_seed } =
    query_db ~f:(fun db -> Sql.Epoch_data.get_epoch_data db next_epoch_id)
  in
  let%map ledger =
    update_epoch_ledger ~logger ~name:"next" ~ledger
      ~epoch_ledger:!next_epoch_ledger epoch_ledger_hash
  in
  next_epoch_ledger := ledger ;
  next_seed := epoch_data_seed

(* cache of fee transfers for coinbases *)
module Fee_transfer_key = struct
  module T = struct
    type t = int64 * int * int [@@deriving hash, sexp, compare]
  end

  type t = T.t

  include Hashable.Make (T)
end

let fee_transfer_tbl : (Fee_transfer_key.t, Coinbase_fee_transfer.t) Hashtbl.t =
  Fee_transfer_key.Table.create ()

let cache_fee_transfer_via_coinbase pool (internal_cmd : Sql.Internal_command.t)
    =
  match internal_cmd.typ with
  | "fee_transfer_via_coinbase" ->
      let%map receiver_pk = Load_data.pk_of_id pool internal_cmd.receiver_id in
      let fee =
        Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 internal_cmd.fee)
      in
      let fee_transfer = Coinbase_fee_transfer.create ~receiver_pk ~fee in
      Hashtbl.add_exn fee_transfer_tbl
        ~key:
          ( internal_cmd.global_slot_since_genesis
          , internal_cmd.sequence_no
          , internal_cmd.secondary_sequence_no )
        ~data:fee_transfer
  | _ ->
      Deferred.unit

module User_command_helpers = struct
  let body_of_sql_user_cmd pool
      ({ typ; source_id = _; receiver_id; amount; global_slot_since_genesis; _ } :
        Sql.User_command.t ) : Signed_command_payload.Body.t Deferred.t =
    let open Signed_command_payload.Body in
    let open Deferred.Let_syntax in
    let%map receiver_pk = Load_data.pk_of_id pool receiver_id in
    let amount =
      Option.map amount
        ~f:(Fn.compose Currency.Amount.of_uint64 Unsigned.UInt64.of_int64)
    in
    (* possibilities from user_command_type enum in SQL schema *)
    match typ with
    | "payment" ->
        if Option.is_none amount then
          failwithf "Payment at global slot since genesis %Ld has NULL amount"
            global_slot_since_genesis () ;
        let amount = Option.value_exn amount in
        Payment Payment_payload.Poly.{ receiver_pk; amount }
    | "delegation" ->
        Stake_delegation
          (Stake_delegation.Set_delegate { new_delegate = receiver_pk })
    | _ ->
        failwithf "Invalid user command type: %s" typ ()
end

(* internal commands in result are remaining internal commands to process

   in most cases, those are the input list `ics`
   when we combine fee transfers, it's the tail of `ics`
*)
let internal_cmds_to_transaction ~logger ~pool (ic : Sql.Internal_command.t)
    (ics : Sql.Internal_command.t list) :
    (Mina_transaction.Transaction.t option * Sql.Internal_command.t list)
    Deferred.t =
  [%log spam]
    "Converting internal command (%s) with global slot since genesis %Ld, \
     sequence number %d, and secondary sequence number %d to transaction"
    ic.typ ic.global_slot_since_genesis ic.sequence_no ic.secondary_sequence_no ;
  let fee_transfer_of_cmd (cmd : Sql.Internal_command.t) =
    if not (String.equal cmd.typ "fee_transfer") then
      failwithf "Expected fee transfer, got: %s" cmd.typ () ;
    let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 cmd.fee) in
    let%map receiver_pk = Load_data.pk_of_id pool cmd.receiver_id in
    let fee_token = Token_id.default in
    Fee_transfer.Single.create ~receiver_pk ~fee ~fee_token
  in
  match ics with
  | ic2 :: ics2
    when Int64.equal ic.global_slot_since_genesis ic2.global_slot_since_genesis
         && Int.equal ic.sequence_no ic2.sequence_no
         && String.equal ic.typ "fee_transfer"
         && String.equal ic.typ ic2.typ -> (
      (* combining situation 2
         two fee transfer commands with same global slot since genesis, sequence number
      *)
      [%log spam]
        "Combining two fee transfers at global slot since genesis %Ld with \
         sequence number %d"
        ic.global_slot_since_genesis ic.sequence_no ;
      let%bind fee_transfer1 = fee_transfer_of_cmd ic in
      let%map fee_transfer2 = fee_transfer_of_cmd ic2 in
      match Fee_transfer.create fee_transfer1 (Some fee_transfer2) with
      | Ok ft ->
          (Some (Mina_transaction.Transaction.Fee_transfer ft), ics2)
      | Error err ->
          Error.tag err ~tag:"Could not create combined fee transfer"
          |> Error.raise )
  | _ -> (
      match ic.typ with
      | "fee_transfer" -> (
          let%map fee_transfer = fee_transfer_of_cmd ic in
          match Fee_transfer.create fee_transfer None with
          | Ok ft ->
              (Some (Mina_transaction.Transaction.Fee_transfer ft), ics)
          | Error err ->
              Error.tag err ~tag:"Could not create fee transfer" |> Error.raise
          )
      | "coinbase" -> (
          let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 ic.fee) in
          let amount =
            Currency.Fee.to_uint64 fee |> Currency.Amount.of_uint64
          in
          (* combining situation 1: add cached coinbase fee transfer, if it exists *)
          let fee_transfer =
            Hashtbl.find fee_transfer_tbl
              ( ic.global_slot_since_genesis
              , ic.sequence_no
              , ic.secondary_sequence_no )
          in
          if Option.is_some fee_transfer then
            [%log spam]
              "Coinbase transaction at global slot since genesis %Ld, sequence \
               number %d, and secondary sequence number %d contains a fee \
               transfer"
              ic.global_slot_since_genesis ic.sequence_no
              ic.secondary_sequence_no ;
          let%map receiver = Load_data.pk_of_id pool ic.receiver_id in
          match Coinbase.create ~amount ~receiver ~fee_transfer with
          | Ok cb ->
              (Some (Mina_transaction.Transaction.Coinbase cb), ics)
          | Error err ->
              Error.tag err ~tag:"Could not create coinbase" |> Error.raise )
      | "fee_transfer_via_coinbase" ->
          (* handled in the coinbase case *)
          return (None, ics)
      | ty ->
          failwithf "Unknown internal command type: %s" ty () )

let user_command_to_transaction ~logger ~pool (cmd : Sql.User_command.t) :
    Mina_transaction.Transaction.t Deferred.t =
  [%log spam]
    "Converting user command (%s) with nonce %Ld, global slot since genesis \
     %Ld, and sequence number %d to transaction"
    cmd.typ cmd.nonce cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind body = User_command_helpers.body_of_sql_user_cmd pool cmd in
  let%bind fee_payer_pk = Load_data.pk_of_id pool cmd.fee_payer_id in
  let memo = Signed_command_memo.of_base58_check_exn cmd.memo in
  let valid_until =
    Option.map cmd.valid_until ~f:(fun slot ->
        Mina_numbers.Global_slot_since_genesis.of_uint32
        @@ Unsigned.UInt32.of_int64 slot )
  in
  let payload =
    Signed_command_payload.create
      ~fee:(Currency.Fee.of_uint64 @@ Unsigned.UInt64.of_int64 cmd.fee)
      ~fee_payer_pk
      ~nonce:(Unsigned.UInt32.of_int64 cmd.nonce)
      ~valid_until ~memo ~body
  in
  (* when applying the transaction, there's a check that the fee payer and
     signer keys are the same; since this transaction was accepted, we know
     those keys are the same
  *)
  let signer = Signature_lib.Public_key.decompress_exn fee_payer_pk in
  let signed_cmd =
    Signed_command.Poly.{ payload; signer; signature = Signature.dummy }
  in
  let user_cmd = User_command.Signed_command signed_cmd in
  return @@ Mina_transaction.Transaction.Command user_cmd

let get_parent_state_view ~pool block_id =
  let%bind state_view =
    let query_db = Mina_caqti.query pool in
    let%bind parent_id =
      query_db ~f:(fun db -> Sql.Block.get_parent_id db block_id)
    in
    let%bind parent_block =
      query_db ~f:(fun db -> Processor.Block.load db ~id:parent_id)
    in
    let%bind snarked_ledger_hash_str =
      query_db ~f:(fun db ->
          Sql.Snarked_ledger_hashes.run db parent_block.snarked_ledger_hash_id )
    in
    let snarked_ledger_hash =
      Frozen_ledger_hash.of_base58_check_exn snarked_ledger_hash_str
    in
    let blockchain_length =
      parent_block.height |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Length.of_uint32
    in
    let min_window_density =
      parent_block.min_window_density |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Length.of_uint32
    in
    let total_currency =
      Currency.Amount.of_string parent_block.total_currency
    in
    let global_slot_since_genesis =
      parent_block.global_slot_since_genesis |> Unsigned.UInt32.of_int64
      |> Mina_numbers.Global_slot_since_genesis.of_uint32
    in
    let epoch_data_of_raw_epoch_data (raw_epoch_data : Processor.Epoch_data.t) :
        Mina_base.Epoch_data.Value.t Deferred.t =
      let%bind hash_str =
        query_db ~f:(fun db ->
            Sql.Snarked_ledger_hashes.run db raw_epoch_data.ledger_hash_id )
      in
      let hash = Frozen_ledger_hash.of_base58_check_exn hash_str in
      let total_currency =
        Currency.Amount.of_string raw_epoch_data.total_currency
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
    in
    let%bind staking_epoch_raw =
      query_db ~f:(fun db ->
          Processor.Epoch_data.load db parent_block.staking_epoch_data_id )
    in
    let%bind (staking_epoch_data : Mina_base.Epoch_data.Value.t) =
      epoch_data_of_raw_epoch_data staking_epoch_raw
    in
    let%bind next_epoch_raw =
      query_db ~f:(fun db ->
          Processor.Epoch_data.load db parent_block.staking_epoch_data_id )
    in
    let%bind next_epoch_data = epoch_data_of_raw_epoch_data next_epoch_raw in
    return
      { Zkapp_precondition.Protocol_state.Poly.snarked_ledger_hash
      ; blockchain_length
      ; min_window_density
      ; total_currency
      ; global_slot_since_genesis
      ; staking_epoch_data
      ; next_epoch_data
      }
  in
  return state_view

let zkapp_command_to_transaction ~proof_cache_db ~logger ~pool
    (cmd : Sql.Zkapp_command.t) : Mina_transaction.Transaction.t Deferred.t =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let query_db = Mina_caqti.query pool in
  (* use dummy authorizations *)
  let%bind (fee_payer : Account_update.Fee_payer.t) =
    let%map (body : Account_update.Body.Fee_payer.t) =
      Load_data.get_fee_payer_body ~pool cmd.zkapp_fee_payer_body_id
    in
    Account_update.Fee_payer.make ~body ~authorization:Signature.dummy
  in
  let nonce_str = Mina_numbers.Account_nonce.to_string fee_payer.body.nonce in
  [%log spam]
    "Converting zkApp command with fee payer nonce %s, global slot since \
     genesis %Ld, and sequence number %d to transaction"
    nonce_str cmd.global_slot_since_genesis cmd.sequence_no ;
  let%bind (account_updates : Account_update.Simple.t list) =
    Deferred.List.map (Array.to_list cmd.zkapp_account_updates_ids)
      ~f:(fun id ->
        let%bind { body_id } =
          query_db ~f:(fun db -> Processor.Zkapp_account_update.load db id)
        in
        let%map body =
          Archive_lib.Load_data.get_account_update_body ~pool body_id
        in
        let authorization =
          match body.authorization_kind with
          | Proof _ ->
              Control.Poly.Proof (Lazy.force Proof.transaction_dummy)
          | Signature ->
              Signature Signature.dummy
          | None_given ->
              None_given
        in
        Account_update.with_no_aux ~body ~authorization )
  in
  let memo = Signed_command_memo.of_base58_check_exn cmd.memo in
  let zkapp_command =
    Zkapp_command.of_simple ~signature_kind ~proof_cache_db
      { fee_payer; account_updates; memo }
  in
  return
  @@ Mina_transaction.Transaction.Command
       (User_command.Zkapp_command zkapp_command)

let find_canonical_chain ~logger pool slot =
  (* find longest canonical chain
     a slot may represent several blocks, only one of which can be on canonical chain
     starting with max slot, look for chain, decrementing slot until chain found
  *)
  let query_db = Mina_caqti.query pool in
  let find_state_hash_chain state_hash =
    match%map query_db ~f:(fun db -> Sql.Block.get_chain db state_hash) with
    | [] ->
        [%log spam] "Block with state hash %s is not along canonical chain"
          state_hash ;
        None
    | _ ->
        Some state_hash
  in
  let%bind state_hashes =
    query_db ~f:(fun db -> Sql.Block.get_state_hashes_by_slot db slot)
  in
  Deferred.List.find_map state_hashes ~f:find_state_hash_chain

let try_slot ~logger pool slot =
  let num_tries = 5 in
  let rec go ~slot ~tries_left =
    if tries_left <= 0 then (
      [%log fatal] "Could not find canonical chain after trying %d slots"
        num_tries ;
      Core_kernel.exit 1 ) ;
    match%bind find_canonical_chain ~logger pool slot with
    | None ->
        go ~slot:(Int64.pred slot) ~tries_left:(tries_left - 1)
    | Some state_hash ->
        [%log spam]
          "Found possible canonical chain to target state hash %s at slot %Ld"
          state_hash slot ;
        return state_hash
  in
  go ~slot ~tries_left:num_tries

let write_replayer_checkpoint ~logger ~ledger ~last_global_slot_since_genesis
    ~max_canonical_slot ~checkpoint_output_folder_opt ~checkpoint_file_prefix =
  if Int64.( <= ) last_global_slot_since_genesis max_canonical_slot then (
    (* start replaying at the slot after the one we've just finished with *)
    let start_slot_since_genesis = Int64.succ last_global_slot_since_genesis in
    let%map replayer_checkpoint =
      let%map input =
        create_replayer_checkpoint ~ledger ~start_slot_since_genesis
      in
      input_to_yojson input |> Yojson.Safe.pretty_to_string
    in
    let checkpoint_file =
      let checkpoint_filename =
        sprintf "%s-checkpoint-%Ld.json" checkpoint_file_prefix
          start_slot_since_genesis
      in
      match checkpoint_output_folder_opt with
      | Some parent ->
          Filename.concat parent checkpoint_filename
      | None ->
          checkpoint_filename
    in
    [%log info] "Writing checkpoint file"
      ~metadata:[ ("checkpoint_file", `String checkpoint_file) ] ;
    Out_channel.with_file checkpoint_file ~f:(fun oc ->
        Out_channel.output_string oc replayer_checkpoint ) )
  else (
    [%log info] "Not writing checkpoint file at slot %Ld, because not canonical"
      last_global_slot_since_genesis
      ~metadata:
        [ ("max_canonical_slot", `String (Int64.to_string max_canonical_slot)) ] ;
    Deferred.unit )

let main ~input_file ~output_file_opt ~archive_uri ~continue_on_error
    ~checkpoint_interval ~checkpoint_output_folder_opt ~checkpoint_file_prefix
    ~genesis_dir_opt ~log_json ~log_level ~log_filename ~file_log_level
    ~constraint_constants ~proof_level () =
  Cli_lib.Stdout_log.setup log_json log_level ;
  Option.iter log_filename ~f:(fun log_filename ->
      Logger.Consumer_registry.register ~id:"default"
        ~processor:(Logger.Processor.raw ~log_level:file_log_level ())
        ~transport:(Logger_file_system.evergrowing ~log_filename)
        () ) ;
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let logger = Logger.create () in
  let json = Yojson.Safe.from_file input_file in
  let input =
    match input_of_yojson json with
    | Ok inp ->
        inp
    | Error msg ->
        failwith
          (sprintf "Could not parse JSON in input file \"%s\": %s" input_file
             msg )
  in
  let archive_uri = Uri.of_string archive_uri in
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool -> (
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      (* load from runtime config in same way as daemon
         except that we don't consider loading from a tar file
      *)
      let query_db = Mina_caqti.query pool in
      let%bind packed_ledger =
        match%bind
          Genesis_ledger_helper.Ledger.load ~proof_level
            ~genesis_dir:
              (Option.value ~default:Cache_dir.autogen_path genesis_dir_opt)
            ~logger ~constraint_constants input.genesis_ledger
        with
        | Error e ->
            [%log fatal]
              "Could not load accounts from input runtime genesis ledger %s"
              (Error.to_string_hum e) ;
            exit 1
        | Ok (packed_ledger, _, _) ->
            return packed_ledger
      in
      let ledger = Lazy.force @@ Genesis_ledger.Packed.t packed_ledger in
      let epoch_ledgers_state_hash_opt =
        Option.map input.target_epoch_ledgers_state_hash
          ~f:State_hash.to_base58_check
      in
      let%bind target_state_hash =
        match epoch_ledgers_state_hash_opt with
        | Some hash ->
            return hash
        | None ->
            [%log info]
              "Searching for block with greatest height on canonical chain" ;
            let%bind max_slot =
              query_db ~f:(fun db -> Sql.Block.get_max_slot db ())
            in
            [%log info] "Maximum global slot since genesis in blocks is %Ld"
              max_slot ;
            try_slot ~logger pool max_slot
      in
      if not @@ List.is_empty input.first_pass_ledger_hashes then (
        [%log info] "Populating set of first-pass ledger hashes" ;
        List.iter input.first_pass_ledger_hashes ~f:First_pass_ledger_hashes.add
        ) ;
      Option.iter input.last_snarked_ledger_hash ~f:(fun h ->
          [%log info] "Setting last snarked ledger hash" ;
          First_pass_ledger_hashes.set_last_snarked_hash h ) ;
      [%log info]
        "Loading block information using target state hash and start slot" ;
      let%bind block_ids, oldest_block_id =
        process_block_infos_of_state_hash ~logger pool
          ~state_hash:target_state_hash
          ~start_slot:input.start_slot_since_genesis ~f:(fun block_infos ->
            let ({ id = oldest_block_id; _ } : Sql.Block_info.t) =
              Option.value_exn
                (List.min_elt block_infos ~compare:(fun bi1 bi2 ->
                     Int64.compare bi1.global_slot_since_genesis
                       bi2.global_slot_since_genesis ) )
            in
            let ids = List.map block_infos ~f:(fun { id; _ } -> id) in
            (* build mapping from global slots to state and ledger hashes *)
            let%bind () =
              Deferred.List.iter block_infos
                ~f:(fun
                     { global_slot_since_genesis
                     ; state_hash
                     ; ledger_hash
                     ; snarked_ledger_hash_id
                     ; _
                     }
                   ->
                  let%map snarked_hash =
                    query_db ~f:(fun db ->
                        Sql.Snarked_ledger_hashes.run db snarked_ledger_hash_id )
                  in

                  Hashtbl.add_exn global_slot_hashes_tbl
                    ~key:global_slot_since_genesis
                    ~data:
                      ( State_hash.of_base58_check_exn state_hash
                      , Ledger_hash.of_base58_check_exn ledger_hash
                      , Frozen_ledger_hash.of_base58_check_exn snarked_hash ) )
            in
            return (Int.Set.of_list ids, oldest_block_id) )
      in
      if Int64.equal input.start_slot_since_genesis 0L then
        (* check that genesis block is in chain to target hash                                                                                                                                                                                          assumption: genesis block occupies global slot 0

           if nonzero start slot, can't assume there's a block at that slot *)
        if Int64.Table.mem global_slot_hashes_tbl Int64.zero then
          [%log info]
            "Block chain leading to target state hash includes genesis block, \
             length = %d"
            (Int.Set.length block_ids)
        else (
          [%log fatal]
            "Block chain leading to target state hash does not include genesis \
             block" ;
          Core_kernel.exit 1 ) ;
      (* some mutable state, less painful than passing epoch ledgers throughout *)
      let staking_epoch_ledger = ref ledger in
      let next_epoch_ledger = ref ledger in
      let%bind staking_seed, next_seed =
        let slots = Int64.Table.keys global_slot_hashes_tbl in
        let least_slot =
          Option.value_exn @@ List.min_elt slots ~compare:Int64.compare
        in
        let state_hash, _ledger_hash, _snarked_hash =
          Int64.Table.find_exn global_slot_hashes_tbl least_slot
        in
        let%bind { staking_epoch_data_id; next_epoch_data_id; _ } =
          let%bind block_id =
            query_db ~f:(fun db -> Processor.Block.find db ~state_hash)
          in
          query_db ~f:(fun db -> Processor.Block.load db ~id:block_id)
        in
        let%bind { epoch_data_seed = staking_seed; _ } =
          query_db ~f:(fun db ->
              Sql.Epoch_data.get_epoch_data db staking_epoch_data_id )
        in
        let%map { epoch_data_seed = next_seed; _ } =
          query_db ~f:(fun db ->
              Sql.Epoch_data.get_epoch_data db next_epoch_data_id )
        in
        (ref staking_seed, ref next_seed)
      in
      (* end mutable state *)
      let get_command_ids (module Command_ids : Get_command_ids) name =
        match%bind
          Caqti_async.Pool.use
            (fun db ->
              Command_ids.run db ~state_hash:target_state_hash
                ~start_slot:input.start_slot_since_genesis )
            pool
        with
        | Ok ids ->
            return ids
        | Error msg ->
            [%log error] "Error getting %s command ids" name
              ~metadata:[ ("error", `String (Caqti_error.show msg)) ] ;
            exit 1
      in
      [%log info] "Loading internal command ids" ;
      let%bind internal_cmd_ids =
        get_command_ids (module Sql.Internal_command_ids) "internal"
      in
      [%log info] "Loading user command ids" ;
      let%bind user_cmd_ids =
        get_command_ids (module Sql.User_command_ids) "user"
      in
      [%log info] "Loading zkApp command ids" ;
      let%bind zkapp_cmd_ids =
        get_command_ids (module Sql.Zkapp_command_ids) "zkApp"
      in
      [%log info]
        "Obtained %d user command ids, %d internal command ids, and %d zkApp \
         command ids"
        (List.length user_cmd_ids)
        (List.length internal_cmd_ids)
        (List.length zkapp_cmd_ids) ;
      [%log info] "Loading internal commands" ;
      let%bind unsorted_internal_cmds_list =
        Deferred.List.map internal_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use
                (fun db ->
                  Sql.Internal_command.run db
                    ~start_slot:input.start_slot_since_genesis
                    ~internal_cmd_id:id )
                pool
            with
            | Ok [] ->
                failwithf "Could not find any internal commands with id: %d" id
                  ()
            | Ok internal_cmds ->
                internal_cmds
            | Error msg ->
                failwithf
                  "Error querying for internal commands with id %d, error %s" id
                  (Caqti_error.show msg) () )
      in
      let unsorted_internal_cmds = List.concat unsorted_internal_cmds_list in
      (* filter out internal commands in blocks not along chain from target state hash *)
      let filtered_internal_cmds =
        List.filter unsorted_internal_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id )
      in
      [%log info] "Will replay %d internal commands"
        (List.length filtered_internal_cmds) ;
      let sorted_internal_cmds =
        List.sort filtered_internal_cmds ~compare:(fun ic1 ic2 ->
            let tuple (ic : Sql.Internal_command.t) =
              ( ic.global_slot_since_genesis
              , ic.sequence_no
              , ic.secondary_sequence_no )
            in
            let cmp = [%compare: int64 * int * int] (tuple ic1) (tuple ic2) in
            if cmp = 0 then
              match (ic1.typ, ic2.typ) with
              | "coinbase", "fee_transfer_via_coinbase" ->
                  -1
              | "fee_transfer_via_coinbase", "coinbase" ->
                  1
              | _ ->
                  failwith
                    "Two internal commands have the same global slot since \
                     genesis %Ld, sequence no %d, and secondary sequence no \
                     %d, but are not a coinbase and fee transfer via coinbase"
            else cmp )
      in
      (* populate cache of fee transfer via coinbase items *)
      [%log info] "Populating fee transfer via coinbase cache" ;
      let%bind () =
        Deferred.List.iter sorted_internal_cmds
          ~f:(cache_fee_transfer_via_coinbase pool)
      in
      [%log info] "Loading user commands" ;
      let%bind (unsorted_user_cmds_list : Sql.User_command.t list list) =
        Deferred.List.map user_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use (fun db -> Sql.User_command.run db id) pool
            with
            | Ok [] ->
                failwithf "Expected at least one user command with id %d" id ()
            | Ok user_cmds ->
                user_cmds
            | Error msg ->
                failwithf
                  "Error querying for user commands with id %d, error %s" id
                  (Caqti_error.show msg) () )
      in
      let unsorted_user_cmds = List.concat unsorted_user_cmds_list in
      (* filter out user commands in blocks not along chain from target state hash *)
      let filtered_user_cmds =
        List.filter unsorted_user_cmds ~f:(fun cmd ->
            Int.Set.mem block_ids cmd.block_id )
      in
      [%log info] "Will replay %d user commands"
        (List.length filtered_user_cmds) ;
      let sorted_user_cmds =
        List.sort filtered_user_cmds ~compare:(fun uc1 uc2 ->
            let tuple (uc : Sql.User_command.t) =
              (uc.global_slot_since_genesis, uc.sequence_no)
            in
            [%compare: int64 * int] (tuple uc1) (tuple uc2) )
      in
      [%log info] "Loading zkApp commands" ;
      let%bind unsorted_zkapp_cmds_list =
        Deferred.List.map zkapp_cmd_ids ~f:(fun id ->
            let open Deferred.Let_syntax in
            match%map
              Caqti_async.Pool.use (fun db -> Sql.Zkapp_command.run db id) pool
            with
            | Ok [] ->
                failwithf "Expected at least one zkApp command with id %d" id ()
            | Ok zkapp_cmds ->
                zkapp_cmds
            | Error msg ->
                failwithf
                  "Error querying for zkApp commands with id %d, error %s" id
                  (Caqti_error.show msg) () )
      in
      let unsorted_zkapp_cmds = List.concat unsorted_zkapp_cmds_list in
      let filtered_zkapp_cmds =
        List.filter unsorted_zkapp_cmds ~f:(fun (cmd : Sql.Zkapp_command.t) ->
            Int64.( >= ) cmd.global_slot_since_genesis
              input.start_slot_since_genesis
            && Int.Set.mem block_ids cmd.block_id )
      in
      [%log info] "Will replay %d zkApp commands"
        (List.length filtered_zkapp_cmds) ;
      let sorted_zkapp_cmds =
        List.sort filtered_zkapp_cmds ~compare:(fun sc1 sc2 ->
            let tuple (sc : Sql.Zkapp_command.t) =
              (sc.global_slot_since_genesis, sc.sequence_no)
            in
            [%compare: int64 * int] (tuple sc1) (tuple sc2) )
      in
      let checkpoint_interval_i64 =
        Option.map checkpoint_interval ~f:Int64.of_int
      in
      let checkpoint_target =
        ref
          (Option.map checkpoint_interval_i64 ~f:(fun interval ->
               Int64.(input.start_slot_since_genesis + interval) ) )
      in
      let%bind max_canonical_slot =
        query_db ~f:(fun db -> Sql.Block.get_max_canonical_slot db ())
      in
      let%bind genesis_snarked_ledger_hash =
        let%map hash_str =
          query_db ~f:(fun db ->
              Sql.Block.genesis_snarked_ledger db input.start_slot_since_genesis )
        in
        Frozen_ledger_hash.of_base58_check_exn hash_str
      in
      let incr_checkpoint_target () =
        Option.iter !checkpoint_target ~f:(fun target ->
            match checkpoint_interval_i64 with
            | Some interval ->
                let new_target = Int64.(target + interval) in
                if Int64.( <= ) new_target max_canonical_slot then (
                  [%log info] "Checkpoint target was %Ld, setting to %Ld" target
                    new_target ;
                  checkpoint_target := Some new_target )
                else (
                  (* set target so it can't be reached *)
                  [%log info]
                    "Checkpoint target was %Ld, new target would be at \
                     noncanonical slot, set target to unreachable value"
                    target ;
                  checkpoint_target := Some Int64.max_value )
            | None ->
                failwith "Expected a checkpoint interval" )
      in
      let found_snarked_ledger_hash = ref false in
      (* See PR #9782. *)
      let state_hashes_to_avoid =
        (* devnet *)
        [ "3NKNU4WceYUjnQbxaUAmcHQzhGhC8ZxkYKqDKojKMpVjoj9WQZM6"
        ; "3NKvaxewhJ9e1GWvFFT83p4MA2MPFChFoQTmdJ2zeBNX9rLorGFH"
        ; "3NKNDWt8f1vVeFdBN8FCyHnAwnc5oXR18UvqriW2tQtHABTgX2tu"
        ; "3NLR1VaGKs36byogm4atXtiNVre3TtWrrg1Btt3HxGZ2mEBEN5hg"
        ; "3NL3fHu5bAqBNMmQ1Jh3HPZq7xX67WKFyAEUs2FFHJeiYxbEiq69"
        ; "3NLuEU1bJ462uzkJpQXDCo2DcpkkJLbK9kXgwpCYHDuofXo7Smrr"
        ; "3NK9ZYikzJDzXK7CPjyr7jo1S4ZGfKUKa18uTZd96X7YVcQihW1W"
        ; "3NK6PXGHsrRo8iYzWx43rtnyN2ynmZ7enWU7CMWH6oTUi5CRck7c"
        ; "3NKNrQG3DvyxDAuhudq7UhYRQ4GL7suKHcfQ3q7nUDXS1NjHyuZE"
        ; "3NKcbRVyPHeBoWiK8AHXVVYxswv5c4kpmECRS3LTbAVCHzrxbzuH"
        ; "3NKoxfcbnSkFSkFaMpmpgfVFqQmrwR6xkfpCHePLPh5uYKQLdpJt"
        ; "3NKVfBD1kXDJ8ZM3xhR5TFZXBRAs5UanSewxQRpXFmoxGxDddkP5"
        ; "3NKuotwHEdKRBK1yuDNkVUXqCnz5dPpS1xL4UJWghrAUB3t9pRQg"
        ; "3NKou5o9gJpcKBp8LnkUQgFBBQFZB6z7GD88pWDdwgVkfV8HmQTW"
        ; "3NKaqDsxAAFMvvxw22PLDkFaQyeHqioxhvb6BcpzbB3i8uaQdta7"
        ; "3NKCDffYzX5VMH3eH3G8CU6Ba6FndrevGBaJ9NCU7U6nv3iv2bpN"
        ; "3NL9sVkyZLLHFEvGPzr4ihYPzzZ3W3GixxjofeZib8qbe8hE4jUg"
        ; "3NLWggBpXBZxaV2R1DaJrL51uS6NshyDejbPn1gpWhp4E9t1cvPU"
        ; "3NL2cRDQkXEwnv33jTY5UKxLpyUpxKhcnwq7hQcfdDwc9QqXg5K9"
        ; "3NKvh8kXNtaJAhuC6Eqa8K4r2whzLuN5G7F8M14GTB1tcFKERp3z"
        ; "3NKVo2E1TGfb2pQ3jv84m7tVid4d6AHnKbDMZLWcrPxWwQJTYiQg"
        ; "3NL8d9RgUbDXjy92eH6ZVFc1ozn3darQx8u9EViMiCqrv5Ywe42x"
        ; "3NLGBF3yXbnQQxophx4YZfdXGcTt11KjC7jv8qaf3b8B8tZdrCBh"
        ; "3NKAbgwCDsdW6m18FSj8mBE2SpdMd7gopc5NMqGHxkqqLykMZrCR"
        ; "3NKFtTCSqVqKdbm6unoCiQWnKnozwYsiey5aPegV5xMR2MNR9kjZ"
        ; "3NKEyaQdmFtYWx2swLjkcpBeQGsfo8riNH6Kbdr9myWUQrZkbqjV"
        ; "3NK7jasQXuACjzJ5mBPNr13Y6Yt8vD6piLc1waFBU4Jte8WzEZ4h"
        ; "3NLPbRNQi6JFbh7DW9ibPgRhUnExwGaMpiuGJdEQ6Na47kWcP3PW"
        ; "3NK4EUku6d9fmU3P1t7NnoxsN4sg699JSskJZ4nJs1mWSHs1CL4v"
        ; "3NLDE8xKUvKMiSpLSd9uvnQaRiXYW6MWw7UXpFD2wbq4WeKRAnKM"
        ; "3NLZYyohgxGFE3hw6o6tfvXnZLoG6gyzr67WNGPFfpugHtoXaFGq" (*mainnet*)
        ; "3NKCedb2xxrgiaBFKVpxAJ9Kp7Tu1JG4qCUppJmt3c1RULQYQtrZ"
        ; "3NKjb8G3Sc4Z5hLckDy2Wg8soZmdghenyAYDuHVF5uNV36Td9DZt"
        ; "3NKKrhT3QX5tUS18kyGkYnjfNCCppgjy9zcZrmtMeNynEce47zpj"
        ; "3NKzdd7UjWLygUvgKfJwd3MVj3PD1GnXDHHGoTLyXinVvSoFRyX5"
        ; "3NKpPvE3NfGnbqRU4U6fDCMdUi9c54kphuDY4jniJuHZ62MyPWmr"
        ; "3NLP9qXSUAo9b8XjLZ8YpvdvEJ1g4TUdeznBH5kDAFv6kYYCGY51"
        ; "3NLLEfqqPdWHDtM7nw4S27uejcLZQ5D7N3BzmCNR5acYSaGuJ4pH"
        ; "3NKJoVQRihbwMUTDJKv4patDDMF8xGrvAaxQ9d2QJovJFegSuEQV"
        ; "3NKQ8W6L77xjPbz9sPNp357gfJ6a5LMD8K8kwGnW5jyULcCbd5Su"
        ; "3NLYL2dmLyGd889rwF5EmdjWE2BBGCZcHAwJA8MotiPVDiXLvktw"
        ; "3NLhmVdQvxpQLNvyehAXZKDsVrkgjb812VfpbgKqBRWSLa9c1kAA"
        ; "3NKX71ifBPJCZFDLdeLmhY97Zc8Y3xt2JZTFLgqtTnv53JvRcbzx"
        ; "3NLUhVLiWav4kBszLKZ6oDNC2BkbeX2cftsUGb6egeixjvqu3qqt"
        ; "3NKtmu2j6UJ9oggDJbtY6UDzZrMgDF8CH5A5xs3GyQUqMq4nS1ZN"
        ; "3NKJbfqrRzsjDC3FkSv5tsKQ7yp1xxYsXcs6arsoj18MKhcMVNeA"
        ; "3NKy6JUgC8r6ZGCKcQxPmKu9pN8xv5mGqVEiC1z1dLuVYhc2KEvV"
        ; "3NLi5AWq9YCT2XrB5vxkC5Psxrjv3JjHmK5DX87duztbCcL2oJkD"
        ; "3NKm5VGDQXtekWf3erWfjcHciGzjAWB4u7WNE7gAHGYjvkFbF5xj"
        ; "3NLnTnSMFayzpAahTgyL9mY1og2HDJjcg9kpKsQT5iQcPJ7FtJtJ"
        ; "3NKGm1K6T9pV7ygFqtScugMQB7EhDozsiz8Fe9LAYG2yx8yYie6p"
        ; "3NKj4YqZq1RCMDK3YM1gRtFZ2fspR1sNbRjQw4GA6Ut2Ar16jEYF"
        ; "3NLC7zugGno2Emt3w2DRJx6LdRzmoiW4F9PuAYurLQFmWFqEer1V"
        ; "3NKAKrhJrvFJtgMvr72ZXTaWPFisgDaND3AxZoPR6gAff5qDuKcq"
        ; "3NKDaz4DVLp4bQ5FJiXjEQPWmwgzvXAfCLY3w8d5NjzJZNVXnF6Q"
        ; "3NLKV4BUZwzpYvqcByRhJoKyME6Q5KEcrHPVY21XPfXsbPp486eu"
        ; "3NLbwy3BrF7gxEPF9WPoJPeED9NUC2RXdDnoJf6GvRwzksJThnM9"
        ; "3NKfHZ5DJkL3jjzstrfTCjHczMrPzvBsgPQ66trR9yqkE9dHJ7AD"
        ; "3NKUaab3R1mcG9caqyUUntpjvYD7VYUJ7rWjTCbgxzob3miG3WHK"
        ; "3NL2aQWNi6JadvfmwkyJVCtd9MjVwDCbvY1bfHbwCm1nJrDwSV2A"
        ; "3NK7ANsW4LQ62Hk8DJNEF36yyccoECJKmdeAyaf96WmksR2TyM3C"
        ; "3NKa82y8gNUe8ePYjq7jEh38vyWVLEteHynK686D8qaebeHpmfsS"
        ; "3NLcmRzkBdmFKqhpKEbw33A7GAd1EG7dg6CVwUhC4RKDTBZGnYDQ"
        ; "3NLHTdvTPXxUn8YFy4z59NxDcX9DYhthFtv8aPNMmpm2pYuA6Tf6"
        ]
      in
      (* apply commands in global slot, sequence order *)
      let rec apply_commands ~last_global_slot_since_genesis ~last_block_id
          ~(block_txns : Mina_transaction.Transaction.t list)
          (internal_cmds : Sql.Internal_command.t list)
          (user_cmds : Sql.User_command.t list)
          (zkapp_cmds : Sql.Zkapp_command.t list) =
        let check_ledger_hash_at_slot state_hash ledger_hash =
          if Ledger_hash.equal (Ledger.merkle_root ledger) ledger_hash then
            [%log info]
              "Applied all commands at global slot since genesis %Ld, got \
               expected ledger hash"
              ~metadata:
                [ ("ledger_hash", json_ledger_hash_of_ledger ledger)
                ; ("state_hash", State_hash.to_yojson state_hash)
                ; ( "global_slot_since_genesis"
                  , `String (Int64.to_string last_global_slot_since_genesis) )
                ; ("block_id", `Int last_block_id)
                ]
              last_global_slot_since_genesis
          else if
            List.mem state_hashes_to_avoid
              (State_hash.to_base58_check state_hash)
              ~equal:String.equal
          then
            [%log info]
              ~metadata:
                [ ("state_hash", `String (State_hash.to_base58_check state_hash))
                ]
              "This block has an inconsistent ledger hash due to a known \
               historical issue."
          else (
            [%log error]
              "Applied all commands at global slot since genesis %Ld, ledger \
               hash differs from expected ledger hash"
              ~metadata:
                [ ("ledger_hash", json_ledger_hash_of_ledger ledger)
                ; ("expected_ledger_hash", Ledger_hash.to_yojson ledger_hash)
                ; ("state_hash", State_hash.to_yojson state_hash)
                ; ( "global_slot_since_genesis"
                  , `String (Int64.to_string last_global_slot_since_genesis) )
                ]
              last_global_slot_since_genesis ;
            if continue_on_error then incr error_count else Core_kernel.exit 1 )
        in
        let check_account_accessed state_hash =
          [%log spam] "Checking accounts accessed in block just processed"
            ~metadata:
              [ ("state_hash", State_hash.to_yojson state_hash)
              ; ( "global_slot_since_genesis"
                , `String (Int64.to_string last_global_slot_since_genesis) )
              ; ("block_id", `Int last_block_id)
              ] ;
          let%bind accounts_accessed_db =
            query_db ~f:(fun db ->
                Processor.Accounts_accessed.all_from_block db last_block_id )
          in
          let%bind accounts_created_db =
            query_db ~f:(fun db ->
                Processor.Accounts_created.all_from_block db last_block_id )
          in
          [%log spam]
            "Verifying that accounts created are also deemed accessed in block \
             with global slot since genesis %Ld"
            last_global_slot_since_genesis ;
          (* every account created in preceding block is an accessed account in preceding block *)
          List.iter accounts_created_db
            ~f:(fun { account_identifier_id = acct_id_created; _ } ->
              if
                Option.is_none
                  (List.find accounts_accessed_db
                     ~f:(fun { account_identifier_id = acct_id_accessed; _ } ->
                       acct_id_accessed = acct_id_created ) )
              then (
                [%log error] "Created account not present in accessed accounts"
                  ~metadata:
                    [ ("created_account_identifier_id", `Int acct_id_created)
                    ; ("state_hash", State_hash.to_yojson state_hash)
                    ; ( "global_slot_since_genesis"
                      , `String (Int64.to_string last_global_slot_since_genesis)
                      )
                    ; ("block_id", `Int last_block_id)
                    ] ;
                if continue_on_error then incr error_count
                else Core_kernel.exit 1 ) ) ;
          [%log spam]
            "Verifying accounts accessed in block with global slot since \
             genesis %Ld"
            last_global_slot_since_genesis ;
          let%map accounts_accessed =
            Deferred.List.map accounts_accessed_db
              ~f:(Archive_lib.Load_data.get_account_accessed ~pool)
          in
          List.iter accounts_accessed ~f:(fun (index, account) ->
              let account_id =
                Account_id.create account.public_key account.token_id
              in
              let index_in_ledger =
                Ledger.index_of_account_exn ledger account_id
              in
              if index <> index_in_ledger then (
                [%log error]
                  "Account index in ledger does not match index in database"
                  ~metadata:
                    [ ("index_in_ledger", `Int index_in_ledger)
                    ; ("index_in_account_accessed", `Int index)
                    ] ;
                if continue_on_error then incr error_count
                else Core_kernel.exit 1 ) ;
              match Ledger.location_of_account ledger account_id with
              | None ->
                  [%log error] "Accessed account not in ledger"
                    ~metadata:
                      [ ("account_id", Account_id.to_yojson account_id) ] ;
                  if continue_on_error then incr error_count
                  else Core_kernel.exit 1
              | Some loc ->
                  let account_in_ledger =
                    match Ledger.get ledger loc with
                    | Some acct ->
                        acct
                    | None ->
                        (* should be unreachable *)
                        failwith
                          "Account not in ledger, even though there's a \
                           location for it"
                  in
                  if not @@ Account.equal account account_in_ledger then (
                    [%log error]
                      "Account in ledger does not match account in database"
                      ~metadata:
                        [ ("account_id", Account_id.to_yojson account_id)
                        ; ( "account_in_ledger"
                          , Account.to_yojson account_in_ledger )
                        ; ("account_in_database", Account.to_yojson account)
                        ] ;
                    if continue_on_error then incr error_count
                    else Core_kernel.exit 1 ) )
        in
        let log_state_hash_on_next_slot curr_global_slot_since_genesis =
          match get_slot_hashes curr_global_slot_since_genesis with
          | None ->
              [%log fatal]
                "Missing state hash information for current global slot" ;
              Core.exit 1
          | Some (state_hash, _ledger_hash, _snarked_hash) ->
              [%log spam]
                ~metadata:
                  [ ( "state_hash"
                    , `String (State_hash.to_base58_check state_hash) )
                  ]
                "Starting processing of commands in block with state_hash \
                 $state_hash at global slot since genesis %Ld"
                curr_global_slot_since_genesis
        in
        let run_transactions_on_slot_change ?(last_block = false) block_txns ()
            =
          match get_slot_hashes last_global_slot_since_genesis with
          | None ->
              if
                Int64.equal last_global_slot_since_genesis
                  input.start_slot_since_genesis
              then (
                [%log info]
                  "No ledger hash information at start slot, not checking \
                   against ledger, not running transactions" ;
                Deferred.unit )
              else (
                [%log fatal]
                  "Missing ledger hash information for last global slot, which \
                   is not the start slot" ;
                Core.exit 1 )
          | Some (state_hash, ledger_hash, snarked_hash) ->
              let write_checkpoint_file ~checkpoint_output_folder_opt
                  ~checkpoint_file_prefix () =
                let write_checkpoint () =
                  write_replayer_checkpoint ~logger ~ledger
                    ~last_global_slot_since_genesis ~max_canonical_slot
                    ~checkpoint_output_folder_opt ~checkpoint_file_prefix
                in
                if last_block then write_checkpoint ()
                else
                  match !checkpoint_target with
                  | None ->
                      Deferred.unit
                  | Some target ->
                      if Int64.(last_global_slot_since_genesis >= target) then (
                        incr_checkpoint_target () ; write_checkpoint () )
                      else Deferred.unit
              in
              let rec count_txns ~signed_count ~zkapp_count ~fee_transfer_count
                  ~coinbase_count = function
                | [] ->
                    [%log spam]
                      "Replaying transactions in block with state hash \
                       $state_hash"
                      ~metadata:
                        [ ("state_hash", State_hash.to_yojson state_hash)
                        ; ( "global_slot_since_genesis"
                          , `String
                              (Int64.to_string last_global_slot_since_genesis)
                          )
                        ; ("block_id", `Int last_block_id)
                        ; ("no_signed_commands", `Int signed_count)
                        ; ("no_zkapp_commands", `Int zkapp_count)
                        ; ("no_fee_transfers", `Int fee_transfer_count)
                        ; ("no_coinbases", `Int coinbase_count)
                        ]
                | txn :: txns -> (
                    match txn with
                    | Mina_transaction.Transaction.Command cmd -> (
                        match cmd with
                        | User_command.Signed_command _ ->
                            count_txns ~signed_count:(signed_count + 1)
                              ~zkapp_count ~fee_transfer_count ~coinbase_count
                              txns
                        | Zkapp_command _ ->
                            count_txns ~signed_count
                              ~zkapp_count:(zkapp_count + 1) ~fee_transfer_count
                              ~coinbase_count txns )
                    | Fee_transfer _ ->
                        count_txns ~signed_count ~zkapp_count
                          ~fee_transfer_count:(fee_transfer_count + 1)
                          ~coinbase_count txns
                    | Coinbase _ ->
                        count_txns ~signed_count ~zkapp_count
                          ~fee_transfer_count
                          ~coinbase_count:(coinbase_count + 1) txns )
              in
              let run_transactions () =
                count_txns ~signed_count:0 ~zkapp_count:0 ~fee_transfer_count:0
                  ~coinbase_count:0 block_txns ;
                let%bind txn_state_view =
                  get_parent_state_view ~pool last_block_id
                in
                let apply_transaction_phases txns =
                  let%bind phase_1s =
                    Deferred.List.mapi txns ~f:(fun n txn ->
                        match
                          Ledger.apply_transaction_first_pass ~signature_kind
                            ~constraint_constants
                            ~global_slot:
                              (Mina_numbers.Global_slot_since_genesis.of_uint32
                                 (Unsigned.UInt32.of_int64
                                    last_global_slot_since_genesis ) )
                            ~txn_state_view ledger txn
                        with
                        | Ok partially_applied ->
                            (* the current ledger may become a snarked ledger *)
                            First_pass_ledger_hashes.add
                              (Ledger.merkle_root ledger) ;
                            let%bind () =
                              update_staking_epoch_data ~logger pool
                                ~last_block_id ~ledger ~staking_epoch_ledger
                                ~staking_seed
                            in
                            let%map () =
                              update_next_epoch_data ~logger pool ~last_block_id
                                ~ledger ~next_epoch_ledger ~next_seed
                            in
                            partially_applied
                        | Error err ->
                            [%log error]
                              "Error during Phase 1 application of transaction \
                               %d (0-based) in block with state hash \
                               $state_hash"
                              n
                              ~metadata:
                                [ ("state_hash", State_hash.to_yojson state_hash)
                                ; ( "transaction"
                                  , Mina_transaction.Transaction.to_yojson txn
                                  )
                                ; ("error", `String (Error.to_string_hum err))
                                ] ;
                            Error.raise err )
                  in
                  Deferred.List.iter phase_1s ~f:(fun partial ->
                      match
                        Ledger.apply_transaction_second_pass ledger partial
                      with
                      | Ok _applied ->
                          let%bind () =
                            update_staking_epoch_data ~logger pool
                              ~last_block_id ~ledger ~staking_epoch_ledger
                              ~staking_seed
                          in
                          update_next_epoch_data ~logger pool ~last_block_id
                            ~ledger ~next_epoch_ledger ~next_seed
                      | Error err ->
                          (* must be a zkApp *)
                          ( match partial with
                          | Ledger.Transaction_partially_applied.Zkapp_command
                              zk_partial ->
                              let cmd = zk_partial.command in
                              [%log error]
                                "Error during Phase 2 application of \
                                 partially-applied zkApp in block with state \
                                 hash $state_hash"
                                ~metadata:
                                  [ ( "state_hash"
                                    , State_hash.to_yojson state_hash )
                                  ; ( "zkapp_command"
                                    , Zkapp_command.to_yojson cmd )
                                  ; ("error", `String (Error.to_string_hum err))
                                  ]
                          | _ ->
                              failwith
                                "Unexpected phase 2 failure of non-zkApp \
                                 command" ) ;
                          Error.raise err )
                in
                apply_transaction_phases (List.rev block_txns)
              in
              ( if
                Frozen_ledger_hash.equal snarked_hash
                  (First_pass_ledger_hashes.get_last_snarked_hash ())
              then
                [%log spam]
                  "Snarked ledger hash same as in the preceding block, not \
                   checking it again"
              else if
              Frozen_ledger_hash.equal snarked_hash genesis_snarked_ledger_hash
            then
                [%log spam] "Snarked ledger hash is genesis snarked ledger hash"
              else
                match First_pass_ledger_hashes.find snarked_hash with
                | None ->
                    if not !found_snarked_ledger_hash then (
                      [%log info]
                        "Current snarked ledger hash not among first-pass \
                         ledger hashes, but we haven't yet found one. The \
                         transaction that created this ledger hash might have \
                         been in an older replayer run that created a \
                         checkpoint file without saved first-pass ledger \
                         hashes" ;
                      First_pass_ledger_hashes.set_last_snarked_hash
                        snarked_hash )
                    else
                      [%log error]
                        "Current snarked ledger hash does not appear among \
                         first-pass ledger hashes" ;
                    if continue_on_error then incr error_count
                    else Core_kernel.exit 1
                | Some (_hash, n) ->
                    [%log spam]
                      "Found snarked ledger hash among first-pass ledger hashes" ;
                    found_snarked_ledger_hash := true ;
                    First_pass_ledger_hashes.set_last_snarked_hash snarked_hash ;
                    First_pass_ledger_hashes.flush_older_than n ) ;
              if List.is_empty block_txns then (
                [%log spam]
                  "No transactions to run for block with state hash $state_hash"
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson state_hash)
                    ; ( "global_slot_since_genesis"
                      , `String (Int64.to_string last_global_slot_since_genesis)
                      )
                    ; ("block_id", `Int last_block_id)
                    ] ;
                Deferred.unit )
              else
                let%bind () = run_transactions () in
                let () = check_ledger_hash_at_slot state_hash ledger_hash in
                (* don't check ledger hash, because depth changed from mainnet *)
                let%bind () = check_account_accessed state_hash in
                log_state_hash_on_next_slot last_global_slot_since_genesis ;
                write_checkpoint_file ~checkpoint_output_folder_opt
                  ~checkpoint_file_prefix ()
        in
        (* a sequence is a command type, slot, sequence number triple *)
        let get_internal_cmd_sequence (ic : Sql.Internal_command.t) =
          (`Internal_command, ic.global_slot_since_genesis, ic.sequence_no)
        in
        let get_user_cmd_sequence (uc : Sql.User_command.t) =
          (`User_command, uc.global_slot_since_genesis, uc.sequence_no)
        in
        let get_zkapp_cmd_sequence (sc : Sql.Zkapp_command.t) =
          (`Zkapp_command, sc.global_slot_since_genesis, sc.sequence_no)
        in
        let command_type_of_sequences seqs =
          let compare (_cmd_ty1, slot1, seq_no1) (_cmd_ty2, slot2, seq_no2) =
            [%compare: int64 * int] (slot1, seq_no1) (slot2, seq_no2)
          in
          let sorted_seqs = List.sort seqs ~compare in
          let cmd_ty, _slot, _seq_no = List.hd_exn sorted_seqs in
          cmd_ty
        in
        let check_for_complete_block ~cmd_global_slot_since_genesis =
          if
            Int64.( > ) cmd_global_slot_since_genesis
              last_global_slot_since_genesis
          then
            let%map () = run_transactions_on_slot_change block_txns () in
            []
          else return block_txns
        in
        match (internal_cmds, user_cmds, zkapp_cmds) with
        | [], [], [] ->
            (* all done *)
            let%bind _ =
              run_transactions_on_slot_change ~last_block:true block_txns ()
            in
            Deferred.return
              (staking_epoch_ledger, staking_seed, next_epoch_ledger, next_seed)
        | ic :: ics, [], [] ->
            (* only internal commands *)
            let%bind block_txns0 =
              check_for_complete_block
                ~cmd_global_slot_since_genesis:ic.global_slot_since_genesis
            in
            let%bind block_txns, ics' =
              let%map txn, ics' =
                internal_cmds_to_transaction ~logger ~pool ic ics
              in
              ( Option.value_map txn ~default:block_txns0 ~f:(fun txn ->
                    txn :: block_txns0 )
              , ics' )
            in
            apply_commands ~block_txns
              ~last_global_slot_since_genesis:ic.global_slot_since_genesis
              ~last_block_id:ic.block_id ics' user_cmds zkapp_cmds
        | [], uc :: ucs, [] ->
            (* only user commands *)
            let%bind block_txns =
              check_for_complete_block
                ~cmd_global_slot_since_genesis:uc.global_slot_since_genesis
            in
            let%bind txn = user_command_to_transaction ~logger ~pool uc in
            apply_commands ~block_txns:(txn :: block_txns)
              ~last_global_slot_since_genesis:uc.global_slot_since_genesis
              ~last_block_id:uc.block_id internal_cmds ucs zkapp_cmds
        | [], [], zkc :: zkcs ->
            (* only zkApp commands *)
            let%bind block_txns =
              check_for_complete_block
                ~cmd_global_slot_since_genesis:zkc.global_slot_since_genesis
            in
            let%bind txn =
              zkapp_command_to_transaction ~proof_cache_db ~logger ~pool zkc
            in
            apply_commands ~block_txns:(txn :: block_txns)
              ~last_global_slot_since_genesis:zkc.global_slot_since_genesis
              ~last_block_id:zkc.block_id internal_cmds user_cmds zkcs
        | [], uc :: ucs, zkc :: zkcs -> (
            (* no internal commands *)
            let seqs =
              [ get_user_cmd_sequence uc; get_zkapp_cmd_sequence zkc ]
            in
            match command_type_of_sequences seqs with
            | `User_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:uc.global_slot_since_genesis
                in
                let%bind txn = user_command_to_transaction ~logger ~pool uc in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id internal_cmds ucs zkapp_cmds
            | `Zkapp_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:zkc.global_slot_since_genesis
                in
                let%bind txn =
                  zkapp_command_to_transaction ~proof_cache_db ~logger ~pool zkc
                in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:zkc.global_slot_since_genesis
                  ~last_block_id:zkc.block_id internal_cmds user_cmds zkcs )
        | ic :: ics, [], zkc :: zkcs -> (
            (* no user commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_zkapp_cmd_sequence zkc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                let%bind block_txns0 =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:ic.global_slot_since_genesis
                in
                let%bind block_txns, ics' =
                  let%map txn, ics' =
                    internal_cmds_to_transaction ~logger ~pool ic ics
                  in
                  ( Option.value_map txn ~default:block_txns0 ~f:(fun txn ->
                        txn :: block_txns0 )
                  , ics' )
                in
                apply_commands ~block_txns
                  ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                  ~last_block_id:ic.block_id ics' user_cmds zkapp_cmds
            | `Zkapp_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:zkc.global_slot_since_genesis
                in
                let%bind txn =
                  zkapp_command_to_transaction ~proof_cache_db ~logger ~pool zkc
                in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:zkc.global_slot_since_genesis
                  ~last_block_id:zkc.block_id internal_cmds user_cmds zkcs )
        | ic :: ics, uc :: ucs, [] -> (
            (* no zkApp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic; get_user_cmd_sequence uc ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                let%bind block_txns0 =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:ic.global_slot_since_genesis
                in
                let%bind block_txns, ics' =
                  let%map txn, ics' =
                    internal_cmds_to_transaction ~logger ~pool ic ics
                  in
                  ( Option.value_map txn ~default:block_txns0 ~f:(fun txn ->
                        txn :: block_txns0 )
                  , ics' )
                in
                apply_commands ~block_txns
                  ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                  ~last_block_id:ic.block_id ics' user_cmds zkapp_cmds
            | `User_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:uc.global_slot_since_genesis
                in
                let%bind txn = user_command_to_transaction ~logger ~pool uc in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id internal_cmds ucs zkapp_cmds )
        | ic :: ics, uc :: ucs, zkc :: zkcs -> (
            (* internal, user, and zkApp commands *)
            let seqs =
              [ get_internal_cmd_sequence ic
              ; get_user_cmd_sequence uc
              ; get_zkapp_cmd_sequence zkc
              ]
            in
            match command_type_of_sequences seqs with
            | `Internal_command ->
                let%bind block_txns0 =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:ic.global_slot_since_genesis
                in
                let%bind block_txns, ics' =
                  let%map txn, ics' =
                    internal_cmds_to_transaction ~logger ~pool ic ics
                  in
                  ( Option.value_map txn ~default:block_txns0 ~f:(fun txn ->
                        txn :: block_txns0 )
                  , ics' )
                in
                apply_commands ~block_txns
                  ~last_global_slot_since_genesis:ic.global_slot_since_genesis
                  ~last_block_id:ic.block_id ics' user_cmds zkapp_cmds
            | `User_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:uc.global_slot_since_genesis
                in
                let%bind txn = user_command_to_transaction ~logger ~pool uc in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:uc.global_slot_since_genesis
                  ~last_block_id:uc.block_id internal_cmds ucs zkapp_cmds
            | `Zkapp_command ->
                let%bind block_txns =
                  check_for_complete_block
                    ~cmd_global_slot_since_genesis:zkc.global_slot_since_genesis
                in
                let%bind txn =
                  zkapp_command_to_transaction ~proof_cache_db ~logger ~pool zkc
                in
                apply_commands ~block_txns:(txn :: block_txns)
                  ~last_global_slot_since_genesis:zkc.global_slot_since_genesis
                  ~last_block_id:zkc.block_id internal_cmds user_cmds zkcs )
      in
      let%bind start_slot_since_genesis =
        let%map slot_opt =
          query_db ~f:(fun db ->
              Sql.Block.get_next_slot db input.start_slot_since_genesis )
        in
        match slot_opt with
        | Some slot ->
            slot
        | None ->
            failwithf
              "There is no slot in the database greater than equal to the \
               start slot %Ld given in the input file"
              input.start_slot_since_genesis ()
      in
      if
        not
          (Int64.equal start_slot_since_genesis input.start_slot_since_genesis)
      then
        [%log info]
          "Starting with next available global slot in the archive database"
          ~metadata:
            [ ( "input_start_slot"
              , `String (Int64.to_string input.start_slot_since_genesis) )
            ; ( "available_start_slot"
              , `String (Int64.to_string start_slot_since_genesis) )
            ] ;
      [%log info] "At start global slot %Ld, ledger hash"
        start_slot_since_genesis
        ~metadata:[ ("ledger_hash", json_ledger_hash_of_ledger ledger) ] ;
      let%bind staking_epoch_ledger, staking_seed, next_epoch_ledger, next_seed
          =
        apply_commands ~block_txns:[]
          ~last_global_slot_since_genesis:start_slot_since_genesis
          ~last_block_id:oldest_block_id sorted_internal_cmds sorted_user_cmds
          sorted_zkapp_cmds
      in
      match input.target_epoch_ledgers_state_hash with
      | None ->
          [%log info] "No target epoch ledger hash supplied, not writing output" ;
          Deferred.unit
      | Some target_epoch_ledgers_state_hash -> (
          match output_file_opt with
          | None ->
              [%log info] "Output file not supplied, not writing output" ;
              return ()
          | Some output_file ->
              if Int.equal !error_count 0 then (
                [%log info] "Writing output to $output_file"
                  ~metadata:[ ("output_file", `String output_file) ] ;
                let%bind output =
                  let%map output =
                    create_output ~target_epoch_ledgers_state_hash
                      ~target_fork_state_hash:
                        (State_hash.of_base58_check_exn target_state_hash)
                      ~ledger ~staking_epoch_ledger:!staking_epoch_ledger
                      ~staking_seed:!staking_seed
                      ~next_epoch_ledger:!next_epoch_ledger
                      ~next_seed:!next_seed input.genesis_ledger
                  in
                  output_to_yojson output |> Yojson.Safe.pretty_to_string
                in
                return
                @@ Out_channel.with_file output_file ~f:(fun oc ->
                       Out_channel.output_string oc output ) )
              else (
                [%log error] "There were %d errors, not writing output"
                  !error_count ;
                exit 1 ) ) )

let () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Proof_level.Full in
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Replay transactions from Mina archive database"
        (let%map input_file =
           Param.flag "--input-file"
             ~doc:"file File containing the starting ledger"
             Param.(required string)
         and output_file_opt =
           Param.flag "--output-file"
             ~doc:"file File containing the resulting ledger"
             Param.(optional string)
         and archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and continue_on_error =
           Param.flag "--continue-on-error"
             ~doc:"Continue processing after errors" Param.no_arg
         and checkpoint_interval =
           Param.flag "--checkpoint-interval"
             ~doc:"NN Write checkpoint file every NN slots"
             Param.(optional int)
         and checkpoint_output_folder_opt =
           Param.flag "--checkpoint-output-folder"
             ~doc:"file Folder containing the resulting checkpoints"
             Param.(optional string)
         and genesis_dir_opt =
           Param.flag "--genesis-ledger-dir"
             ~doc:"DIR Directory that contains the genesis ledger"
             Param.(optional string)
         and checkpoint_file_prefix =
           Param.flag "--checkpoint-file-prefix"
             ~doc:"string Checkpoint file prefix (default: 'replayer')"
             Param.(optional_with_default "replayer" string)
         and log_json = Cli_lib.Flag.Log.json
         and log_level = Cli_lib.Flag.Log.level
         and file_log_level = Cli_lib.Flag.Log.file_log_level
         and log_filename = Cli_lib.Flag.Log.file in
         main ~input_file ~output_file_opt ~archive_uri ~checkpoint_interval
           ~continue_on_error ~checkpoint_output_folder_opt
           ~checkpoint_file_prefix ~genesis_dir_opt ~log_json ~log_level
           ~file_log_level ~log_filename ~constraint_constants ~proof_level )))
