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

  val compose : Block.t -> Raw.t

  val decompose : Raw.t -> Block.t

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

    val lift : Validated_block.t -> t

    val lower : t -> Validated_block.t
  end
