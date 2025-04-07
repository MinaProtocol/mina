module type Full = sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t [@@deriving equal, sexp]
    end
  end]

  type t = Stable.Latest.t

  val create : Diff.t -> t

  val staged_ledger_diff : t -> Diff.t

  val to_binio_bigstring : t -> Core_kernel.Bigstring.t

  val compute_reference : tag:int -> t -> Consensus.Body_reference.t
end
