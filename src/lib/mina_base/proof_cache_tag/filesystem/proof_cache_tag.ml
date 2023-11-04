(* Cache proofs using the filesystem, one file per proof. *)

open Core

type value = Pickles.Proof.Proofs_verified_2.t

let counter = ref 0

let prefix = Filename.temp_dir "mina" "proof_cache"

let path i = prefix ^ Filename.dir_sep ^ Int.to_string i

type t = { idx : int } [@@deriving compare, equal, sexp, yojson, hash]

let unwrap ({ idx = x } : t) : value =
  (* Read from the file. *)
  In_channel.with_file ~binary:true (path x) ~f:(fun chan ->
      let str = In_channel.input_all chan in
      Binable.of_string
        (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
        str )

let generate (x : value) : t =
  let new_counter = !counter in
  incr counter ;
  let res = { idx = new_counter } in
  (* When this reference is GC'd, delete the file. *)
  Gc.Expert.add_finalizer_last_exn res (fun () ->
      Core.Unix.unlink (path new_counter) ) ;
  (* Write the proof to the file. *)
  Out_channel.with_file ~binary:true (path new_counter) ~f:(fun chan ->
      Out_channel.output_string chan
      @@ Binable.to_string
           (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
           x ) ;
  res
