open Snark_work_lib
open Core_kernel
module Ledger_proof = Ledger_proof.Prod

module Single = struct
  module Spec = struct
    (* bin_io is for uptime service SNARK worker *)
    type t =
      ( Transaction_witness.Stable.Latest.t
      , Ledger_proof.Stable.Latest.t )
      Work.Single.Spec.Stable.Latest.t
    [@@deriving sexp, bin_io_unversioned, to_yojson]

    let transaction t =
      Work.Single.Spec.witness t
      |> Option.map ~f:(fun w ->
             w.Transaction_witness.Stable.Latest.transaction )
  end
end

module Spec = struct
  type t = Single.Spec.t Work.Spec.t [@@deriving to_yojson]
end

module Result = struct
  type t = (Spec.t, Ledger_proof.Stable.Latest.t) Work.Result.t

  let transactions (t : t) =
    One_or_two.map t.spec.instances ~f:(fun i -> Single.Spec.transaction i)
end
