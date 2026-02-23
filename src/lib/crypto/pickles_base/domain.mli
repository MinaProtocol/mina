(** Wrapping integers for computing NTT domain *)

module Stable : sig
  module V1 : sig
    type t = Pow_2_roots_of_unity of int
    [@@unboxed] [@@deriving sexp, equal, compare, hash, yojson]

    include Plonkish_prelude.Sigs.Binable.S with type t := t

    include Plonkish_prelude.Sigs.VERSIONED
  end

  module Latest = V1
end

type t = Stable.Latest.t = Pow_2_roots_of_unity of int
[@@unboxed] [@@deriving sexp, equal, compare, hash, yojson]

include Core_kernel.Hashable.S with type t := t

(** {2 Size computation} *)

val log2_size : t -> int

val size : t -> int
