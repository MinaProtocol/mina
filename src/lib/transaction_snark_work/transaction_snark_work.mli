open Core_kernel
open Currency
open Signature_lib

module Statement : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t = Transaction_snark.Statement.Stable.V2.t One_or_two.Stable.V1.t
      [@@deriving compare, sexp, yojson, equal]

      include Comparable.S with type t := t

      include Hashable.S_binable with type t := t
    end
  end]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val gen : t Quickcheck.Generator.t

  val compact_json : t -> Yojson.Safe.t

  val work_ids : t -> int One_or_two.t
end

module Info : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        { statements : Statement.Stable.V2.t
        ; work_ids : int One_or_two.Stable.V1.t
        ; fee : Fee.Stable.V1.t
        ; prover : Public_key.Compressed.Stable.V1.t
        }
      [@@deriving compare, sexp, to_yojson]
    end
  end]
end

(* TODO: The SOK message actually should bind the SNARK to
       be in this particular bundle. The easiest way would be to
       SOK with
       H(all_statements_in_bundle || fee || public_key)
*)

[%%versioned:
module Stable : sig
  module V2 : sig
    type t = Mina_wire_types.Transaction_snark_work.V2.t =
      { fee : Fee.Stable.V1.t
      ; proofs : Ledger_proof.Stable.V2.t One_or_two.Stable.V1.t
      ; prover : Public_key.Compressed.Stable.V1.t
      }
    [@@deriving sexp, compare, equal, yojson]
  end
end]

val fee : t -> Fee.t

val info : t -> Info.t

val statement : t -> Statement.t

type unchecked = t

module Checked : sig
  type nonrec t = t =
    { fee : Fee.t
    ; proofs : Ledger_proof.t One_or_two.t
    ; prover : Public_key.Compressed.t
    }
  [@@deriving sexp, compare, to_yojson]

  module Stable : module type of Stable

  val create_unsafe : unchecked -> t

  val statement : t -> Statement.t
end

val forget : Checked.t -> t
