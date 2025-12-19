open Async_kernel
open Core_kernel

module Proof_with_size = struct
  module Stable = struct
    module V2 = struct
      type t =
        { proof : Pickles.Proof.Proofs_verified_2.Stable.Latest.t
        ; bin_io_size : int
        }

      let bin_size_t : t Bin_prot.Size.sizer =
       fun { proof = _; bin_io_size } -> bin_io_size

      let bin_write_t : t Bin_prot.Write.writer =
       fun buf ~pos { proof; bin_io_size = _ } ->
        Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_write_t buf ~pos proof

      let bin_read_t : t Bin_prot.Read.reader =
       fun buf ~pos_ref ->
        let before = !pos_ref in
        let proof =
          Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_read_t buf ~pos_ref
        in
        let bin_io_size = !pos_ref - before in
        { proof; bin_io_size }

      let __bin_read_t__ : (int -> t) Bin_prot.Read.reader =
       fun buf ~pos_ref size ->
        let before = !pos_ref in
        let proof =
          Pickles.Proof.Proofs_verified_2.Stable.Latest.__bin_read_t__ buf
            ~pos_ref size
        in
        let bin_io_size = !pos_ref - before in
        { proof; bin_io_size }

      let bin_shape_t : Bin_shape_lib.Bin_shape.t =
        Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_shape_t

      let bin_writer_t : t Bin_prot.Type_class.writer0 =
        { size = bin_size_t; write = bin_write_t }

      let bin_reader_t : t Bin_prot.Type_class.reader0 =
        { read = bin_read_t; vtag_read = __bin_read_t__ }

      let bin_t : t Bin_prot.Type_class.t0 =
        { shape = bin_shape_t; writer = bin_writer_t; reader = bin_reader_t }
    end

    module Latest = V2
  end
end

module Cache = Disk_cache.Make (Proof_with_size.Stable.V2)

type cache_db = Lmdb_cache of Cache.t | Identity_cache

type t =
  | Lmdb of { cache_id : Cache.id; cache_db : Cache.t; bin_io_size : int }
  | Identity of Pickles.Proof.Proofs_verified_2.Stable.Latest.t

(* Sexp serialization is opaque for proof_cache_tag *)
let sexp_of_t _ = Sexp.of_string "proof_cache_tag"

(* JSON serialization is opaque for proof_cache_tag *)
let to_yojson _ = `String "proof_cache_tag"

let read_proof_from_disk = function
  | Lmdb t ->
      (Cache.get t.cache_db t.cache_id).proof
  | Identity proof ->
      proof

let write_proof_to_disk db proof =
  match db with
  | Lmdb_cache cache_db ->
      let bin_io_size =
        Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_size_t proof
      in
      Lmdb
        { cache_id = Cache.put cache_db { proof; bin_io_size }
        ; cache_db
        ; bin_io_size
        }
  | Identity_cache ->
      Identity proof

let create_db path ~logger =
  Cache.initialize ~logger path
  |> Deferred.Result.map ~f:(fun cache -> Lmdb_cache cache)

let create_identity_db () = Identity_cache

module Serializable_type = struct
  type nonrec t = t

  module Stable = struct
    module V2 = struct
      type nonrec t = t

      let bin_size_t : t Bin_prot.Size.sizer = function
        | Lmdb { cache_id = _; cache_db = _; bin_io_size } ->
            bin_io_size
        | Identity proof ->
            Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_size_t proof

      let bin_write_t : t Bin_prot.Write.writer =
       fun buf ~pos res ->
        Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_write_t buf ~pos
          (read_proof_from_disk res)

      let bin_read_t : t Bin_prot.Read.reader =
       fun buf ~pos_ref ->
        let proof =
          Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_read_t buf ~pos_ref
        in
        Identity proof

      let __bin_read_t__ : (int -> t) Bin_prot.Read.reader =
       fun buf ~pos_ref size ->
        let proof =
          Pickles.Proof.Proofs_verified_2.Stable.Latest.__bin_read_t__ buf
            ~pos_ref size
        in
        Identity proof

      let bin_shape_t : Bin_shape_lib.Bin_shape.t =
        Pickles.Proof.Proofs_verified_2.Stable.Latest.bin_shape_t

      let bin_writer_t : t Bin_prot.Type_class.writer0 =
        { size = bin_size_t; write = bin_write_t }

      let bin_reader_t : t Bin_prot.Type_class.reader0 =
        { read = bin_read_t; vtag_read = __bin_read_t__ }

      let bin_t : t Bin_prot.Type_class.t0 =
        { shape = bin_shape_t; writer = bin_writer_t; reader = bin_reader_t }

      let __versioned__ = ()
    end

    module Latest = V2
  end

  let of_cache_tag = Fn.id

  let to_proof = read_proof_from_disk
end

module For_tests = struct
  let create_db = create_identity_db
end
