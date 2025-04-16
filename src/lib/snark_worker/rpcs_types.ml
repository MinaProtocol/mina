open Core_kernel
module Ledger_proof = Ledger_proof.Prod
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Regular_work_single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Transaction_witness.Stable.V2.t
        , Ledger_proof.Stable.V2.t )
        Work.Single.Spec.Stable.V2.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_segment_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { id : int
        ; statement : Transaction_snark.Statement.With_sok.Stable.V2.t
        ; witness : Zkapp_command_segment.Witness.Stable.V1.t
        ; spec : Zkapp_command_segment.Basic.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Wire_work = struct
  module Single = struct
    module Spec = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            | Regular of Regular_work_single.Stable.V1.t
            | Zkapp_command_segment of Zkapp_command_segment_work.Stable.V1.t
          [@@deriving sexp, yojson]

          let to_latest = Fn.id
        end

        module V1 = struct
          type t = Regular_work_single.Stable.V1.t [@@deriving sexp, yojson]

          let to_latest (t : t) : V2.t = Regular t
        end
      end]

      type t = Stable.Latest.t [@@deriving sexp, yojson]

      let map_regular_witness ~f = function
        | Regular work ->
            Regular
              (Snark_work_lib.Work.Single.Spec.map ~f_witness:f ~f_proof:Fn.id
                 work )
        | Zkapp_command_segment seg ->
            Zkapp_command_segment seg

      let statement : t -> Transaction_snark.Statement.Stable.V2.t = function
        | Regular regular ->
            Work.Single.Spec.statement regular
        | Zkapp_command_segment { statement; _ } ->
            Transaction_snark.Statement.With_sok.drop_sok statement

      let transaction : t -> Mina_transaction.Transaction.Stable.V2.t option =
        function
        | Regular work ->
            work |> Work.Single.Spec.witness
            |> Option.map ~f:(fun w ->
                   w.Transaction_witness.Stable.V2.transaction )
        | Zkapp_command_segment _ ->
            None
    end
  end

  module Spec = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Single.Spec.Stable.V2.t Work.Spec.Stable.V1.t
        [@@deriving to_yojson]

        let to_latest = Fn.id
      end

      module V1 = struct
        type t = Single.Spec.Stable.V1.t Work.Spec.Stable.V1.t
        [@@deriving to_yojson]

        let to_latest : t -> V2.t =
          Work.Spec.map ~f_single:Single.Spec.Stable.V1.to_latest
      end
    end]
  end

  module Result = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          (Spec.Stable.V2.t, Ledger_proof.Stable.V2.t) Work.Result.Stable.V2.t

        let to_latest = Fn.id
      end

      module V1 = struct
        type t =
          (Spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Work.Result.Stable.V1.t

        let to_latest (t : t) : V2.t =
          Work.Result.Stable.V1.to_latest t
          |> Work.Result.map ~f_single:Fn.id ~f_spec:Spec.Stable.V1.to_latest
      end
    end]

    let transactions (t : t) =
      One_or_two.map t.spec.instances ~f:(fun i -> Single.Spec.transaction i)
  end
end
