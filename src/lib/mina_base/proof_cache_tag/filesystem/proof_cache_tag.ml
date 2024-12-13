(* Cache proofs using the filesystem, one file per proof. *)

open Core

type value = Pickles.Proof.Proofs_verified_2.t

let counter = ref 0

module Cache = struct

  let unique_sub_path i t = t ^ Filename.dir_sep ^ Int.to_string i

  let initialize path = path

  type t = string

end

type t = { idx : int } [@@deriving compare, equal, sexp, yojson, hash]

let unwrap ({ idx = x } : t) (db : Cache.t) =
  (* Read from the file. *)
  In_channel.with_file ~binary:true (Cache.unique_sub_path x db) ~f:(fun chan ->
      let str = In_channel.input_all chan in
      Binable.of_string
        (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
        str )

let generate (x : value) (db : Cache.t)  =
  let new_counter = !counter in
  incr counter ;
  let res = { idx = new_counter } in
  (* When this reference is GC'd, delete the file. *)
  Gc.Expert.add_finalizer_last_exn res (fun () ->
      Core.Unix.unlink (Cache.unique_sub_path new_counter db) ) ;
  (* Write the proof to the file. *)
  Out_channel.with_file ~binary:true (Cache.unique_sub_path new_counter db) ~f:(fun chan ->
      Out_channel.output_string chan
      @@ Binable.to_string
           (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
           x ) ;
  res

module For_tests = struct 
  
  let random = Cache.initialize @@ Filename.temp_dir "mina" "proof_cache"
  
end