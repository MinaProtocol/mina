open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib
open Coda_base

module Make (Kernel : Kernel_intf) = struct
  module Coda_processes = Coda_processes.Make (Kernel)
  open Coda_processes

  module Api = struct
    type t =
      { workers: Coda_process.t list
      ; configs: Coda_process.Coda_worker.Input.t list
      ; start_writer:
          (int * Coda_process.Coda_worker.Input.t * (unit -> unit))
          Linear_pipe.Writer.t
      ; online: bool Array.t
      ; payment_writer:
          ( int
          * Private_key.t
          * Public_key.Compressed.t
          * Currency.Amount.t
          * Currency.Fee.t )
          Linear_pipe.Writer.t }

    let create configs workers payment_writer start_writer =
      let online = Array.init (List.length workers) ~f:(fun _ -> true) in
      {workers; configs; start_writer; online; payment_writer}

    let online t i = t.online.(i)

    let get_balance t i pk =
      let worker = List.nth_exn t.workers i in
      if online t i then
        Deferred.map (Coda_process.get_balance_exn worker pk) ~f:(fun x ->
            Some x )
      else return None

    let start t i =
      Linear_pipe.write t.start_writer
        (i, List.nth_exn t.configs i, fun () -> t.online.(i) <- true)

    let stop t i =
      t.online.(i) <- false ;
      Coda_process.disconnect (List.nth_exn t.workers i)

    let send_payment t i sk pk amount fee =
      Linear_pipe.write t.payment_writer (i, sk, pk, amount, fee)
  end

  let start_prefix_check log workers events proposal_interval testnet =
    let all_transitions_r, all_transitions_w = Linear_pipe.create () in
    let chains = Array.init (List.length workers) ~f:(fun i -> []) in
    let check_chains chains =
      let chains = Array.filteri chains ~f:(fun i c -> Api.online testnet i) in
      let lengths =
        Array.to_list (Array.map chains ~f:(fun c -> List.length c))
      in
      let first = chains.(0) in
      let rest = Array.slice chains 1 0 in
      let newest_shared =
        List.find first ~f:(fun x ->
            Array.for_all rest ~f:(fun c -> List.exists c ~f:(fun y -> x = y))
        )
      in
      let shared_idx =
        match newest_shared with
        | None -> List.length first
        | Some shared ->
            Option.value_exn
              (Option.map
                 (List.findi first ~f:(fun _ x -> x = shared))
                 ~f:(fun x -> fst x))
      in
      let shared_prefix_age = shared_idx in
      Logger.info log
        !"lengths: %{sexp: int list} shared_prefix: %{sexp: string option} \
          shared_prefix_age: %d"
        lengths newest_shared shared_prefix_age ;
      if not (shared_prefix_age <= 5) then (
        Logger.fatal log "prefix too old" ;
        ignore (exit 1) ) ;
      ()
    in
    let last_time = ref (Time.now ()) in
    don't_wait_for
      (let epsilon = 0.5 in
       let rec go () =
         let diff = Time.diff (Time.now ()) !last_time in
         let diff = Time.Span.to_sec diff in
         if not (diff < (Float.of_int proposal_interval /. 1000.) +. epsilon)
         then (
           Logger.fatal log "no recent blocks" ;
           ignore (exit 1) ) ;
         let%bind () = after (Time.Span.of_sec 1.0) in
         go ()
       in
       go ()) ;
    don't_wait_for
      (Deferred.ignore
         (Linear_pipe.fold ~init:chains all_transitions_r
            ~f:(fun chains (prev, curr, i) ->
              let bits_to_str b =
                let str =
                  String.concat
                    (List.map b ~f:(fun x -> if x then "1" else "0"))
                in
                let hash = Md5.digest_string str in
                Md5.to_hex hash
              in
              let curr = bits_to_str curr in
              let chain = chains.(i) in
              let chain = curr :: chain in
              last_time := Time.now () ;
              chains.(i) <- chain ;
              check_chains chains ;
              return chains ))) ;
    don't_wait_for
      (Linear_pipe.iter events ~f:(function `Transition (i, (prev, curr)) ->
           Linear_pipe.write all_transitions_w (prev, curr, i) ))

  let start_payment_check log events payments workers proposal_interval testnet
      =
    let block_counts = Array.init (List.length workers) ~f:(fun _ -> 0) in
    let active_accounts = ref [] in
    let get_balances pk =
      Deferred.List.all
        (List.mapi workers ~f:(fun i w -> Api.get_balance testnet i pk))
    in
    let add_to_active_accounts pk =
      match List.findi !active_accounts ~f:(fun i (apk, _, _) -> apk = pk) with
      | None ->
          let%map balances = get_balances pk in
          let send_block_counts = Array.to_list block_counts in
          assert (List.length balances = List.length send_block_counts) ;
          active_accounts :=
            (pk, send_block_counts, balances) :: !active_accounts
      | Some (i, a) -> return ()
    in
    let check_active_accounts () =
      let%map new_aa =
        Deferred.List.filter !active_accounts
          ~f:(fun (pk, send_block_counts, send_balances) ->
            let%bind balances = get_balances pk in
            let current_block_counts = Array.to_list block_counts in
            let%map dones =
              Deferred.List.all
                (List.init (List.length send_block_counts) ~f:(fun i ->
                     let balance = List.nth_exn balances i in
                     let send_block_count = List.nth_exn send_block_counts i in
                     let current_block_count =
                       List.nth_exn current_block_counts i
                     in
                     let send_balance = List.nth_exn send_balances i in
                     if Option.is_none balance || Option.is_none send_balance
                     then return true
                     else if balance <> send_balance then return true
                     else
                       let diff = current_block_count - send_block_count in
                       Logger.warn log
                         !"%d balance not yet updated %{sexp: \
                           Currency.Balance.t option option} %d"
                         i balance diff ;
                       if diff >= 7 then (
                         Logger.fatal log "balance took too long to update" ;
                         ignore (exit 1) ) ;
                       return false ))
            in
            let all_done = List.for_all dones ~f:Fn.id in
            if all_done then false else true )
      in
      active_accounts := new_aa
    in
    don't_wait_for
      (Linear_pipe.iter events ~f:(function `Transition (i, t) ->
           block_counts.(i) <- 1 + block_counts.(i) ;
           Deferred.unit )) ;
    don't_wait_for
      (Linear_pipe.iter payments ~f:(fun (i, sk, pk, amount, fee) ->
           let%bind () = add_to_active_accounts pk in
           Coda_process.send_payment_exn (List.nth_exn workers i) sk pk amount
             fee User_command_memo.dummy )) ;
    don't_wait_for
      (let rec go () =
         let%bind () = check_active_accounts () in
         let%bind () = after (Time.Span.of_sec 0.5) in
         go ()
       in
       go ()) ;
    ()

  let events workers start_reader =
    let event_r, event_w = Linear_pipe.create () in
    let connect_worker i worker =
      let%bind transitions = Coda_process.strongest_ledgers_exn worker in
      Linear_pipe.iter transitions ~f:(fun t ->
          Linear_pipe.write event_w (`Transition (i, t)) )
    in
    don't_wait_for
      (Linear_pipe.iter start_reader ~f:(fun (i, config, started) ->
           don't_wait_for
             (let%bind worker = Coda_process.spawn_exn config in
              don't_wait_for
                (let secs_to_catch_up = 10.0 in
                 let%map () = after (Time.Span.of_sec secs_to_catch_up) in
                 started ()) ;
              connect_worker i worker) ;
           Deferred.unit )) ;
    List.iteri workers ~f:(fun i w -> don't_wait_for (connect_worker i w)) ;
    event_r

  let start_checks log workers proposal_interval payment_reader start_reader
      testnet =
    let event_pipe = events workers start_reader in
    let prefix_events, payment_events = Linear_pipe.fork2 event_pipe in
    start_prefix_check log workers prefix_events proposal_interval testnet ;
    start_payment_check log payment_events payment_reader workers
      proposal_interval testnet

  (* note: this is very declarative, maybe this should be more imperative? *)
  (* next steps:
   *   add more powerful api hooks to enable sending payments on certain conditions
   *   implement stop/start
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
  let test log n should_propose snark_work_public_keys work_selection =
    let log = Logger.child log "worker_testnet" in
    let proposal_interval =
      Int64.to_int_exn Kernel.Consensus_mechanism.block_interval_ms
    in
    let%bind program_dir = Unix.getcwd () in
    Coda_processes.init () ;
    let configs =
      Coda_processes.local_configs n ~proposal_interval ~program_dir
        ~should_propose
        ~snark_worker_public_keys:(Some (List.init n snark_work_public_keys))
        ~work_selection
    in
    let%map workers = Coda_processes.spawn_local_processes_exn configs in
    let payment_reader, payment_writer = Linear_pipe.create () in
    let start_reader, start_writer = Linear_pipe.create () in
    let testnet = Api.create configs workers payment_writer start_writer in
    start_checks log workers proposal_interval payment_reader start_reader
      testnet ;
    testnet
end
