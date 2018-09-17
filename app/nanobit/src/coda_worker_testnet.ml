open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib
open Nanobit_base

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  module Api = struct
    type t =
      { workers: Coda_process.t list
      ; transaction_writer:
          ( int
          * Private_key.t
          * Public_key.Compressed.t
          * Currency.Amount.t
          * Currency.Fee.t )
          Linear_pipe.Writer.t }

    let create workers transaction_writer = {workers; transaction_writer}

    let start t i = failwith "nyi"

    let stop t i = failwith "nyi"

    let send_transaction t i sk pk amount fee =
      Linear_pipe.write t.transaction_writer (i, sk, pk, amount, fee)
  end

  let start_prefix_check log transitions proposal_interval =
    let all_transitions_r, all_transitions_w = Linear_pipe.create () in
    let chains = Array.init (List.length transitions) ~f:(fun i -> []) in
    let check_chains chains =
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
         (Linear_pipe.fold ~init:chains all_transitions_r ~f:
            (fun chains (prev, curr, i) ->
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
    List.iteri transitions ~f:(fun i transitions ->
        don't_wait_for
          (Linear_pipe.iter transitions ~f:(fun (prev, curr) ->
               Linear_pipe.write all_transitions_w (prev, curr, i) )) )

  let start_transaction_check log transitions transactions workers
      proposal_interval =
    let block_counts = Array.init (List.length workers) ~f:(fun _ -> 0) in
    let active_accounts = ref [] in
    let get_balances pk =
      Deferred.List.all
        (List.map workers ~f:(fun w -> Coda_process.get_balance_exn w pk))
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
        Deferred.List.filter !active_accounts ~f:
          (fun (pk, send_block_counts, send_balances) ->
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
                     if balance <> send_balance then return true
                     else
                       let diff = current_block_count - send_block_count in
                       Logger.warn log
                         !"%d balance not yet updated %{sexp: \
                           Currency.Balance.t option} %d"
                         i balance diff ;
                       if diff >= 5 then (
                         Logger.fatal log "balance took too long to update" ;
                         ignore (exit 1) ) ;
                       return false ))
            in
            let all_done = List.for_all dones ~f:Fn.id in
            if all_done then false else true )
      in
      active_accounts := new_aa
    in
    List.iteri transitions ~f:(fun i transition ->
        don't_wait_for
          (Linear_pipe.iter transition ~f:(fun t ->
               block_counts.(i) <- 1 + block_counts.(i) ;
               Deferred.unit )) ) ;
    don't_wait_for
      (Linear_pipe.iter transactions ~f:(fun (i, sk, pk, amount, fee) ->
           let%bind () = add_to_active_accounts pk in
           Coda_process.send_transaction_exn (List.nth_exn workers i) sk pk
             amount fee )) ;
    don't_wait_for
      (let rec go () =
         let%bind () = check_active_accounts () in
         let%bind () = after (Time.Span.of_sec 0.5) in
         go ()
       in
       go ()) ;
    ()

  let start_checks log workers proposal_interval transaction_reader =
    don't_wait_for
      (let%map transitions =
         Deferred.List.all
           (List.map workers ~f:(fun w -> Coda_process.strongest_ledgers_exn w))
       in
       let transitions =
         List.map transitions ~f:(fun t -> Linear_pipe.fork2 t)
       in
       let prefix_transitions = List.map transitions ~f:fst in
       let transaction_transitions = List.map transitions ~f:snd in
       start_prefix_check log prefix_transitions proposal_interval ;
       start_transaction_check log transaction_transitions transaction_reader
         workers proposal_interval ;
       ())

  (* note: this is very declarative, maybe this should be more imperative? *)
  (* next steps:
   *   add more powerful api hooks to enable sending transactions on certain conditions
   *   implement stop/start
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
  let test ?(proposal_interval= 1000) log n should_propose
      snark_work_public_keys =
    let log = Logger.child log "worker_testnet" in
    let%bind program_dir = Unix.getcwd () in
    Coda_processes.init () ;
    let configs =
      Coda_processes.local_configs n ~proposal_interval ~program_dir
        ~should_propose
        ~snark_worker_public_keys:(Some (List.init n snark_work_public_keys))
    in
    let%map workers = Coda_processes.spawn_local_processes_exn configs in
    let transaction_reader, transaction_writer = Linear_pipe.create () in
    let api = Api.create workers transaction_writer in
    start_checks log workers proposal_interval transaction_reader ;
    api
end
