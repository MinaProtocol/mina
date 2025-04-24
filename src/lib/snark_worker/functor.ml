open Core
open Async

module Make (Inputs : Intf.Inputs_intf) :
  Intf.S0 with type ledger_proof := Inputs.Ledger_proof.t = struct
  open Inputs
  module Rpcs = Rpcs.Make (Inputs)

  module Work = struct
    open Snark_work_lib

    module Single = struct
      module Spec = struct
        type t =
          ( Transaction_witness.Stable.Latest.t
          , Ledger_proof.t )
          Work.Single.Spec.t
        [@@deriving sexp, yojson]

        let transaction t =
          Option.map (Work.Single.Spec.witness t) ~f:(fun w ->
              w.Transaction_witness.Stable.Latest.transaction )

        let statement = Work.Single.Spec.statement
      end
    end

    module Spec = struct
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp, yojson]

      let instances = Work.Spec.instances
    end

    module Result = struct
      type t = (Spec.t, Ledger_proof.t) Work.Result.t

      let transactions (t : t) =
        One_or_two.map t.spec.instances ~f:(fun i -> Single.Spec.transaction i)
    end
  end
end
