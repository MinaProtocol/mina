open Core_kernel
open Snark_params.Tick

module type S = sig
  include Data_hash.Full_size

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t = Field.t [@@deriving sexp, compare, yojson]

      val to_latest : t -> t

      include Comparable.S_binable with type t := t
    end
  end]
end
