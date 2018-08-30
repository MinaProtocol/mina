open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) :
  Integration_test_intf.S =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  let name = "coda-shared-prefix-test"

  let main who_proposes () =
    let%bind program_dir = Unix.getcwd () in
    let n = 2 in
    let log = Logger.create () in
    let log = Logger.child log name in
    Coda_processes.init () ;
    Coda_processes.spawn_local_processes_exn n ~program_dir
      ~should_propose:(fun i -> i = who_proposes)
      ~f:(fun workers ->
        let chains = Array.init (List.length workers) ~f:(fun _ -> []) in
        let check_chains () =
          let lengths =
            Array.to_list (Array.map chains ~f:(fun c -> List.length c))
          in
          let first = chains.(0) in
          let rest = Array.slice chains 1 0 in
          let newest_shared =
            List.find first ~f:(fun x ->
                Array.for_all rest ~f:(fun c ->
                    List.exists c ~f:(fun y -> x = y) ) )
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
          let shared_prefix_dist = shared_idx in
          Logger.info log
            !"lengths: %{sexp: int list} shared_prefix: %{sexp: string \
              option} shared_prefix_dist: %d"
            lengths newest_shared shared_prefix_dist ;
          assert (shared_prefix_dist <= 5) ;
          if Array.fold ~init:0 (Array.map chains List.length) ~f:Int.max > 30
          then exit 0
          else Deferred.unit
        in
        let%bind () =
          Deferred.List.all_unit
            (List.mapi workers ~f:(fun i worker ->
                 let%bind strongest_ledgers =
                   Coda_process.strongest_ledgers_exn worker
                 in
                 don't_wait_for
                   (Linear_pipe.iter strongest_ledgers ~f:(fun (prev, curr) ->
                        let bits_to_str b =
                          let str =
                            String.concat
                              (List.map b ~f:(fun x -> if x then "1" else "0"))
                          in
                          let hash = Md5.digest_string str in
                          Md5.to_hex hash
                        in
                        let prev_str = bits_to_str prev in
                        let curr_str = bits_to_str curr in
                        let chain = chains.(i) in
                        let chain = curr_str :: chain in
                        chains.(i) <- chain ;
                        let%bind () = check_chains () in
                        Logger.debug log "%d got tip %s %s" i prev_str curr_str ;
                        return () )) ;
                 Deferred.unit ))
        in
        let%bind () = after (Time.Span.of_sec 1000000.) in
        return () )

  let command =
    let open Command.Let_syntax in
    Command.async ~summary:"Test that workers share prefixes"
      (let%map_open who_proposes =
        flag "who-proposes" ~doc:"ID node number which will be proposing" (required int) in
        main who_proposes)
end
