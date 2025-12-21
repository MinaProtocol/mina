open Core_kernel
open Currency
open Signature_lib

module Statement : sig
  type t = Transaction_snark.Statement.t One_or_two.t
  [@@deriving compare, sexp, yojson, equal]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  module Stable : sig
    module V2 : sig
      type t [@@deriving bin_io, compare, sexp, version, yojson, equal]

      include Comparable.S with type t := t

      include Hashable.S_binable with type t := t
    end
  end
  with type V2.t = t

  val gen : t Quickcheck.Generator.t

  val compact_json : t -> Yojson.Safe.t

  val work_ids : t -> int One_or_two.t
end

module Info : sig
  type t =
    { statements : Statement.Stable.V2.t
    ; work_ids : int One_or_two.Stable.V1.t
    ; fee : Fee.Stable.V1.t
    ; prover : Public_key.Compressed.Stable.V1.t
    }
  [@@deriving to_yojson, sexp, compare]

  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, to_yojson, version, sexp, bin_io]
    end
  end
  with type V2.t = t
end

(* TODO: The SOK message actually should bind the SNARK to
       be in this particular bundle. The easiest way would be to
       SOK with
       H(all_statements_in_bundle || fee || public_key)
*)

module type S = sig
  type t

  val fee : t -> Fee.t

  val prover : t -> Public_key.Compressed.t
end

type t =
  { fee : Currency.Fee.t
  ; proofs : Ledger_proof.Cached.t One_or_two.t
  ; prover : Public_key.Compressed.t
  }

include S with type t := t

val info : t -> Info.t

val statement : t -> Statement.t

val proofs : t -> Ledger_proof.Cached.t One_or_two.t

module Stable : sig
  module V2 : sig
    type t [@@deriving bin_io, equal, sexp, version, yojson]

    val statement : t -> Statement.Stable.V2.t

    val fee : t -> Fee.Stable.V1.t

    val prover : t -> Public_key.Compressed.Stable.V1.t

    val proofs : t -> Ledger_proof.t One_or_two.t

    val to_latest : t -> t
  end

  module Latest = V2
end
with type V2.t = Mina_wire_types.Transaction_snark_work.V2.t

module Serializable_type : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t

      val statement : t -> Statement.Stable.V2.t

      val fee : t -> Fee.Stable.V1.t

      val prover : t -> Public_key.Compressed.Stable.V1.t

      val proofs : t -> Ledger_proof.Serializable_type.t One_or_two.t
    end
  end]
end

type unchecked = t

module Checked : sig
  include S

  val create_unsafe : unchecked -> t

  val statement : t -> Statement.t

  val proofs : t -> Ledger_proof.Cached.t One_or_two.t
end

val forget : Checked.t -> t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val to_serializable_type : t -> Serializable_type.t
