(* Cache proofs using the lmdb *)

open Core
open Lmdb_storage.Generic

type value = Pickles.Proof.Proofs_verified_2.Stable.Latest.t


module F (Db : Db) = struct
  type holder = (int, value) Db.t

  let mk_maps { Db.create } =
    create Lmdb_storage.Conv.uint32_be
      (Lmdb_storage.Conv.bin_prot_conv
         Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_t )

  let config = { default_config with initial_mmap_size = 256 lsl 20 }
end

module Rw = Read_write (F)

type t = { idx : int } [@@deriving compare, equal, sexp, yojson, hash]

let counter = ref 0

module Cache = struct


  let initialize path = Rw.create path

  type t = Rw.t * Rw.holder

end

let unwrap ({ idx = x } : t) (db: Cache.t) : value =
  (* Read from the db. *)
  let env, db = db in 
  Rw.get ~env db x |> Option.value_exn

let generate (x : value) (db: Cache.t) : t =
  let env, db = db in 
  let idx= !counter in
  incr counter ;
  let res = { idx } in
  Gc.Expert.add_finalizer_last_exn res (fun () ->
    Rw.remove ~env db idx
  ) ;
  Rw.set ~env db idx x ; res


module For_tests = struct 
  
  let random () = Cache.initialize @@ Filename.temp_dir "mina" "proof_cache"

end