(* Cache proofs using the filesystem, one file per proof. *)

(* TODO:
   figure out the reason why filesystem cache is much more disk hungry;
   It takes 4~5 times disk space than LMDB cache. *)

open Core

module Make (B : sig
  include Binable.S
end) =
struct
  type t =
    { root : string
    ; next_idx : int ref
    ; eviction_freezed : bool ref
    ; disk_meta_location : string option
    }

  type persistence = int [@@deriving bin_io_unversioned]

  type id = { idx : int } [@@deriving bin_io_unversioned]

  let freeze_eviction_and_snapshot ~logger
      { eviction_freezed; next_idx; disk_meta_location; _ } =
    eviction_freezed := true ;
    match disk_meta_location with
    | None ->
        [%log info]
          "No metadata location is set for FS disk cache, not saving disk \
           cache persistence information" ;
        Async.Deferred.unit
    | Some disk_meta_location ->
        Async_unix.Writer.save_bin_prot disk_meta_location
          bin_writer_persistence !next_idx

  let initialize path ~logger ?disk_meta_location () =
    let open Async in
    let open Deferred.Let_syntax in
    let%bind next_idx =
      match disk_meta_location with
      | None ->
          return 0
      | Some disk_meta_location -> (
          match%map
            Async.Reader.load_bin_prot disk_meta_location bin_reader_persistence
          with
          | Error e ->
              [%log warn]
                "Failed to read FS disk cache persistence information from \
                 disk, initializing a fresh cache"
                ~metadata:
                  [ ("location", `String disk_meta_location)
                  ; ("reason", `String (Error.to_string_hum e))
                  ] ;
              0
          | Ok idx ->
              idx )
    in
    Async.Deferred.Result.map (Disk_cache_utils.initialize_dir path ~logger)
      ~f:(fun root ->
        let cache =
          { root
          ; next_idx = ref next_idx
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

  let path root i = root ^ Filename.dir_sep ^ Int.to_string i

  let get ({ root; _ } : t) (id : id) : B.t =
    (* Read from the file. *)
    In_channel.with_file ~binary:true (path root id.idx) ~f:(fun chan ->
        let str = In_channel.input_all chan in
        Binable.of_string (module B) str )

  let register_gc ~(id : id) ({ root; eviction_freezed; _ } : t) =
    let { idx } = id in
    (* When this reference is GC'd, delete the file. *)
    Core.Gc.Expert.add_finalizer_last_exn id (fun () ->
        if not !eviction_freezed then
          (* Ignore errors: if a directory is deleted, it's ok. *)
          try Core.Unix.unlink (path root idx) with _ -> () )

  let try_get_deserialized (t : t) (id : id) : B.t option =
    try
      let result = Some (get t id) in
      register_gc ~id t ; result
    with Sys_error _ -> None

  let put ({ root; next_idx; _ } as t : t) x : id =
    let idx = !next_idx in
    incr next_idx ;
    let id = { idx } in
    register_gc ~id t ;
    (* Write the proof to the file. *)
    Out_channel.with_file ~binary:true (path root idx) ~f:(fun chan ->
        Out_channel.output_string chan @@ Binable.to_string (module B) x ) ;
    id

  let count ({ root; _ } : t) = Sys.ls_dir root |> List.length
end

let%test_module "disk_cache filesystem" =
  ( module struct
    include Disk_cache_test_lib.Make (Make)

    let%test_unit "remove data on gc" = remove_data_on_gc ()

    let%test_unit "simple read/write" = simple_write ()

    let%test_unit "initialization special cases" =
      initialization_special_cases ()
  end )
