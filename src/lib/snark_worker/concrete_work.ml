open Snark_work_lib
open Core_kernel
module Ledger_proof = Ledger_proof.Prod

module Single = struct
  module Spec = struct
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

    type t = Stable.Latest.t [@@deriving sexp, yojson]

    let transaction (t : t) : Mina_transaction.Transaction.Stable.V2.t option =
      Work.Single.Spec.witness t
      |> Option.map ~f:(fun w -> w.Transaction_witness.Stable.V2.transaction)
  end
end

module Spec = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Single.Spec.Stable.V1.t Work.Spec.Stable.V1.t
      [@@deriving to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module Result = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (Spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Work.Result.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  let transactions (t : t) =
    One_or_two.map t.spec.instances ~f:(fun i -> Single.Spec.transaction i)
end
