open Core_kernel
module Ledger_proof = Ledger_proof.Prod
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Wire_work = struct
  module Spec = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Work.Wire.Single.Spec.Stable.V2.t Work.Compact.Spec.Stable.V1.t
        [@@deriving to_yojson]

        let to_latest = Fn.id
      end

      module V1 = struct
        type t =
          Work.Wire.Regular_work_single.Stable.V1.t
          Work.Compact.Spec.Stable.V1.t
        [@@deriving to_yojson]

        let to_latest (spec : t) : V2.t =
          Work.Compact.Spec.map
            ~f_single:Work.Wire.Single.Spec.Stable.V1.to_latest spec
      end
    end]
  end

  module Result = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          ( Spec.Stable.V2.t
          , Ledger_proof.Stable.V2.t )
          Work.Compact.Result.Stable.V2.t

        let to_latest = Fn.id
      end

      module V1 = struct
        type t =
          ( Spec.Stable.V1.t
          , Ledger_proof.Stable.V2.t )
          Work.Compact.Result.Stable.V1.t

        let to_latest (t : t) : V2.t =
          Work.Compact.Result.Stable.V1.to_latest t
          |> Work.Compact.Result.map ~f_single:Fn.id
               ~f_spec:Spec.Stable.V1.to_latest
      end
    end]

    let transactions (t : t) =
      One_or_two.map t.spec.instances ~f:(fun i ->
          Work.Wire.Single.Spec.transaction i )
  end
end
