[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type ('spec, 'job_id) t =
      { spec : 'spec
      ; job_id : 'job_id
      ; sok_message : Mina_base.Sok_message.Stable.V1.t
      }
    [@@deriving sexp, yojson]
  end
end]

type ('spec, 'job_id) t = ('spec, 'job_id) Stable.Latest.t =
  { spec : 'spec; job_id : 'job_id; sok_message : Mina_base.Sok_message.t }
[@@deriving sexp, yojson]

val map : f_spec:('s1 -> 's2) -> ('s1, 'id) t -> ('s2, 'id) t
