open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
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

  let map ~f_single_spec ~f_subzkapp_spec = function
    | Single job ->
        Single (With_job_meta.map ~f_spec:f_single_spec job)
    | Sub_zkapp_command job ->
        Sub_zkapp_command (With_job_meta.map ~f_spec:f_subzkapp_spec job)

  let sok_message : _ t -> Mina_base.Sok_message.t = function
    | Single job ->
        job.sok_message
    | Sub_zkapp_command job ->
        job.sok_message

  let get_id : _ t -> Id.Any.t = function
    | Single { job_id; _ } ->
        Single job_id
    | Sub_zkapp_command { job_id; _ } ->
        Sub_zkapp job_id
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      (Single_spec.Stable.V2.t, Sub_zkapp_spec.Stable.V2.t) Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id

    let statement : t -> Transaction_snark.Statement.t = function
      | Single { spec; _ } ->
          Single_spec.Poly.statement spec
      | Sub_zkapp_command { spec; _ } ->
          Sub_zkapp_spec.Stable.Latest.statement spec

    let sok_message : t -> Mina_base.Sok_message.t = function
      | Single { sok_message; _ } | Sub_zkapp_command { sok_message; _ } ->
          sok_message
  end
end]

type t = (Single_spec.t, Sub_zkapp_spec.t) Poly.t
