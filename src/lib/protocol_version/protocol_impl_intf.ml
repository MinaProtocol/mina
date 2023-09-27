module type Full = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving compare, equal, sexp, yojson]
    end
  end]

  val api : t -> int

  val patch : t -> int

  val tag : t -> string option

  val current : t

  val to_string : t -> string

  (** useful when deserializing, could contain negative integers *)
  val is_valid : t -> bool
end
