open Core_kernel

module Good : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t = int
    end

    module V1 : sig
      type t = string

      val to_latest : t -> V2.t
    end
  end]

  (* make sure t is an int *)
  val is_42 : t -> bool
end
