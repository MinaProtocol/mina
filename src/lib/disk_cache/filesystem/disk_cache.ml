(* Cache proofs using the filesystem, one file per proof. *)

open Core

module Make (B : sig
  include Binable.S
end) =
struct
  type t = string * int ref

  type id = { idx : int }

  let initialize path ~logger =
    Async.Deferred.Result.map (Utils.initialize_dir path ~logger)
      ~f:(fun path -> (path, ref 0))

  let path root i = root ^ Filename.dir_sep ^ Int.to_string i

  let get ((root, _) : t) (id : id) : B.t =
    (* Read from the file. *)
    In_channel.with_file ~binary:true (path root id.idx) ~f:(fun chan ->
        let str = In_channel.input_all chan in
        Binable.of_string (module B) str )

  let put ((root, next_idx) : t) x : id =
    let idx = !next_idx in
    incr next_idx ;
    let res = { idx } in
    (* When this reference is GC'd, delete the file. *)
    Core.Gc.Expert.add_finalizer_last_exn res (fun () ->
        (* Ignore errors: if a directory is deleted, it's ok. *)
        try Core.Unix.unlink (path root idx) with _ -> () ) ;
    (* Write the proof to the file. *)
    Out_channel.with_file ~binary:true (path root idx) ~f:(fun chan ->
        Out_channel.output_string chan @@ Binable.to_string (module B) x ) ;
    res

  let count ((path, _) : t) = Sys.ls_dir path |> List.length
end

let%test_module "disk_cache filesystem" =
  ( module struct
    include Disk_cache_test_lib.Make (Make)

    let%test_unit "remove data on gc" = remove_data_on_gc ()

    let%test_unit "simple read/write" = simple_write ()

    let%test_unit "initialization special cases" =
      initialization_special_cases ()
  end )
