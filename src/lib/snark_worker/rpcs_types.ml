open Core_kernel
open Signature_lib
module Ledger_proof = Ledger_proof.Prod
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Wire_work = struct
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

      let transaction (t : t) : Mina_transaction.Transaction.Stable.V2.t option
          =
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
end

module Regular_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { work_spec : Wire_work.Spec.Stable.V1.t
        ; public_key : Public_key.Compressed.Stable.V1.t
        }

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

      let to_latest = Fn.id
    end
  end]
end

module Failed_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Regular of Regular_work.Stable.V1.t
        | Zkapp_command_segment of Zkapp_command_segment_work.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end
