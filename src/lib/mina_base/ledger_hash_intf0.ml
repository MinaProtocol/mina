open Core_kernel
open Snark_params.Tick

module type S = sig
  include Data_hash.Full_size

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Field.t [@@deriving sexp, compare, hash, yojson]

      val to_latest : t -> t

      include Comparable.S with type t := t

      include Hashable_binable with type t := t
    end
  end]
end
