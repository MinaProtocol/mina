open Core_kernel
open Coda_state

module type S = sig
  type t [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V2 : sig
        type t [@@deriving sexp, to_yojson, bin_io]
      end

      module V1 : sig
        type t [@@deriving bin_io]

        val to_latest : t -> V2.t
      end

      module Latest = V2
    end
    with type V2.t = t

  val create :
       snark_transition:Snark_transition.Value.t
    -> prover_state:Consensus.Data.Prover_state.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val snark_transition : t -> Snark_transition.Value.t

  val prover_state : t -> Consensus.Data.Prover_state.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { snark_transition: Snark_transition.Value.Stable.V1.t
      ; prover_state: Consensus.Data.Prover_state.Stable.V2.t
      ; staged_ledger_diff: Staged_ledger_diff.Stable.V2.t }
    [@@deriving sexp, to_yojson, fields]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      { snark_transition: Snark_transition.Value.Stable.V1.t
      ; prover_state: Consensus.Data.Prover_state.Stable.V1.t
      ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
    [@@deriving sexp, to_yojson, fields]

    let to_latest {snark_transition; prover_state; staged_ledger_diff} =
      { V2.snark_transition
      ; prover_state=
          Consensus.Data.Prover_state.Stable.V1.to_latest prover_state
      ; staged_ledger_diff=
          Staged_ledger_diff.Stable.V1.to_latest staged_ledger_diff }
  end
end]

(* bin_io, version omitted *)
type t = Stable.Latest.t =
  { snark_transition: Snark_transition.Value.t
  ; prover_state: Consensus.Data.Prover_state.t
  ; staged_ledger_diff: Staged_ledger_diff.t }
[@@deriving sexp, fields, to_yojson]

let create ~snark_transition ~prover_state ~staged_ledger_diff =
  {Stable.Latest.snark_transition; staged_ledger_diff; prover_state}
