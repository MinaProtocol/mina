open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
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

  let drop_data : _ t -> _ t = function
    | Single { job; _ } ->
        Single { job; data = () }
    | Sub_zkapp_command { job; _ } ->
        Sub_zkapp_command { job; data = () }

  let map ~f_single_spec ~f_subzkapp_spec ~f_data = function
    | Single { job; data } ->
        Single
          { job = With_job_meta.map ~f_spec:f_single_spec job
          ; data = f_data data
          }
    | Sub_zkapp_command { job; data } ->
        Sub_zkapp_command
          { job = With_job_meta.map ~f_spec:f_subzkapp_spec job
          ; data = f_data data
          }

  let sok_message : _ t -> Mina_base.Sok_message.t = function
    | Single { job; _ } ->
        job.sok_message
    | Sub_zkapp_command { job; _ } ->
        job.sok_message

  let id_to_json : _ t -> Yojson.Safe.t = function
    | Single { job = { job_id; _ }; _ } ->
        `List [ `String "single"; Id.Single.to_yojson job_id ]
    | Sub_zkapp_command { job = { job_id; _ }; _ } ->
        `List [ `String "sub_zkapp"; Id.Sub_zkapp.to_yojson job_id ]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Single_spec.Stable.V1.t
      , Sub_zkapp_spec.Stable.V1.t
      , unit )
      Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id

    let statement : t -> Transaction_snark.Statement.t = function
      | Single { job = { spec; _ }; _ } ->
          Single_spec.Poly.statement spec
      | Sub_zkapp_command { job = { spec; _ }; _ } ->
          Sub_zkapp_spec.Stable.Latest.statement spec

    let sok_message : t -> Mina_base.Sok_message.t = function
      | Single { job = { sok_message; _ }; _ } ->
          sok_message
      | Sub_zkapp_command { job = { sok_message; _ }; _ } ->
          sok_message
  end
end]

type t = (Single_spec.t, Sub_zkapp_spec.t, unit) Poly.t