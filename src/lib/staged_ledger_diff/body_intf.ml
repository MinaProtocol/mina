module type Full = sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t [@@deriving equal, compare, sexp, to_yojson, bin_io]
    end
  end]

  type t = Stable.Latest.t [@@deriving equal, compare, sexp, to_yojson]

  val create : Diff.t -> t

  val staged_ledger_diff : t -> Diff.t

  val to_binio_bigstring : t -> Core_kernel.Bigstring.t

  val to_raw_string : t -> string

  val compute_reference : tag:int -> t -> Consensus.Body_reference.t
end
