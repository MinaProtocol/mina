module Bigstring : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Core_kernel.Bigstring.Stable.V1.t [@@deriving sexp, compare]

      include Core_kernel.Binable.S with type t := t

      val hash_fold_t : Core_kernel.Hash.state -> t -> Core_kernel.Hash.state

      val hash : t -> Core_kernel.Hash.hash_value
    end
  end]

  include Core_kernel.Hashable.S with type t := t
end

module T : Location_intf.S
