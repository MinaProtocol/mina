(** Multi-key file storage - stores multiple keys with heterogeneous types in a single file *)

module Tag : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('filename_key, 'a) t [@@deriving sexp]
    end
  end]
end

module type S = Intf.S

include S with type 'a tag = (string, 'a) Tag.t and type filename_key = string

module Make_custom (Inputs : sig
  type filename_key

  val filename : filename_key -> string
end) :
  S
    with type 'a tag = (Inputs.filename_key, 'a) Tag.t
     and type filename_key = Inputs.filename_key
