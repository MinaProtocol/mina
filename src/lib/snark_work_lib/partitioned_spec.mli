open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('single_spec, 'sub_zkapp_spec) t =
        | Single of
            ('single_spec, Id.Single.Stable.V1.t) With_job_meta.Stable.V1.t
        | Sub_zkapp_command of
            ( 'sub_zkapp_spec
            , Id.Sub_zkapp.Stable.V1.t )
            With_job_meta.Stable.V1.t
      [@@deriving sexp, yojson]
    end
  end]

  val map :
       f_single_spec:('a -> 'b)
    -> f_subzkapp_spec:('c -> 'd)
    -> ('a, 'c) t
    -> ('b, 'd) t

  val sok_message : _ t -> Mina_base.Sok_message.t

  val get_id : _ t -> Id.Any.t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t =
      (Single_spec.Stable.V2.t, Sub_zkapp_spec.Stable.V2.t) Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t

    val statement : t -> Transaction_snark.Statement.t

    val sok_message : t -> Mina_base.Sok_message.t
  end
end]

type t = (Single_spec.t, Sub_zkapp_spec.t) Poly.t
