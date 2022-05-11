[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t [@@deriving sexp, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, yojson]

val of_body : private_key:Signature_lib.Private_key.t -> Body.t -> t

val verify : public_key:Signature_lib.Public_key.t -> t -> bool

val reference : t -> Blake2.t

val compute_reference : Body.t -> Blake2.t
