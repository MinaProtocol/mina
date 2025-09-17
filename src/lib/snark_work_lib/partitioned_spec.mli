open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('single_spec, 'sub_zkapp_spec, 'data) t =
        | Single of
            { job :
                ('single_spec, Id.Single.Stable.V1.t) With_job_meta.Stable.V1.t
            ; data : 'data
            }
        | Sub_zkapp_command of
            { job :
                ( 'sub_zkapp_spec
                , Id.Sub_zkapp.Stable.V1.t )
                With_job_meta.Stable.V1.t
            ; data : 'data
            }
      [@@deriving sexp, yojson]
    end
  end]

  val drop_data : ('a, 'b, 'c) t -> ('a, 'b, unit) t

  val map :
       f_single_spec:('a -> 'b)
    -> f_subzkapp_spec:('c -> 'd)
    -> f_data:('e -> 'f)
    -> ('a, 'c, 'e) t
    -> ('b, 'd, 'f) t

  val sok_message : _ t -> Mina_base.Sok_message.t

  val id_to_json : _ t -> Yojson.Safe.t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      ( Single_spec.Stable.V1.t
      , Sub_zkapp_spec.Stable.V1.t
      , unit )
      Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    val to_latest : t -> t

    val statement : t -> Transaction_snark.Statement.t

    val sok_message : t -> Mina_base.Sok_message.t
  end
end]

type t = (Single_spec.t, Sub_zkapp_spec.t, unit) Poly.t