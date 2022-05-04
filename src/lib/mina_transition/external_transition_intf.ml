open Core_kernel

module type External_transition_base_intf = sig
  module Raw : sig
    type t [@@deriving sexp]

    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type nonrec t = t [@@deriving sexp]
      end
    end]
  end
end

module type S = sig
  include External_transition_base_intf

  val compose : Mina_block.t -> Raw.t

  val decompose : Raw.t -> Mina_block.t

  module Validated : sig
    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V2 : sig
        type t [@@deriving sexp, to_yojson]
      end

      module V1 : sig
        type t [@@deriving sexp, to_yojson]

        val to_latest : t -> V2.t

        val of_v2 : V2.t -> t
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]

    val lift : Mina_block.Validated.t -> t

    val lower : t -> Mina_block.Validated.t
  end
end
