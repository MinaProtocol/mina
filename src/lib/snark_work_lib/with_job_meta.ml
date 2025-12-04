[%%versioned
module Stable = struct
  module V1 = struct
    type ('spec, 'job_id) t =
      { spec : 'spec
      ; job_id : 'job_id
      ; sok_message : Mina_base.Sok_message.Stable.V1.t
            (* ; work_spec_hash:   *)
      }
    [@@deriving sexp, yojson]
  end
end]

let map ~(f_spec : 's1 -> 's2) (t : ('s1, 'id) t) : ('s2, 'id) t =
  { t with spec = f_spec t.spec }
