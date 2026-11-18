open Core_kernel
open Async_kernel

type t [@@deriving sexp_of, to_yojson]

type cache_db

val create_db :
     string
  -> logger:Logger.t
  -> (cache_db, [> `Initialization_error of Error.t ]) Deferred.Result.t

val read_proof_from_disk : t -> Pickles.Proof.Proofs_verified_2.Stable.Latest.t

(** The bin_prot serialization of the proof, read without decoding it *)
val read_proof_bin_prot_from_disk : t -> Bigstring.t

(** Writes the proof's bin_prot serialization, as
    [Pickles.Proof.Proofs_verified_2.Stable.Latest], by copying the stored bytes
    instead of decoding and re-encoding them. Each call to [size] or [write]
    reads the stored bytes. *)
val bin_writer_stored : t Bin_prot.Type_class.writer

val write_proof_to_disk :
  cache_db -> Pickles.Proof.Proofs_verified_2.Stable.Latest.t -> t

val create_identity_db : unit -> cache_db

module For_tests : sig
  val create_db : unit -> cache_db
end
