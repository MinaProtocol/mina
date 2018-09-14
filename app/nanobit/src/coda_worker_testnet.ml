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

  module Api = struct
    type t =
      { workers: Coda_process.t list
      ; finish_ivar: unit Ivar.t
      ; finished: unit Deferred.t }

    let create workers finish_ivar finished = {workers; finish_ivar; finished}

    let start t i = failwith "nyi"

    let stop t i = failwith "nyi"

    let shutdown_testnet t = Ivar.fill t.finish_ivar () ; t.finished

    let send_transaction t i sk pk amount fee =
      let {workers} = t in
      Coda_process.send_transaction_exn (List.nth_exn workers i) sk pk amount
        fee
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

  let start_checks log workers proposal_interval =
    don't_wait_for
      (let%map transitions =
         Deferred.List.all
           (List.map workers ~f:(fun w -> Coda_process.strongest_ledgers_exn w))
       in
       start_prefix_check log transitions proposal_interval ;
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
    let ready =
      Deferred.create (fun ready_ivar ->
          let fill_ready = ref None in
          let finished =
            let%bind program_dir = Unix.getcwd () in
            Coda_processes.init () ;
            Coda_processes.spawn_local_processes_exn n ~proposal_interval
              ~program_dir ~should_propose
              ~snark_worker_public_keys:
                (Some (List.init n snark_work_public_keys))
              ~f:(fun workers ->
                let%bind () =
                  Deferred.create (fun finish_ivar ->
                      start_checks log workers proposal_interval ;
                      Option.value_exn !fill_ready (workers, finish_ivar) )
                in
                return () )
          in
          fill_ready :=
            Some
              (fun (workers, finish_ivar) ->
                let api = Api.create workers finish_ivar finished in
                Ivar.fill ready_ivar api ) )
    in
    ready
end
