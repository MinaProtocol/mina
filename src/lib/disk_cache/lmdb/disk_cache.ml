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
    ; logger : Logger.t
    ; garbage : int Hash_set.t
          (** A list of ids that are no longer reachable from OCaml's side *)
    }

  (** How big can the above hashset be before we do a cleanup *)
  let garbage_size_limit = 512

  let initialize path ~logger =
    Async.Deferred.Result.map (Disk_cache_utils.initialize_dir path ~logger)
      ~f:(fun path ->
        let env, db = Rw.create path in
        { env
        ; db
        ; counter = ref 0
        ; logger
        ; garbage = Hash_set.create (module Int)
        } )

  type id = { idx : int }

  let get ({ env; db; logger; _ } : t) ({ idx } : id) : Data.t =
    [%log debug] "Getting data at %d in LMDB cache" idx
      ~metadata:[ ("index", `Int idx) ] ;
    Rw.get ~env db idx |> Option.value_exn

  let put ({ env; db; counter; logger; garbage } : t) (x : Data.t) : id =
    (* TODO: we may reuse IDs by pulling them from the `garbage` hash set *)
    let idx = !counter in
    incr counter ;
    let res = { idx } in
    (* When this reference is GC'd, delete the file. *)
    Gc.Expert.add_finalizer_last_exn res (fun () ->
        [%log debug] "Data at %d is GCed, marking as garbage" idx
          ~metadata:[ ("index", `Int idx) ] ;
        Hash_set.add garbage idx ) ;
    if Hash_set.length garbage >= garbage_size_limit then (
      Hash_set.iter garbage ~f:(fun to_remove ->
          [%log debug] "Instructing LMDB to remove garbage at index %d"
            to_remove
            ~metadata:[ ("index", `Int to_remove) ] ;
          Rw.remove ~env db to_remove ) ;
      Hash_set.clear garbage ) ;
    Rw.set ~env db idx x ;
    res

  let iteri ({ env; db; logger; _ } : t) ~f =
    Rw.iter ~env db ~f:(fun k v ->
        [%log debug] "Iterating at index %d" k ~metadata:[ ("index", `Int k) ] ;
        f k v )

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
