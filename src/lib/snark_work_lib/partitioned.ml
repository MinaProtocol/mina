open Core_kernel

(* A `Pairing.t` identifies a single work in Work_selector's perspective *)
module Pairing = struct
  module UUID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* this identifies a One_or_two work from Work_selector's perspective *)
        type t = Pairing_UUID of int
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. This is needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { one_or_two : [ `First | `Second | `One ]
        ; pair_uuid : UUID.Stable.V1.t option
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_job = struct
  (* This identifies a single `Zkapp_command_job.t` *)
  module UUID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Job_UUID of int [@@deriving compare, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Spec = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          | Segment of
              { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
              ; witness :
                  Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
              ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
              }
          | Merge of
              { proof1 : Ledger_proof.Stable.V2.t
              ; proof2 : Ledger_proof.Stable.V2.t
              }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.t
          ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
          }
      | Merge of
          { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }

    let materialize : t -> Stable.Latest.t = function
      | Segment { statement; witness; spec } ->
          let witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .read_all_proofs_from_disk witness
          in

          Segment { statement; witness; spec }
      | Merge { proof1; proof2 } ->
          let proof1 = Ledger_proof.Cached.read_proof_from_disk proof1 in
          let proof2 = Ledger_proof.Cached.read_proof_from_disk proof2 in
          Merge { proof1; proof2 }

    let cache ~(proof_cache_db : Proof_cache_tag.cache_db) :
        Stable.Latest.t -> t = function
      | Segment { statement; witness; spec } ->
          let witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .write_all_proofs_to_disk witness
          in
          Segment { statement; witness; spec }
      | Merge { proof1; proof2 } ->
          let proof1 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof1
          in
          let proof2 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof2
          in
          Merge { proof1; proof2 }
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { spec : Spec.Stable.V1.t
        ; pairing_id : Pairing.Stable.V1.t
        ; job_uuid : UUID.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    { spec : Spec.t; pairing_id : Pairing.Stable.V1.t; job_uuid : UUID.t }

  let materialize ({ spec; pairing_id; job_uuid } : t) : Stable.Latest.t =
    { spec = Spec.materialize spec; pairing_id; job_uuid }

  let cache ~(proof_cache_db : Proof_cache_tag.cache_db)
      ({ spec; pairing_id; job_uuid } : Stable.Latest.t) : t =
    { spec = Spec.cache ~proof_cache_db spec; pairing_id; job_uuid }
end

module Selector_work = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        ( Transaction_witness.Stable.V2.t
        , Ledger_proof.Stable.V2.t )
        Work.Single.Spec.Stable.V2.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = (Transaction_witness.t, Ledger_proof.Cached.t) Work.Single.Spec.t

  let materialize : t -> Stable.Latest.t =
    Work.Single.Spec.map
      ~f_witness:Transaction_witness.read_all_proofs_from_disk
      ~f_proof:Ledger_proof.Cached.read_proof_from_disk

  let cache ~(proof_cache_db : Proof_cache_tag.cache_db) : Stable.Latest.t -> t
      =
    Work.Single.Spec.map ~f_witness:Transaction_witness.write_all_proofs_to_disk
      ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
end

(* this is the actual work passed over network between coordinator and worker *)
module Single = struct
  module Spec = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          | Regular of (Selector_work.Stable.V1.t * Pairing.Stable.V1.t)
          | Sub_zkapp_command of Zkapp_command_job.Stable.V1.t
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end

      module V1 = struct
        type t = Selector_work.Stable.V1.t [@@deriving sexp, yojson]

        let to_latest ~one_or_two (t : t) : V2.t =
          Regular (t, { Pairing.Stable.V1.pair_uuid = None; one_or_two })
      end
    end]

    type t =
      | Regular of (Selector_work.t * Pairing.t)
      | Sub_zkapp_command of Zkapp_command_job.t

    let materialize : t -> Stable.Latest.t = function
      | Regular (work, pairing) ->
          Regular (Selector_work.materialize work, pairing)
      | Sub_zkapp_command job ->
          Sub_zkapp_command (Zkapp_command_job.materialize job)

    let cache ~(proof_cache_db : Proof_cache_tag.cache_db) :
        Stable.Latest.t -> t = function
      | Regular (work, pairing) ->
          Regular (Selector_work.cache ~proof_cache_db work, pairing)
      | Sub_zkapp_command job ->
          Sub_zkapp_command (Zkapp_command_job.cache ~proof_cache_db job)

    let regular_opt (work : t) : Selector_work.t option =
      match work with Regular (w, _) -> Some w | _ -> None

    let map_regular_witness ~f = function
      | Regular (work, pairing) ->
          Regular
            (Work.Single.Spec.map ~f_witness:f ~f_proof:Fn.id work, pairing)
      | Sub_zkapp_command seg ->
          Sub_zkapp_command seg

    let statement : t -> Transaction_snark.Statement.t = function
      | Regular (regular, _) ->
          Work.Single.Spec.statement regular
      | Sub_zkapp_command
          { spec = Zkapp_command_job.Spec.Segment { statement; _ }; _ } ->
          Mina_state.Snarked_ledger_state.With_sok.drop_sok statement
      | Sub_zkapp_command
          { spec = Zkapp_command_job.Spec.Merge { proof1; proof2 }; _ } -> (
          let module Statement = Mina_state.Snarked_ledger_state in
          let { Proof_carrying_data.data = t1; _ } = proof1 in
          let { Proof_carrying_data.data = t2; _ } = proof2 in
          let statement =
            Statement.merge
              ({ t1 with sok_digest = () } : Statement.t)
              { t2 with sok_digest = () }
          in
          match statement with
          | Ok statement ->
              statement
          | Error _ ->
              failwith
                "Failed to construct a statement from  zkapp merge command" )

    let transaction : t -> Mina_transaction.Transaction.t option = function
      | Regular (work, _) ->
          work |> Work.Single.Spec.witness
          |> Option.map ~f:(fun w -> w.Transaction_witness.transaction)
      | Sub_zkapp_command _ ->
          None
  end
end
