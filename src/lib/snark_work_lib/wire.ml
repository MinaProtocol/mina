open Core_kernel
open Transaction_snark
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

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

    let ignored = Stable.Latest.Pairing_UUID (-1)
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. This is needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { one_or_two : [ `First | `Second | `One ]
        ; pair_uuid : UUID.Stable.V1.t
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Regular_work_single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Transaction_witness.Stable.V2.t
        , Ledger_proof.Stable.V2.t )
        Compact.Single.Spec.Stable.V2.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_job = struct
  (* A Zkapp_command_job.t`this identifies a single `Zkapp_command_job` *)
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
      module V1 = struct
        type t =
          | Segment of
              { statement : Statement.With_sok.Stable.V2.t
              ; witness : Zkapp_command_segment.Witness.Stable.V1.t
              ; spec : Zkapp_command_segment.Basic.Stable.V1.t
              }
          | Merge of
              { proof1 : Ledger_proof.Stable.V2.t
              ; proof2 : Ledger_proof.Stable.V2.t
              }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
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
end

(* this is the actual work passed over network between coordinator and worker *)
module Single = struct
  module Spec = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Regular of (Regular_work_single.Stable.V1.t * Pairing.Stable.V1.t)
          | Sub_zkapp_command of Zkapp_command_job.Stable.V1.t
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end

      module V1 = struct
        type t = Regular_work_single.Stable.V1.t [@@deriving sexp, yojson]

        let to_latest ~one_or_two (t : t) : V2.t =
          Regular
            ( t
            , { Pairing.Stable.V1.pair_uuid = Pairing.UUID.ignored; one_or_two }
            )
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, yojson]

    let regular_opt (work : t) : Regular_work_single.t option =
      match work with Regular (w, _) -> Some w | _ -> None

    let map_regular_witness ~f = function
      | Regular (work, pairing) ->
          Regular
            (Compact.Single.Spec.map ~f_witness:f ~f_proof:Fn.id work, pairing)
      | Sub_zkapp_command seg ->
          Sub_zkapp_command seg

    let statement : t -> Statement.Stable.V2.t option = function
      | Regular (regular, _) ->
          Some (Compact.Single.Spec.statement regular)
      | Sub_zkapp_command _ ->
          None

    let transaction : t -> Mina_transaction.Transaction.Stable.V2.t option =
      function
      | Regular (work, _) ->
          work |> Compact.Single.Spec.witness
          |> Option.map ~f:(fun w ->
                 w.Transaction_witness.Stable.V2.transaction )
      | Sub_zkapp_command _ ->
          None
  end
end

module Spec = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Single.Spec.Stable.V2.t Compact.Spec.Stable.V1.t
      [@@deriving to_yojson]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t = Regular_work_single.Stable.V1.t Compact.Spec.Stable.V1.t
      [@@deriving to_yojson]

      let to_latest (spec : t) : V2.t =
        Compact.Spec.map_biased ~f_single:Single.Spec.Stable.V1.to_latest spec
    end
  end]
end

module Result = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        (Spec.Stable.V2.t, Ledger_proof.Stable.V2.t) Compact.Result.Stable.V2.t

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        (Spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Compact.Result.Stable.V1.t

      let to_latest (t : t) : V2.t =
        Compact.Result.Stable.V1.to_latest t
        |> Compact.Result.map ~f_single:Fn.id ~f_spec:Spec.Stable.V1.to_latest
    end
  end]

  let transactions (t : t) =
    One_or_two.map t.spec.instances ~f:(fun i -> Single.Spec.transaction i)
end
