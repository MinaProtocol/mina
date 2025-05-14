open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'zkapp_command_segment_witness, 'ledger_proof, 'data) t =
        | Single of
            { single_spec :
                ('witness, 'ledger_proof) Single_spec.Poly.Stable.V2.t
            ; pairing : Pairing.Single.Stable.V1.t
            ; data : 'data
            }
        | Sub_zkapp_command of
            { spec :
                ( 'zkapp_command_segment_witness
                , 'ledger_proof )
                Zkapp_command_job.Spec.Poly.Stable.V1.t
                Zkapp_command_job.Poly.Stable.V1.t
            ; data : 'data
            }
      [@@deriving sexp, yojson]

      let map ~f_witness ~f_zkapp_command_segment_witness ~f_proof ~f_data =
        function
        | Single { single_spec; pairing; data } ->
            Single
              { single_spec =
                  Single_spec.Poly.map ~f_witness ~f_proof single_spec
              ; pairing
              ; data = f_data data
              }
        | Sub_zkapp_command { spec; data } ->
            Sub_zkapp_command
              { spec =
                  Zkapp_command_job.Poly.map
                    ~f_spec:
                      (Zkapp_command_job.Spec.Poly.map
                         ~f_witness:f_zkapp_command_segment_witness ~f_proof )
                    spec
              ; data = f_data data
              }

      let statements : _ t -> Transaction_snark.Statement.t One_or_two.t =
        function
        | Single { single_spec; _ } ->
            let stmt = Single_spec.Poly.statement single_spec in
            `One stmt
        | Sub_zkapp_command { spec = { spec; _ }; _ } ->
            `One (Zkapp_command_job.Spec.Poly.statement spec)

      let map_with_statement (t : _ t) ~f : _ t =
        match t with
        | Single { single_spec; pairing; data } ->
            let stmt = Single_spec.Poly.statement single_spec in
            Single { single_spec; pairing; data = f stmt data }
        | Sub_zkapp_command { spec = { spec; _ } as job_spec; data } ->
            Sub_zkapp_command
              { spec = job_spec
              ; data = f (Zkapp_command_job.Spec.Poly.statement spec) data
              }

      let transaction = function
        | Single { single_spec; _ } ->
            let txn = Single_spec.Poly.transaction single_spec in
            `Single txn
        | Sub_zkapp_command _ ->
            `Sub_zkapp_command
    end
  end]

  [%%define_locally
  Stable.Latest.(map, statements, map_with_statement, transaction)]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Transaction_witness.Stable.V2.t
      , Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
      , Ledger_proof.Stable.V2.t
      , unit )
      Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t =
  ( Transaction_witness.t
  , Transaction_snark.Zkapp_command_segment.Witness.t
  , Ledger_proof.Cached.t
  , unit )
  Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t = function
  | Single { single_spec; pairing; data } ->
      let single_spec = Single_spec.read_all_proofs_from_disk single_spec in
      Single { single_spec; pairing; data }
  | Sub_zkapp_command { spec; data } ->
      let spec = Zkapp_command_job.read_all_proofs_from_disk spec in
      Sub_zkapp_command { spec; data }

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t = function
  | Single { single_spec; pairing; data } ->
      let single_spec =
        Single_spec.write_all_proofs_to_disk ~proof_cache_db single_spec
      in
      Single { single_spec; pairing; data }
  | Sub_zkapp_command { spec; data } ->
      let spec =
        Zkapp_command_job.write_all_proofs_to_disk ~proof_cache_db spec
      in
      Sub_zkapp_command { spec; data }
