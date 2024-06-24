(* Domain specification *)

module Stable : sig
  module V1 : sig
    type t = Pow_2_roots_of_unity of int
    [@@unboxed] [@@deriving sexp, equal, compare, hash, yojson]

    include Pickles_types.Sigs.Binable.S with type t := t

    include Pickles_types.Sigs.VERSIONED
  end

  module Latest = V1
end

type t = Stable.Latest.t = Pow_2_roots_of_unity of int
[@@unboxed] [@@deriving sexp, equal, compare, hash, yojson]

include Core_kernel.Hashable.S with type t := t

(** {2 Size computation} *)

val log2_size : t -> int

val size : t -> int
