open Core_kernel
module Ledger_proof = Ledger_proof.Prod
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Wire_work = struct
  module Spec = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Single.Spec.Stable.V2.t Work.Spec.Stable.V2.t
        [@@deriving to_yojson]

        let to_latest = Fn.id
      end

      module V1 = struct
        type t = Single.Spec.Stable.V1.t Work.Spec.Stable.V1.t
        [@@deriving to_yojson]

        let to_latest (spec : t) : V2.t =
          Work.Spec.Stable.V1.to_latest spec
          |> Work.Spec.map ~f_single:Single.Spec.Stable.V1.to_latest
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
