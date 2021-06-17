open Core_kernel

module type Security_intf = sig
  (** In production we set this to (hopefully a prefix of) k for our consensus
   * mechanism; infinite is for tests *)
  val max_depth : [ `Infinity | `Finite of int ]
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t [@@deriving sexp, bin_io, yojson]
  end

  type t [@@deriving sexp, bin_io, yojson]
end
