[%%versioned:
module Stable : sig
  module V1 : sig
    type ('spec, 'job_id) t =
      { spec : 'spec
      ; job_id : 'job_id
      ; issued_since_unix_epoch : Mina_stdlib.Time.Span.Stable.V1.t
      ; sok_message : Mina_base.Sok_message.Stable.V1.t
      }
    [@@deriving sexp, yojson]
  end
end]

val map : f_spec:('s1 -> 's2) -> ('s1, 'id) t -> ('s2, 'id) t
