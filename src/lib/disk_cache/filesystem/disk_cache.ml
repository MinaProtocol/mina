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

  let get ((root, _counter) : t) (id : id) : B.t =
    (* Read from the file. *)
    In_channel.with_file ~binary:true (path root id.idx) ~f:(fun chan ->
        let str = In_channel.input_all chan in
        Binable.of_string (module B) str )

  let put ((root, counter) : t) x : id =
    let new_counter = !counter in
    incr counter ;
    let res = { idx = new_counter } in
    (* When this reference is GC'd, delete the file. *)
    Core.Gc.Expert.add_finalizer_last_exn res (fun () ->
        Core.Unix.unlink (path root new_counter) ) ;
    (* Write the proof to the file. *)
    Out_channel.with_file ~binary:true (path root new_counter) ~f:(fun chan ->
        Out_channel.output_string chan @@ Binable.to_string (module B) x ) ;
    res

  let count ((_, counter) : t) = !counter
end
