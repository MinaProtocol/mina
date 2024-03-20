open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      { public_key : Public_key.Stable.V1.t
      ; private_key : (Private_key.Stable.V1.t[@sexp.opaque])
      }
    [@@deriving sexp, to_yojson]
  end
end]

include Comparable.S with type t := t

val of_private_key_exn : Private_key.t -> t

val create : unit -> t

val gen : t Quickcheck.Generator.t

module And_compressed_pk : sig
  type nonrec t = t * Public_key.Compressed.t [@@deriving sexp]

  include Comparable.S with type t := t
end
