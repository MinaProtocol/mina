(* Cache proofs using the filesystem, one file per proof. *)

(* TODO:
   figure out the reason why filesystem cache is much more disk hungry;
   It takes 4~5 times disk space than LMDB cache. *)

open Core

module Make (B : sig
  include Binable.S
end) =
struct
  type t = { root : string; next_idx : int ref; eviction_freezed : bool ref }

  type persistence = int [@@deriving bin_io_unversioned]

  type id = { idx : int }

  let initialize path ~logger ?persistence:(next_idx : persistence = 0) () =
    Async.Deferred.Result.map (Disk_cache_utils.initialize_dir path ~logger)
      ~f:(fun root ->
        { root; next_idx = ref next_idx; eviction_freezed = ref false } )

  let path root i = root ^ Filename.dir_sep ^ Int.to_string i

  let get ({ root; _ } : t) (id : id) : B.t =
    (* Read from the file. *)
    In_channel.with_file ~binary:true (path root id.idx) ~f:(fun chan ->
        let str = In_channel.input_all chan in
        Binable.of_string (module B) str )

  let freeze_eviction { eviction_freezed; next_idx; _ } =
    eviction_freezed := true ;
    !next_idx

  let put ({ root; next_idx; eviction_freezed } : t) x : id =
    let idx = !next_idx in
    incr next_idx ;
    let res = { idx } in
    (* When this reference is GC'd, delete the file. *)
    Core.Gc.Expert.add_finalizer_last_exn res (fun () ->
        if not !eviction_freezed then
          (* Ignore errors: if a directory is deleted, it's ok. *)
          try Core.Unix.unlink (path root idx) with _ -> () ) ;
    (* Write the proof to the file. *)
    Out_channel.with_file ~binary:true (path root idx) ~f:(fun chan ->
        Out_channel.output_string chan @@ Binable.to_string (module B) x ) ;
    res

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
