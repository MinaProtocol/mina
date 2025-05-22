open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'ledger_proof, 'sub_zkapp_spec, 'data) t =
        | Single of
            { job :
                ( ('witness, 'ledger_proof) Single_spec.Poly.Stable.V2.t
                , Id.Single.Stable.V1.t )
                With_job_meta.Stable.V1.t
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

  let map ~f_witness ~f_subzkapp_spec ~f_proof ~f_data = function
    | Single { job; data } ->
        Single
          { job =
              With_job_meta.map
                ~f_spec:(
                  Single_spec.Poly.map ~f_witness ~f_proof )
                job
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
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Transaction_witness.Stable.V2.t
      , Ledger_proof.Stable.V2.t
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

    let map_with_statement (t : t) ~f : _ Poly.t =
      match t with
      | Single { job = { spec; _ } as job; data } ->
          let stmt = Single_spec.Poly.statement spec in
          Single { job; data = f stmt data }
      | Sub_zkapp_command { job = { spec; _ } as job; data } ->
          Sub_zkapp_command
            { job; data = f (Sub_zkapp_spec.Stable.Latest.statement spec) data }
  end
end]

type t =
  (Transaction_witness.t, Ledger_proof.Cached.t, Sub_zkapp_spec.t, unit) Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t = function
  | Single { job; data } ->
      let job =
        With_job_meta.map ~f_spec:Single_spec.read_all_proofs_from_disk job
      in
      Single { job; data }
  | Sub_zkapp_command { job; data } ->
      let job =
        With_job_meta.map ~f_spec:Sub_zkapp_spec.read_all_proofs_from_disk job
      in
      Sub_zkapp_command { job; data }

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t = function
  | Single { job; data } ->
      let job =
        With_job_meta.map
          ~f_spec:(Single_spec.write_all_proofs_to_disk ~proof_cache_db)
          job
      in
      Single { job; data }
  | Sub_zkapp_command { job; data } ->
      let job =
        With_job_meta.map
          ~f_spec:(Sub_zkapp_spec.write_all_proofs_to_disk ~proof_cache_db)
          job
      in
      Sub_zkapp_command { job; data }
