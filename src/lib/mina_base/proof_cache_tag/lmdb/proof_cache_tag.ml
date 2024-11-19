(* Cache proofs using the lmdb *)

open Core
open Lmdb_storage.Generic

type value = Pickles.Proof.Proofs_verified_2.Stable.Latest.t

module F (Db : Db) = struct
  type holder = (int, value) Db.t

  let mk_maps { Db.create } =
    create Lmdb_storage.Conv.uint32_be 
    (Lmdb_storage.Conv.bin_prot_conv Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_t)

  let config = { default_config with initial_mmap_size = 256 lsl 20 }
end


module Rw = Read_write (F)

let db_dir = "/tmp"  ^ "cache.db"

type t = { idx : int } [@@deriving compare, equal, sexp, yojson, hash]

let unwrap ({ idx = x } : t) : value =
  (* Read from the db. *)
  let env, db = Rw.create db_dir in
  Rw.get ~env db x |> Option.value_exn

let generate (x : value) : t =
  let env, db = Rw.create db_dir in
  let hash = Pickles.Proof.Proofs_verified_2.Stable.Latest.hash x in
  let res = { idx = hash } in
  Rw.set ~env db hash x;
  res
