open Core_kernel
open Coda_state
open Module_version

module type S = sig
  type t [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, to_yojson, bin_io]
      end

      module Latest = V1
    end
    with type V1.t = t

  val create :
       snark_transition:Snark_transition.Value.t
    -> prover_state:Consensus.Data.Prover_state.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val snark_transition : t -> Snark_transition.Value.t

  val prover_state : t -> Consensus.Data.Prover_state.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t
end

(*module Make (Staged_ledger_diff : sig
  type t [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, sexp, to_yojson, version]
      end
    end
    with type V1.t = t
end) : S with module Staged_ledger_diff = Staged_ledger_diff = struct
  module Staged_ledger_diff = Staged_ledger_diff*)

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { snark_transition: Snark_transition.Value.Stable.V1.t
        ; prover_state: Consensus.Data.Prover_state.Stable.V1.t
        ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
      [@@deriving sexp, to_yojson, fields, bin_io, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "internal_transition"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io, version omitted *)
type t = Stable.Latest.t =
  { snark_transition: Snark_transition.Value.Stable.V1.t
  ; prover_state: Consensus.Data.Prover_state.Stable.V1.t
  ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
[@@deriving sexp, fields, to_yojson]

let create ~snark_transition ~prover_state ~staged_ledger_diff =
  {Stable.Latest.snark_transition; staged_ledger_diff; prover_state}

(*end

include Make (Staged_ledger_diff)*)
