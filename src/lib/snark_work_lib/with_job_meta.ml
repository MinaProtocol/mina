[%%versioned
module Stable = struct
  module V1 = struct
    type ('spec, 'job_id) t =
      { spec : 'spec
      ; job_id : 'job_id
      ; scheduled_since_unix_epoch : Mina_stdlib.Time.Span.Stable.V1.t
      ; sok_message : Mina_base.Sok_message.Stable.V1.t
      }
    [@@deriving sexp, yojson]
  end
end]

let map ~(f_spec : 's1 -> 's2) (t : ('s1, 'id) t) : ('s2, 'id) t =
  { t with spec = f_spec t.spec }
