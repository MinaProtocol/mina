module Bigstring : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Bigstring.Stable.V1.t [@@deriving sexp, compare]

      include Binable.S with type t := t

      val hash_fold_t : Hash.state -> t -> Hash.state

      val hash : t -> Hash.hash_value
    end
  end]

  include Hashable.S with type t := t
end

module T : Location_intf.S
