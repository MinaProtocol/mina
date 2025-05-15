open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'zkapp_command_segment_witness, 'ledger_proof, 'data) t =
        | Single of
            { job :
                ( ('witness, 'ledger_proof) Single_spec.Poly.Stable.V2.t
                , Id.Single.Stable.V1.t )
                With_status.Stable.V1.t
            ; data : 'data
            }
        | Sub_zkapp_command of
            { job :
                ( ( 'zkapp_command_segment_witness
                  , 'ledger_proof )
                  Sub_zkapp_spec.Poly.Stable.V1.t
                , Id.Sub_zkapp.Stable.V1.t )
                With_status.Stable.V1.t
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

  let map ~f_witness ~f_zkapp_command_segment_witness ~f_proof ~f_data =
    function
    | Single { job; data } ->
        Single
          { job =
              With_status.map
                ~f_spec:(fun spec ->
                  Single_spec.Poly.map ~f_witness ~f_proof spec )
                job
          ; data = f_data data
          }
    | Sub_zkapp_command { job; data } ->
        Sub_zkapp_command
          { job =
              With_status.map
                ~f_spec:
                  (Sub_zkapp_spec.Poly.map
                     ~f_witness:f_zkapp_command_segment_witness ~f_proof )
                job
          ; data = f_data data
          }

  let fee_of_full : _ t -> Currency.Fee.t = function
    | Single { job; _ } ->
        job.fee_of_full
    | Sub_zkapp_command { job; _ } ->
        job.fee_of_full

  let statements : _ t -> Transaction_snark.Statement.t One_or_two.t = function
    | Single { job = { spec; _ }; _ } ->
        let stmt = Single_spec.Poly.statement spec in
        `One stmt
    | Sub_zkapp_command { job = { spec; _ }; _ } ->
        `One (Sub_zkapp_spec.Poly.statement spec)

  let map_with_statement (t : _ t) ~f : _ t =
    match t with
    | Single { job = { spec; _ } as job; data } ->
        let stmt = Single_spec.Poly.statement spec in
        Single { job; data = f stmt data }
    | Sub_zkapp_command { job = { spec; _ } as job; data } ->
        Sub_zkapp_command
          { job; data = f (Sub_zkapp_spec.Poly.statement spec) data }

  let transaction = function
    | Single { job = { spec; _ }; _ } ->
        let txn = Single_spec.Poly.transaction spec in
        `Single txn
    | Sub_zkapp_command _ ->
        `Sub_zkapp_command
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
  | Single { job; data } ->
      let job =
        With_status.map ~f_spec:Single_spec.read_all_proofs_from_disk job
      in
      Single { job; data }
  | Sub_zkapp_command { job; data } ->
      let job =
        With_status.map ~f_spec:Sub_zkapp_spec.read_all_proofs_from_disk job
      in
      Sub_zkapp_command { job; data }

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t = function
  | Single { job; data } ->
      let job =
        With_status.map
          ~f_spec:(Single_spec.write_all_proofs_to_disk ~proof_cache_db)
          job
      in
      Single { job; data }
  | Sub_zkapp_command { job; data } ->
      let job =
        With_status.map
          ~f_spec:(Sub_zkapp_spec.write_all_proofs_to_disk ~proof_cache_db)
          job
      in
      Sub_zkapp_command { job; data }
