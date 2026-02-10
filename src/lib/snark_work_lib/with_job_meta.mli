(** Attaches metadata to a job specification.

    Includes the job ID for tracking and the sok_message (statement of
    knowledge) for prover attribution and fee payment.
*)

[%%versioned:
module Stable : sig
  module V1 : sig
    type ('spec, 'job_id) t =
      { spec : 'spec
      ; job_id : 'job_id
      ; sok_message : Mina_base.Sok_message.Stable.V1.t
      }
    [@@deriving sexp, yojson]
  end
end]

(** Transform the spec while preserving metadata. *)
val map : f_spec:('s1 -> 's2) -> ('s1, 'id) t -> ('s2, 'id) t
