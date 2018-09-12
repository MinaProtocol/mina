open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  type api =
    { stop: int -> unit
    ; start: int -> unit
    ; send_transaction:
           int
        -> Private_key.t
        -> Public_key.Compressed.t
        -> Currency.Amount.t
        -> Currency.Fee.t
        -> unit Deferred.t }

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

  let start_checks log workers proposal_interval =
    don't_wait_for
      (let%map transitions =
         Deferred.List.all
           (List.map workers ~f:(fun w -> Coda_process.strongest_ledgers_exn w))
       in
       start_prefix_check log transitions proposal_interval ;
       ())

  (* note: this is very declarative, maybe this should be more imperative? *)
  (* step 2:
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
  let test ?(proposal_interval= 1000) log n should_propose
      snark_work_public_keys =
    let log = Logger.child log "worker_testnet" in
    let ready =
      Deferred.create (fun ready_ivar ->
          let fill_ready = ref None in
          let finished =
            Deferred.create (fun finished_ivar ->
                don't_wait_for
                  (let%bind program_dir = Unix.getcwd () in
                   Coda_processes.init () ;
                   let%map () =
                     Coda_processes.spawn_local_processes_exn n
                       ~proposal_interval ~program_dir ~should_propose
                       ~snark_worker_public_keys:
                         (Some (List.init n snark_work_public_keys))
                       ~f:(fun workers ->
                         start_checks log workers proposal_interval ;
                         Option.value_exn !fill_ready workers ;
                         return () )
                   in
                   Ivar.fill finished_ivar ()) )
          in
          fill_ready :=
            Some
              (fun workers ->
                let api =
                  { stop= (fun i -> failwith "nyi")
                  ; start= (fun i -> failwith "nyi")
                  ; send_transaction=
                      (fun i sk pk amount fee ->
                        Coda_process.send_transaction_exn
                          (List.nth_exn workers i) sk pk amount fee ) }
                in
                Ivar.fill ready_ivar (api, finished) ) )
    in
    ready
end
