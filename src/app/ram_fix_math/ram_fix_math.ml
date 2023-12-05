open Core

(* number of operations to do when performing benchmarks *)
let bench_count = 10_000

module Const = struct
  let k = 290

  let ledger_depth = 30

  let scan_state_depth = 7

  let scan_state_delay = 2

  (* 2*k for best tip path (including root history), k for duplicate block producers *)
  let est_blocks_in_frontier = 3 * k

  (* k for best tip boath (excluding root history), k for duplicate block producers *)
  let est_scan_states = 2 * k

  let max_accounts_modified_per_signed_command = 2
end

(* things we can change in the protocol *)
module Params = struct
  let max_zkapp_txn_account_updates = 6

  let max_zkapp_commands_per_block = 128

  let max_signed_commands_per_block = 0

  let max_zkapp_events = 100

  let max_zkapp_actions = 100

  let max_txn_pool_size = 3000

  let max_accounts_modified_per_zkapp_command =
    1 + max_zkapp_txn_account_updates

  let max_accounts_modified_per_block =
    (max_accounts_modified_per_zkapp_command * max_zkapp_commands_per_block)
    + Const.max_accounts_modified_per_signed_command
      * max_signed_commands_per_block
end

(* dummy values used for computing RAM usage benchmarking *)
module Values = struct
  let bin_copy (type a) ~(bin_class : a Bin_prot.Type_class.t) (x : a) =
    let size = bin_class.writer.size x in
    let buf = Bigstring.create size in
    assert (bin_class.writer.write buf ~pos:0 x = size) ;
    bin_class.reader.read buf ~pos_ref:(ref 0)

  let field () : Snark_params.Tick.Field.t =
    bin_copy ~bin_class:Snark_params.Tick.Field.bin_t
      Snark_params.Tick.Field.zero

  let amount () : Currency.Amount.t =
    bin_copy ~bin_class:Currency.Amount.Stable.Latest.bin_t Currency.Amount.zero

  let balance () : Currency.Balance.t =
    bin_copy ~bin_class:Currency.Balance.Stable.Latest.bin_t
      Currency.Balance.zero

  let fee () : Currency.Fee.t =
    bin_copy ~bin_class:Currency.Fee.Stable.Latest.bin_t Currency.Fee.zero

  let length () : Mina_numbers.Length.t =
    bin_copy ~bin_class:Mina_numbers.Length.Stable.Latest.bin_t
      Mina_numbers.Length.zero

  let account_nonce () : Mina_numbers.Account_nonce.t =
    bin_copy ~bin_class:Mina_numbers.Account_nonce.Stable.Latest.bin_t
      Mina_numbers.Account_nonce.zero

  let global_slot_since_genesis () : Mina_numbers.Global_slot_since_genesis.t =
    bin_copy
      ~bin_class:Mina_numbers.Global_slot_since_genesis.Stable.Latest.bin_t
      Mina_numbers.Global_slot_since_genesis.zero

  let global_slot_span () : Mina_numbers.Global_slot_span.t =
    bin_copy ~bin_class:Mina_numbers.Global_slot_span.Stable.Latest.bin_t
      Mina_numbers.Global_slot_span.zero

  let zkapp_version () : Mina_numbers.Zkapp_version.t =
    bin_copy ~bin_class:Mina_numbers.Zkapp_version.Stable.Latest.bin_t
      Mina_numbers.Zkapp_version.zero

  let signed_command_memo () : Mina_base.Signed_command_memo.t =
    bin_copy ~bin_class:Mina_base.Signed_command_memo.Stable.Latest.bin_t
      Mina_base.Signed_command_memo.empty

  let zkapp_uri () : string =
    bin_copy ~bin_class:String.bin_t (String.init 255 ~f:(Fn.const 'z'))

  let token_symbol () : Mina_base.Account.Token_symbol.t =
    bin_copy ~bin_class:Mina_base.Account.Token_symbol.Stable.Latest.bin_t
      (String.init Mina_base.Account.Token_symbol.max_length ~f:(Fn.const 'z'))

  let token_id () : Mina_base.Token_id.t =
    bin_copy ~bin_class:Mina_base.Token_id.Stable.Latest.bin_t
      Mina_base.Token_id.default

  let timing_info () : Mina_base.Account_update.Update.Timing_info.t =
    bin_copy
      ~bin_class:Mina_base.Account_update.Update.Timing_info.Stable.Latest.bin_t
      Mina_base.Account_update.Update.Timing_info.dummy

  let state_hash () : Mina_base.State_hash.t =
    bin_copy ~bin_class:Mina_base.State_hash.Stable.Latest.bin_t
      Mina_base.State_hash.dummy

  let permissions () : Mina_base.Permissions.t =
    bin_copy ~bin_class:Mina_base.Permissions.Stable.Latest.bin_t
      Mina_base.Permissions.user_default

  let precondition_numeric (type a) (f : unit -> a) :
      a Mina_base.Zkapp_precondition.Numeric.t =
    Check { lower = f (); upper = f () }

  let precondition_hash (type a) (f : unit -> a) :
      a Mina_base.Zkapp_precondition.Hash.t =
    Check (f ())

  let preconditions () : Mina_base.Account_update.Preconditions.t =
    { network =
        { snarked_ledger_hash = precondition_hash field
        ; blockchain_length = precondition_numeric length
        ; min_window_density = precondition_numeric length
        ; total_currency = precondition_numeric amount
        ; global_slot_since_genesis =
            precondition_numeric global_slot_since_genesis
        ; staking_epoch_data =
            { ledger =
                { hash = precondition_hash field
                ; total_currency = precondition_numeric amount
                }
            ; seed = precondition_hash field
            ; start_checkpoint = precondition_hash field
            ; lock_checkpoint = precondition_hash field
            ; epoch_length = precondition_numeric length
            }
        ; next_epoch_data =
            { ledger =
                { hash = precondition_hash field
                ; total_currency = precondition_numeric amount
                }
            ; seed = precondition_hash field
            ; start_checkpoint = precondition_hash field
            ; lock_checkpoint = precondition_hash field
            ; epoch_length = precondition_numeric length
            }
        }
    ; account = Mina_base.Zkapp_precondition.Account.accept
    ; valid_while =
        Check
          { lower = global_slot_since_genesis ()
          ; upper = global_slot_since_genesis ()
          }
    }

  let keypair () : Signature_lib.Keypair.t = Signature_lib.Keypair.create ()

  let private_key () : Signature_lib.Private_key.t = (keypair ()).private_key

  let public_key_uncompressed () : Signature_lib.Public_key.t =
    (keypair ()).public_key

  let public_key () : Signature_lib.Public_key.Compressed.t =
    Signature_lib.Public_key.compress (keypair ()).public_key

  let verification_key : unit -> Mina_base.Verification_key_wire.t =
    let vk =
      let `VK vk, `Prover _ =
        Transaction_snark.For_tests.create_trivial_snapp
          ~constraint_constants:Genesis_constants.Constraint_constants.compiled
          ()
      in
      vk
    in
    fun () ->
      bin_copy ~bin_class:Mina_base.Verification_key_wire.Stable.Latest.bin_t vk

  let side_loaded_proof : unit -> Pickles.Side_loaded.Proof.t =
    let proof =
      let num_updates = 1 in
      let _ledger, zkapp_commands =
        Snark_profiler_lib.create_ledger_and_zkapps ~min_num_updates:num_updates
          ~num_proof_updates:num_updates ~max_num_updates:num_updates ()
      in
      let cmd = List.hd_exn zkapp_commands in
      let update =
        List.nth_exn (Mina_base.Zkapp_command.all_account_updates_list cmd) 1
      in
      match update.authorization with
      | Proof proof ->
          proof
      | _ ->
          failwith "woops"
    in
    fun () ->
      bin_copy ~bin_class:Pickles.Side_loaded.Proof.Stable.Latest.bin_t
        (Pickles.Side_loaded.Proof.of_proof proof)

  let ledger_proof () : Ledger_proof.t =
    bin_copy ~bin_class:Ledger_proof.Stable.Latest.bin_t
      (Ledger_proof.For_tests.mk_dummy_proof
         (Mina_state.Snarked_ledger_state.genesis
            ~genesis_ledger_hash:
              (Mina_base.Frozen_ledger_hash.of_ledger_hash
                 Mina_base.Ledger_hash.empty_hash ) ) )

  let one_priced_proof () :
      Ledger_proof.t One_or_two.t Network_pool.Priced_proof.t =
    { proof = `One (ledger_proof ())
    ; fee = { prover = public_key (); fee = fee () }
    }

  let two_priced_proofs () :
      Ledger_proof.t One_or_two.t Network_pool.Priced_proof.t =
    { proof = `Two (ledger_proof (), ledger_proof ())
    ; fee = { prover = public_key (); fee = fee () }
    }

  let receipt_chain_hash () : Mina_base.Receipt.Chain_hash.t =
    bin_copy ~bin_class:Mina_base.Receipt.Chain_hash.Stable.Latest.bin_t
      Mina_base.Receipt.Chain_hash.empty

  let account () : Mina_base.Account.t =
    { public_key = public_key ()
    ; token_id = token_id ()
    ; token_symbol = token_symbol ()
    ; balance = balance ()
    ; nonce = account_nonce ()
    ; receipt_chain_hash = receipt_chain_hash ()
    ; delegate = Some (public_key ())
    ; voting_for = state_hash ()
    ; timing =
        Mina_base.Account.Timing.Timed
          { initial_minimum_balance = balance ()
          ; cliff_time = global_slot_since_genesis ()
          ; cliff_amount = amount ()
          ; vesting_period = global_slot_span ()
          ; vesting_increment = amount ()
          }
    ; permissions = permissions ()
    ; zkapp =
        Some
          { app_state =
              Pickles_types.Vector.init Mina_base.Zkapp_state.Max_state_size.n
                ~f:(fun _ -> field ())
          ; verification_key = Some (verification_key ())
          ; zkapp_uri = zkapp_uri ()
          ; zkapp_version = zkapp_version ()
          ; action_state =
              Pickles_types.Vector.init Pickles_types.Nat.N5.n ~f:(fun _ ->
                  field () )
          ; last_action_slot = global_slot_since_genesis ()
          ; proved_state = false
          }
    }

  let ledger_mask ?(n = Params.max_accounts_modified_per_block) () :
      Mina_ledger.Ledger.t =
    let ledger =
      Mina_ledger.Ledger.create_ephemeral ~depth:Const.ledger_depth ()
    in
    List.init n ~f:Fn.id
    |> List.iter ~f:(fun i ->
           Mina_ledger.Ledger.set_at_index_exn ledger i (account ()) ) ;
    ledger

  let ledger_witness n : Mina_ledger.Sparse_ledger.t =
    let ledger_mask = ledger_mask ~n () in
    let ids = ref [] in
    Mina_ledger.Ledger.iteri ledger_mask ~f:(fun _ acc ->
        ids := Mina_base.Account.identifier acc :: !ids ) ;
    Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger_mask !ids

  let zkapp_command_witness () : Mina_ledger.Sparse_ledger.t =
    ledger_witness Params.max_accounts_modified_per_zkapp_command

  let signed_command_witness () : Mina_ledger.Sparse_ledger.t =
    ledger_witness Const.max_accounts_modified_per_signed_command

  let signed_command' () : Mina_base.Signed_command.t =
    { payload =
        { common =
            { fee = fee ()
            ; fee_payer_pk = public_key ()
            ; nonce = account_nonce ()
            ; valid_until = global_slot_since_genesis ()
            ; memo = signed_command_memo ()
            }
        ; body = Payment { receiver_pk = public_key (); amount = amount () }
        }
    ; signer = public_key_uncompressed ()
    ; signature = (field (), private_key ())
    }

  let signed_command () : Mina_base.User_command.t =
    Mina_base.User_command.Signed_command (signed_command' ())

  let zkapp_account_update () : Mina_base.Account_update.t =
    { body =
        { public_key = public_key ()
        ; token_id = token_id ()
        ; update =
            { app_state =
                Pickles_types.Vector.init Mina_base.Zkapp_state.Max_state_size.n
                  ~f:(fun _ -> Mina_base.Zkapp_basic.Set_or_keep.Set (field ()))
            ; delegate = Set (public_key ())
            ; verification_key = Set (verification_key ())
            ; permissions = Set (permissions ())
            ; zkapp_uri = Set (zkapp_uri ())
            ; token_symbol = Set (token_symbol ())
            ; timing = Set (timing_info ())
            ; voting_for = Set (state_hash ())
            }
        ; balance_change =
            (* TODO: insure uniqueness *) Currency.Amount.Signed.zero
        ; increment_nonce = false (* TODO: actions and events sizes *)
        ; events = [ Array.init Params.max_zkapp_events ~f:(fun _ -> field ()) ]
        ; actions =
            [ Array.init Params.max_zkapp_actions ~f:(fun _ -> field ()) ]
        ; call_data = field ()
        ; preconditions = preconditions ()
        ; use_full_commitment = false
        ; implicit_account_creation_fee = false
        ; may_use_token = No
        ; authorization_kind = Proof (field ())
        }
    ; authorization = Proof (side_loaded_proof ())
    }

  let zkapp_command' () : Mina_base.Zkapp_command.t =
    { fee_payer =
        { body =
            { public_key = public_key ()
            ; fee = fee ()
            ; valid_until = Some (global_slot_since_genesis ())
            ; nonce = account_nonce ()
            }
        ; authorization = (field (), private_key ())
        }
    ; account_updates =
        List.init Params.max_zkapp_txn_account_updates ~f:(Fn.const ())
        |> List.fold_left ~init:[] ~f:(fun acc () ->
               Mina_base.Zkapp_command.Call_forest.cons
                 (zkapp_account_update ()) acc )
    ; memo = signed_command_memo ()
    }

  let zkapp_command () : Mina_base.User_command.t =
    Mina_base.User_command.Zkapp_command (zkapp_command' ())

  let pending_coinbase_stack () : Mina_base.Pending_coinbase.Stack.t =
    bin_copy
      ~bin_class:Mina_base.Pending_coinbase.Stack_versioned.Stable.Latest.bin_t
      Mina_base.Pending_coinbase.Stack.empty

  let local_state () : Mina_state.Local_state.t =
    bin_copy ~bin_class:Mina_state.Local_state.Stable.Latest.bin_t
      (Mina_state.Local_state.dummy ())

  let fee_excess () : Mina_base.Fee_excess.t =
    bin_copy ~bin_class:Mina_base.Fee_excess.Stable.Latest.bin_t
      Mina_base.Fee_excess.empty

  let base_work varying witness :
      Transaction_snark_scan_state.Transaction_with_witness.t =
    { transaction_with_info = { previous_hash = field (); varying = varying () }
    ; state_hash = (state_hash (), field ())
    ; statement =
        (*Transaction_snark.Statement.Stable.V2.t*)
        { source =
            { first_pass_ledger = field ()
            ; second_pass_ledger = field ()
            ; pending_coinbase_stack = pending_coinbase_stack ()
            ; local_state = local_state ()
            }
        ; target =
            { first_pass_ledger = field ()
            ; second_pass_ledger = field ()
            ; pending_coinbase_stack = pending_coinbase_stack ()
            ; local_state = local_state ()
            }
        ; connecting_ledger_left = field ()
        ; connecting_ledger_right = field ()
        ; supply_increase =
            (* TODO: insure uniqueness *) Currency.Amount.Signed.zero
        ; fee_excess = fee_excess ()
        ; sok_digest = ()
        }
    ; init_stack = Base (pending_coinbase_stack ())
    ; first_pass_ledger_witness = witness ()
    ; second_pass_ledger_witness = witness ()
    ; block_global_slot = global_slot_since_genesis ()
    }

  let zkapp_command_base_work () :
      Transaction_snark_scan_state.Transaction_with_witness.t =
    base_work
      (fun () ->
        Command
          (Zkapp_command
             { accounts =
                 List.init Params.max_accounts_modified_per_zkapp_command
                   ~f:(fun _ ->
                     let a = account () in
                     (Mina_base.Account.identifier a, Some a) )
             ; command =
                 { status = Applied; data = zkapp_command' () }
                 (* the worst case is that no new accounts are created and they are all cached, so we leave this empty *)
             ; new_accounts = []
             } ) )
      zkapp_command_witness

  let signed_command_base_work () :
      Transaction_snark_scan_state.Transaction_with_witness.t =
    base_work
      (fun () ->
        Command
          (Signed_command
             { common =
                 { user_command =
                     { status = Applied; data = signed_command' () }
                 }
             ; body =
                 Payment
                   { new_accounts =
                       [ Mina_base.Account.identifier (account ()) ]
                   }
             } ) )
      signed_command_witness

  let sok_message () : Mina_base.Sok_message.t =
    Mina_base.Sok_message.create ~fee:(fee ()) ~prover:(public_key ())

  let merge_work () :
      Transaction_snark_scan_state.Ledger_proof_with_sok_message.t =
    (ledger_proof (), sok_message ())
end

module Sizes = struct
  let count (type a) (x : a) =
    Obj.(reachable_words @@ repr x) * (Sys.word_size / 8)

  let verification_key = count @@ Values.verification_key ()

  let side_loaded_proof = count @@ Values.side_loaded_proof ()

  let ledger_proof = count @@ Values.ledger_proof ()

  let one_priced_proof = count @@ Values.one_priced_proof ()

  let two_priced_proof = count @@ Values.two_priced_proofs ()

  let signed_command = count @@ Values.signed_command ()

  let zkapp_command = count @@ Values.zkapp_command ()

  let ledger_mask = count @@ Values.ledger_mask ()

  let zkapp_command_base_work = count @@ Values.zkapp_command_base_work ()

  let signed_command_base_work = count @@ Values.signed_command_base_work ()

  let merge_work = count @@ Values.merge_work ()

  type size_params =
    { side_loaded_proof : int
    ; ledger_proof : int
    ; one_priced_proof : int
    ; two_priced_proof : int
    ; signed_command : int
    ; zkapp_command : int
    ; ledger_mask : int
    ; zkapp_command_base_work : int
    ; signed_command_base_work : int
    ; merge_work : int
    }
  [@@deriving sexp]

  let pre_fix =
    { side_loaded_proof
    ; ledger_proof
    ; one_priced_proof
    ; two_priced_proof
    ; signed_command
    ; zkapp_command
    ; ledger_mask
    ; zkapp_command_base_work
    ; signed_command_base_work
    ; merge_work
    }

  let post_fix =
    let cache_ref_size = Sys.word_size / 8 in
    (* ledger witness (x2) + toplevel accounts list on applied command *)
    let num_accounts_in_zkapp_command_base_work =
      Params.max_accounts_modified_per_zkapp_command * 3
    in
    (* ledger witness (x2) + 1 new account *)
    let num_accounts_in_signed_command_base_work =
      (Const.max_accounts_modified_per_signed_command * 2) + 1
    in
    { pre_fix with
      side_loaded_proof = cache_ref_size
    ; ledger_proof =
        cache_ref_size (* replace ledger proofs with content id references *)
    ; one_priced_proof = one_priced_proof - ledger_proof + cache_ref_size
    ; two_priced_proof =
        two_priced_proof - (ledger_proof * 2) + (cache_ref_size * 2)
        (* replace zkapps proofs and verification keys in commands *)
    ; zkapp_command =
        zkapp_command
        - (side_loaded_proof + verification_key - (cache_ref_size * 2))
          * Params.max_zkapp_txn_account_updates
        (* replace verification keys in ledger masks *)
    ; ledger_mask =
        ledger_mask
        - (verification_key - cache_ref_size)
          * Params.max_accounts_modified_per_block
        (* replace side loaded proofs and verification keys from commands embedded in base work, and verification keys in accounts loaded *)
    ; zkapp_command_base_work =
        zkapp_command_base_work
        - (side_loaded_proof + verification_key - (cache_ref_size * 2))
          * Params.max_zkapp_txn_account_updates
        - (verification_key - cache_ref_size)
          * num_accounts_in_zkapp_command_base_work
        (* replace verification keys loaded in accounts of signed command base work *)
    ; signed_command_base_work =
        signed_command_base_work
        - (verification_key - cache_ref_size)
          * num_accounts_in_signed_command_base_work
        (* replace ledger proofs in merge work *)
    ; merge_work = merge_work - ledger_proof + cache_ref_size
    }
end

module Timer : sig
  type t

  val init : unit -> t

  val time : t -> (unit -> 'a) -> 'a

  val total : t -> Time.Span.t
end = struct
  type t = { mutable total : Time.Span.t } [@@deriving fields]

  let init () = { total = Time.Span.zero }

  let time t f =
    let start = Time.now () in
    let x = f () in
    let elapsed = Time.(abs_diff (now ()) start) in
    t.total <- Time.Span.(t.total + elapsed) ;
    x
end

let print_timer name timer =
  let total = Timer.total timer in
  Printf.printf
    !"%s: %{Time.Span} (total: %{Time.Span})\n"
    name
    (Time.Span.of_ns (Time.Span.to_ns total /. Int.to_float bench_count))
    total

let serial_bench (type a) ~(name : string)
    ~(bin_class : a Bin_prot.Type_class.t) ~(gen : a Quickcheck.Generator.t)
    ~(equal : a -> a -> bool) ?(size = 0) () =
  Printf.printf
    "==========================================================================================\n\
     SERIALIZATION BENCHMARKS %s\n\
     ==========================================================================================\n"
    name ;
  let write_timer = Timer.init () in
  let read_timer = Timer.init () in
  for i = 1 to bench_count do
    let random = Splittable_random.State.of_int i in
    let sample = Quickcheck.Generator.generate ~size ~random gen in
    let size = bin_class.writer.size sample in
    let buf = Bigstring.create size in
    let final_pos =
      Timer.time write_timer (fun () ->
          bin_class.writer.write buf ~pos:0 sample )
    in
    assert (final_pos = size) ;
    let result =
      Timer.time read_timer (fun () ->
          bin_class.reader.read buf ~pos_ref:(ref 0) )
    in
    assert (equal sample result)
  done ;
  print_timer "write" write_timer ;
  print_timer "read" read_timer

let compute_ram_usage (sizes : Sizes.size_params) =
  let format_gb size = Int.to_float size /. (1024.0 **. 3.0) in
  (*
  let format_kb size = (Int.to_float size /. 1024.0) in
  Printf.printf "verification key = %fKB, side_loaded_proof = %fKB, account update = %fKB\n, command = %fKB, %d\n"
    (format_kb Sizes.verification_key)
    (format_kb Sizes.side_loaded_proof)
    (format_kb Sizes.zkapp_account_update)
    (format_kb Sizes.zkapp_command)
    Params.max_zkapp_txn_account_updates ;
  *)
  (* this baseline measurement was taken from a fresh daemon, and serves to show the general overhead a daemon has before bootstrapping *)
  let baseline =
    let prover = Int.of_float (1.04 *. 1024.0 *. 1024.0 *. 1024.0) in
    let verifier = 977 * 1024 * 1024 in
    let vrf_evaluator = 127 * 1024 * 1024 in
    let daemon = 966 * 1024 * 1024 in
    (* the libp2p baseline was taken from a seed running on a real network *)
    let libp2p_helper = 3312128 in
    prover + verifier + vrf_evaluator + daemon + libp2p_helper
  in
  (* TODO: actually measure the entire scan state instead of estimating *)
  let scan_states =
    (* for the deltas, the zkapp commands and ledger proofs a shared references to the staged ledger diff we deserialize from the network *)
    (* we assume accounts loaded are not shared since they can all be loaded from the on-disk ledger separately *)
    let deltas =
      let base =
        Params.max_zkapp_commands_per_block
        * (sizes.zkapp_command_base_work - sizes.zkapp_command)
        + (Params.max_signed_commands_per_block * sizes.signed_command_base_work)
      in
      let merge =
        ( Params.max_zkapp_commands_per_block
        + Params.max_signed_commands_per_block - 1 )
        * (sizes.merge_work - sizes.ledger_proof)
      in
      (* the deltas apply for all but the root scan state *)
      (Const.est_scan_states - 1) * (base + merge)
    in
    (* for the root, we cannot subtract out shared references, since the data in the root can be from bootstrap *)
    (* after k blocks, some references can be shared from root history, but not necessarily all *)
    let root =
      let base =
        (Params.max_zkapp_commands_per_block * sizes.zkapp_command_base_work)
        + (Params.max_signed_commands_per_block * sizes.signed_command_base_work)
      in
      let merge i = Int.pow 2 (Const.scan_state_depth - i) * sizes.merge_work in
      List.init (Const.scan_state_depth + 1) ~f:Fn.id
      |> List.sum
           (module Int)
           ~f:(fun i -> (Const.scan_state_delay + 1) * (base + merge i))
    in
    root + deltas
  in
  let ledger_masks = Const.k * sizes.ledger_mask in
  let staged_ledger_diffs =
    (* TODO: coinbases, fee transfers *)
    let zkapp_commands_size_per_block =
      Params.max_zkapp_commands_per_block * sizes.zkapp_command
    in
    let signed_commands_size_per_block =
      Params.max_signed_commands_per_block * sizes.signed_command
    in
    Const.est_blocks_in_frontier
    * (zkapp_commands_size_per_block + signed_commands_size_per_block)
  in
  let snark_pool =
    (* NB: the scan state is split up into (depth+1)+(delay+1) trees, but with different layers
       being built across each tree, they squash down into (delay+1) full trees of work referenced *)
    (* the size of works referenced per a squashed tree; 127 bundles of 2 proofs, 1 bundle of 1
       proof for the root (under the assumption every block is full) *)
    let refernced_size_per_squashed_tree =
      (127 * sizes.two_priced_proof) + sizes.one_priced_proof
    in
    (* the size of work referenced by the root of the frontier *)
    let root_referenced_size =
      (Const.scan_state_delay + 1) * refernced_size_per_squashed_tree
    in
    (* the size of delta references added by each full block in the frontier after the root *)
    let delta_referenced_size = refernced_size_per_squashed_tree in
    root_referenced_size + ((Const.est_scan_states - 1) * delta_referenced_size)
  in
  (* TODO: measure the actuall network pool memory footprint instead of estimating *)
  let transaction_pool = Params.max_txn_pool_size * sizes.zkapp_command in
  let usage_categories =
    [ ("baseline", baseline)
    ; ("scan_states", scan_states)
    ; ("ledger_masks", ledger_masks)
    ; ("staged_ledger_diffs", staged_ledger_diffs)
    ; ("snark_pool", snark_pool)
    ; ("transaction_pool", transaction_pool)
    ]
  in
  List.iter usage_categories ~f:(fun (name, size) ->
      Printf.printf "%s = %fGB\n" name (format_gb size) ) ;
  let total_size =
    List.sum (module Int) usage_categories ~f:(fun (_, size) -> size)
  in
  Printf.printf "TOTAL: %fGB\n" (format_gb total_size)

let () =
  Printf.printf
    "==========================================================================================\n\
     PRE FIX SIZES\n\
     ==========================================================================================\n" ;
  Printf.printf !"%{sexp: Sizes.size_params}\n" Sizes.pre_fix ;
  compute_ram_usage Sizes.pre_fix ;
  Printf.printf "\n" ;
  Printf.printf
    "==========================================================================================\n\
     POST FIX SIZES\n\
     ==========================================================================================\n" ;
  Printf.printf !"%{sexp: Sizes.size_params}\n" Sizes.post_fix ;
  compute_ram_usage Sizes.post_fix ;
  Printf.printf "\n" ;
  serial_bench ~name:"Pickles.Side_loaded.Proof.t"
    ~bin_class:Pickles.Side_loaded.Proof.Stable.Latest.bin_t
    ~gen:(Quickcheck.Generator.return (Values.side_loaded_proof ()))
    ~equal:Pickles.Side_loaded.Proof.equal () ;
  Printf.printf "\n" ;
  serial_bench ~name:"Mina_base.Verification_key_wire.t"
    ~bin_class:Mina_base.Verification_key_wire.Stable.Latest.bin_t
    ~gen:(Quickcheck.Generator.return (Values.verification_key ()))
    ~equal:Mina_base.Verification_key_wire.equal () ;
  Printf.printf "\n" ;
  serial_bench ~name:"Ledger_proof.t"
    ~bin_class:Ledger_proof.Stable.Latest.bin_t
    ~gen:(Quickcheck.Generator.return (Values.ledger_proof ()))
    ~equal:Ledger_proof.equal ()
