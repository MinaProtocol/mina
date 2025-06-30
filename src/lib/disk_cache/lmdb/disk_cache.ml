(* Cache proofs using the lmdb *)

open Core
open Lmdb_storage.Generic

module type Config = sig
  val config : config
end

module Make_with_config (Data : Binable.S) (Config : Config) = struct
  module F (Db : Db) = struct
    type holder = (int, Data.t) Db.t

    let mk_maps { Db.create } =
      create Lmdb_storage.Conv.uint32_be
        (Lmdb_storage.Conv.bin_prot_conv Data.bin_t)

    let config = Config.config
  end

  module Rw = Read_write (F)

  type t = { env : Rw.t; db : Rw.holder; counter : int ref }

  let initialize path ~logger =
    Async.Deferred.Result.map (Disk_cache_utils.initialize_dir path ~logger)
      ~f:(fun path ->
        let env, db = Rw.create path in
        { env; db; counter = ref 0 } )

  type id = { idx : int }

  let get ({ env; db; _ } : t) ({ idx } : id) : Data.t =
    Rw.get ~env db idx |> Option.value_exn

  let put ({ env; db; counter } : t) (x : Data.t) : id =
    let idx = !counter in
    incr counter ;
    let res = { idx } in
    (* When this reference is GC'd, delete the file. *)
    Gc.Expert.add_finalizer_last_exn res (fun () -> Rw.remove ~env db idx) ;
    Rw.set ~env db idx x ;
    res

  let iteri ({ env; db; _ } : t) ~f = Rw.iter ~env db ~f

  let count ({ env; db; _ } : t) =
    let sum = ref 0 in
    Rw.iter ~env db ~f:(fun _ _ -> incr sum ; `Continue) ;
    !sum

  let int_of_id { idx } = idx
end

module Make (Data : Binable.S) = struct
  include
    Make_with_config
      (Data)
      (struct
        let config = { default_config with initial_mmap_size = 256 lsl 20 }
      end)
end

let%test_module "disk_cache lmdb" =
  ( module struct
    include Disk_cache_test_lib.Make_extended (Make)

    let%test_unit "remove data on gc" = remove_data_on_gc ()

    let%test_unit "simple read/write (with iteration)" =
      simple_write_with_iteration ()

    let%test_unit "initialization special cases" =
      initialization_special_cases ()
  end )

let%test_module "disk_cache lmdb stress" =
  ( module struct
    open Async

    (* Formula for memory usage: 2^(max_cycle + 1) * proof_string_length bytes *)

    let max_cycle = 15

    let proof_string_length = 1 lsl 16

    let minor_gc_every = Time.Span.of_sec 0.2

    let random_proof () =
      let gen_char _ =
        let charset =
          "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        in
        charset.[Random.int (String.length charset)]
      in
      String.init proof_string_length ~f:gen_char

    include
      Make_with_config
        (Disk_cache_test_lib.Mock)
        (struct
          let config =
            { initial_mmap_size = 64 (* 64 Bytes *)
            ; mmap_growth_factor = 1.2
            ; mmap_growth_max_step = 4 lsl 30 (* 4 GiB *)
            }
        end)

    let logger = Logger.create ()

    let%test_unit "simple stress test with minor GC" =
      let succeeding = ref true in
      let stress_test_done = ref false in
      (* Assumption: writing to LMDB is blocking so we tracks `next_slot` correctly *)
      let rec minor_gc_loop () =
        if !stress_test_done then Deferred.unit
        else
          let%bind () = after minor_gc_every in
          [%log info] "Triggering minor GC" ;
          Gc.minor () ;
          minor_gc_loop ()
      in
      let impl path =
        let%bind cache_or_exn = initialize path ~logger in
        let cache =
          match cache_or_exn with
          | Ok cache ->
              cache
          | Error (`Initialization_error err) ->
              raise (Error.to_exn err)
        in
        let all_proofs =
          Array.create ~len:((1 lsl (max_cycle + 1)) - 1) ({ idx = 0 }, "")
        in
        let next_slot = ref 0 in
        let rec do_cycle this_cycle =
          [%log info] "Stress cycle" ~metadata:[ ("id", `Int this_cycle) ] ;
          (* Put 2^i items in the cache *)
          let put_jobs =
            List.init (1 lsl this_cycle) ~f:(fun _ ->
                let%map () = after Time.Span.zero in
                let this_pf = random_proof () in
                let this_slot = !next_slot in

                let ({ idx = id_unwrapped } as cached) =
                  put cache { proof = this_pf }
                in
                [%log info] "Caching proof"
                  ~metadata:[ ("id", `Int id_unwrapped) ] ;
                all_proofs.(this_slot) <- (cached, this_pf) ;
                next_slot := !next_slot + 1 )
          in
          (* Read 2^i items from the cache *)
          let get_jobs =
            List.init (1 lsl this_cycle) ~f:(fun _ ->
                let%map () = after Time.Span.zero in
                let this_slot = Random.int_incl 0 (!next_slot - 1) in
                let proof_id, proof_expected = all_proofs.(this_slot) in
                let Disk_cache_test_lib.Mock.{ proof = proof_actual } =
                  get cache proof_id
                in
                let { idx = id_unwrapped } = proof_id in

                if not (String.equal proof_expected proof_actual) then (
                  [%log fatal] "Cached proof mismatch between LMDB and memory!"
                    ~metadata:
                      [ ("id", `Int id_unwrapped)
                      ; ("expected", `String proof_expected)
                      ; ("actual", `String proof_actual)
                      ] ;
                  succeeding := false )
                else
                  [%log info] "Uncached proof successfully"
                    ~metadata:[ ("id", `Int id_unwrapped) ] )
          in
          (* get jobs may get scheduled before put jobs, but it should be fine *)
          let%bind _ = put_jobs @ get_jobs |> Deferred.all in
          if this_cycle = max_cycle then (
            stress_test_done := true ;
            assert !succeeding ;
            Deferred.unit )
          else do_cycle (this_cycle + 1)
        in
        Deferred.both (minor_gc_loop ()) (do_cycle 1) |> Deferred.ignore_m
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "disk-cache-lmdb-stress-simple" ~f:impl )
  end )
