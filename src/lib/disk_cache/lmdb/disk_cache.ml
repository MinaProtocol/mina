(* Cache proofs using the lmdb *)

open Core
open Lmdb_storage.Generic

module Make (Data : Binable.S) = struct
  module F (Db : Db) = struct
    type holder = (int, Data.t) Db.t

    let mk_maps { Db.create } =
      create Lmdb_storage.Conv.uint32_be
        (Lmdb_storage.Conv.bin_prot_conv Data.bin_t)

    let config = { default_config with initial_mmap_size = 256 lsl 20 }
  end

  module Rw = Read_write (F)

  type t =
    { env : Rw.t
    ; db : Rw.holder
    ; counter : int ref
    ; reusable_keys : int Queue.t
          (** A list of ids that are no longer reachable from OCaml runtime, but
              haven't been cleared inside the LMDB disk cache *)
    ; queue_guard : Error_checking_mutex.t
    ; eviction_freezed : bool ref
    ; disk_meta_location : string option
    }

  type persistence = int [@@deriving bin_io_unversioned]

  (** How big can the queue [reusable_keys] be before we do a cleanup *)
  let reuse_size_limit = 512

  let freeze_eviction_and_snapshot ~logger
      ({ eviction_freezed; counter; disk_meta_location; _ } : t) =
    eviction_freezed := true ;
    match disk_meta_location with
    | None ->
        [%log info]
          "No metadata location is set for LMDB disk cache, not saving disk \
           cache persistence information" ;
        Async.Deferred.unit
    | Some disk_meta_location ->
        Async_unix.Writer.save_bin_prot disk_meta_location
          bin_writer_persistence !counter

  let initialize path ~logger ?disk_meta_location () =
    let open Async in
    let open Deferred.Let_syntax in
    let%bind counter =
      match disk_meta_location with
      | None ->
          return 0
      | Some disk_meta_location -> (
          match%map
            Async.Reader.load_bin_prot disk_meta_location bin_reader_persistence
          with
          | Error e ->
              [%log warn]
                "Failed to read LMDB disk cache persistence information from \
                 disk $location, initializing a fresh cache"
                ~metadata:
                  [ ("location", `String disk_meta_location)
                  ; ("reason", `String (Error.to_string_hum e))
                  ] ;
              0
          | Ok idx ->
              [%log info]
                "Successfully restored LMDB disk cacahe persistence from disk \
                 $location"
                ~metadata:[ ("location", `String disk_meta_location) ] ;
              idx )
    in
    Async.Deferred.Result.map (Disk_cache_utils.initialize_dir path ~logger)
      ~f:(fun path ->
        let env, db = Rw.create path in
        let cache =
          { env
          ; db
          ; counter = ref counter
          ; reusable_keys = Queue.create ()
          ; queue_guard = Error_checking_mutex.create ()
          ; eviction_freezed = ref false
          ; disk_meta_location
          }
        in

        Option.iter disk_meta_location ~f:(fun _ ->
            Mina_stdlib_unix.Exit_handlers.register_async_shutdown_handler
              ~logger
              ~description:
                "Shutting down LMDB Disk Cache GC Eviction and store \
                 persistence info needed to reload from disk" (fun () ->
                freeze_eviction_and_snapshot ~logger cache ) ) ;
        cache )

  type id = { idx : int } [@@deriving bin_io_unversioned]

  let get ({ env; db; _ } : t) ({ idx } : id) : Data.t =
    Rw.get ~env db idx
    |> Option.value_exn
         ~message:
           (Printf.sprintf "Trying to access non-existent cache item %d" idx)

  let register_gc ~(id : id)
      ({ reusable_keys; queue_guard; eviction_freezed; _ } : t) =
    let { idx } = id in
    (* When this reference is GC'd, delete the file. *)
    Gc.Expert.add_finalizer_last_exn id (fun () ->
        if not !eviction_freezed then
          (* The actual deletion is delayed, as GC maybe triggered in LMDB's
             critical section. LMDB critical section then will be re-entered if
             it's invoked directly in a GC hook.
             This causes mutex double-acquiring and node freezes. *)
          Error_checking_mutex.critical_section queue_guard ~f:(fun () ->
              Queue.enqueue reusable_keys idx ) )

  let try_get_deserialized ({ env; db; _ } as t : t) ({ idx } as id : id) :
      Data.t option =
    Rw.get ~env db idx |> Option.map ~f:(fun data -> register_gc ~id t ; data)

  (* WARN: Don't try to be smart here and reuse LMDB keys, as SNARK pool
     persistence will try to read from disk and trusting the ID they have
     correspond to the proofs in Cache DB. If reused, we need a mechanism to
     sync IDs between the 2 which is complex.
  *)
  let put ({ env; db; counter; reusable_keys; queue_guard; _ } as t : t)
      (x : Data.t) : id =
    let idx = !counter in
    incr counter ;
    let id = { idx } in
    register_gc ~id t ;
    Error_checking_mutex.critical_section queue_guard ~f:(fun () ->
        if Queue.length reusable_keys >= reuse_size_limit then (
          Rw.batch_remove ~env db reusable_keys ;
          Queue.clear reusable_keys ) ) ;
    Rw.set ~env db idx x ;
    id

  let iteri ({ env; db; _ } : t) ~f = Rw.iter ~env db ~f

  let count ({ env; db; _ } : t) =
    let sum = ref 0 in
    Rw.iter ~env db ~f:(fun _ _ -> incr sum ; `Continue) ;
    !sum

  let int_of_id { idx } = idx
end

let%test_module "disk_cache lmdb" =
  ( module struct
    include Disk_cache_test_lib.Make_extended (Make)

    let%test_unit "remove data on gc" = remove_data_on_gc ~gc_strict:false ()

    let%test_unit "simple read/write (with iteration)" =
      simple_write_with_iteration ()

    let%test_unit "initialization special cases" =
      initialization_special_cases ()
  end )
