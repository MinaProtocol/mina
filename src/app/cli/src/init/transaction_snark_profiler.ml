open Core
open Snark_profiler_lib

let name = "transaction-snark-profiler"

let run ~genesis_constants ~constraint_constants ~proof_level
    ~user_command_profiler ~zkapp_profiler num_transactions ~max_num_updates
    ?min_num_updates repeats preeval use_zkapps : unit =
  let logger = Logger.null () in
  let print n msg = printf !"[%i] %s\n%!" n msg in
  if use_zkapps then (
    let ledger, transactions =
      Async.Thread_safe.block_on_async_exn (fun () ->
          create_ledger_and_zkapps ~genesis_constants ~constraint_constants
            ?min_num_updates ~max_num_updates () )
    in
    Parallel.init_master () ;
    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~commit_id:Mina_version.commit_id ~logger ~proof_level
            ~constraint_constants ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )
    in
    let rec go n =
      if n <= 0 then ()
      else
        let message =
          Async.Thread_safe.block_on_async_exn (fun () ->
              zkapp_profiler ~verifier ledger transactions )
        in
        print n message ;
        go (n - 1)
    in
    go repeats )
  else
    let ledger, transactions =
      create_ledger_and_transactions ~constraint_constants num_transactions
    in
    let sparse_ledger =
      Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger
        (List.fold ~init:[] transactions ~f:(fun participants t ->
             List.rev_append
               (Mina_transaction.Transaction.accounts_referenced
                  (Mina_transaction.Transaction.forget t) )
               participants ) )
    in
    let rec go n =
      if n <= 0 then ()
      else
        let message =
          Async.Thread_safe.block_on_async_exn (fun () ->
              user_command_profiler sparse_ledger transactions preeval )
        in
        print n message ;
        go (n - 1)
    in
    go repeats

let dry ~genesis_constants ~constraint_constants ~proof_level ~max_num_updates
    ?min_num_updates num_transactions repeats preeval use_zkapps () =
  let zkapp_profiler ~verifier:_ _ _ =
    failwith "Can't check base SNARKs on zkApps"
  in
  Test_util.with_randomness 123456789 (fun () ->
      run ~genesis_constants ~constraint_constants ~proof_level
        ~user_command_profiler:
          (check_base_snarks ~genesis_constants ~constraint_constants)
        ~zkapp_profiler num_transactions ~max_num_updates ?min_num_updates
        repeats preeval use_zkapps )

let witness ~genesis_constants ~constraint_constants ~proof_level
    ~max_num_updates ?min_num_updates num_transactions repeats preeval
    use_zkapps () =
  let zkapp_profiler ~verifier:_ _ _ =
    failwith "Can't generate witnesses for base SNARKs on zkApps"
  in
  Test_util.with_randomness 123456789 (fun () ->
      run ~genesis_constants ~constraint_constants ~proof_level
        ~user_command_profiler:
          (generate_base_snarks_witness ~genesis_constants ~constraint_constants)
        ~zkapp_profiler num_transactions ~max_num_updates ?min_num_updates
        repeats preeval use_zkapps )

let main ~(genesis_constants : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~proof_level ~max_num_updates ?min_num_updates num_transactions repeats
    preeval use_zkapps () =
  Test_util.with_randomness 123456789 (fun () ->
      let module T = Transaction_snark.Make (struct
        let constraint_constants = constraint_constants

        let proof_level = proof_level
      end) in
      run ~genesis_constants ~constraint_constants ~proof_level
        ~user_command_profiler:
          (profile_user_command ~genesis_constants ~constraint_constants
             (module T) )
        ~zkapp_profiler:(profile_zkapps ~constraint_constants)
        num_transactions ~max_num_updates ?min_num_updates repeats preeval
        use_zkapps )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler"
    (let%map_open n =
       flag "--k" ~aliases:[ "-k" ]
         ~doc:
           "count count = log_2(number of transactions to snark); omit for \
            mocked transactions"
         (optional int)
     and repeats =
       flag "--repeat" ~aliases:[ "-repeat" ]
         ~doc:"count number of times to repeat the profile" (optional int)
     and preeval =
       flag "--preeval" ~aliases:[ "-preeval" ]
         ~doc:
           "true/false whether to pre-evaluate the checked computation to \
            cache interpreter and computation state (payments only)"
         (optional bool)
     and check_only =
       flag "--check-only" ~aliases:[ "-check-only" ]
         ~doc:
           "Just check base snarks, don't keys or time anything (payments only)"
         no_arg
     and witness_only =
       flag "--witness-only" ~aliases:[ "-witness-only" ]
         ~doc:"Just generate the witnesses for the base snarks (payments only)"
         no_arg
     and use_zkapps =
       flag "--zkapps" ~aliases:[ "-zkapps" ]
         ~doc:
           "Use zkApp transactions instead of payments; Generates all \
            permutation of proof and non-proof updates"
         no_arg
     and max_num_updates =
       flag "--max-num-updates" ~aliases:[ "-max-num-updates" ]
         ~doc:
           "Maximum number of account updates per transaction (excluding the \
            fee payer). Default:6"
         (optional int)
     and min_num_updates =
       flag "--min-num-updates" ~aliases:[ "-min-num-updates" ]
         ~doc:
           "Minimum number of account updates per transaction (excluding the \
            fee payer). Minimum: 1 Default: 1 "
         (optional int)
     in
     let num_transactions =
       Option.map n ~f:(fun n -> `Count (Int.pow 2 n))
       |> Option.value ~default:`Two_from_same
     in
     let max_num_updates = Option.value max_num_updates ~default:6 in
     Option.value_map ~default:() min_num_updates ~f:(fun m ->
         if m > max_num_updates then
           failwith
             "min-num-updates should be less than or equal to max-num-updates" ) ;
     if use_zkapps then (
       let incompatible_flags = ref [] in
       let add_incompatible_flag flag =
         incompatible_flags := flag :: !incompatible_flags
       in
       ( match preeval with
       | None ->
           ()
       | Some b ->
           if b then add_incompatible_flag "--preeval true" ) ;
       if check_only then add_incompatible_flag "--check-only" ;
       if witness_only then add_incompatible_flag "--witness-only" ;
       if not @@ List.is_empty !incompatible_flags then (
         eprintf "These flags are incompatible with --zkapps: %s\n"
           (String.concat !incompatible_flags ~sep:", ") ;
         exit 1 ) ) ;
     let repeats = Option.value repeats ~default:1 in
     let genesis_constants = Genesis_constants.Compiled.genesis_constants in
     let constraint_constants =
       Genesis_constants.Compiled.constraint_constants
     in
     let proof_level = Genesis_constants.Proof_level.Full in
     if witness_only then
       witness ~genesis_constants ~constraint_constants ~proof_level
         ~max_num_updates ?min_num_updates num_transactions repeats preeval
         use_zkapps
     else if check_only then
       dry ~genesis_constants ~constraint_constants ~proof_level
         ~max_num_updates ?min_num_updates num_transactions repeats preeval
         use_zkapps
     else
       main ~genesis_constants ~constraint_constants ~proof_level
         ~max_num_updates ?min_num_updates num_transactions repeats preeval
         use_zkapps )
