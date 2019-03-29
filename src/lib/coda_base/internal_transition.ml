open Core_kernel
open Module_version

module type S = sig
  module Prover_state : sig
    type t [@@deriving sexp, bin_io]
  end

  module Snark_transition : Snark_transition.S

  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io]
      end

      module Latest = V1
    end
    with type V1.t = t

  val create :
       snark_transition:Snark_transition.value
    -> prover_state:Prover_state.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val snark_transition : t -> Snark_transition.value

  val prover_state : t -> Prover_state.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t
end

module Make (Snark_transition : Snark_transition.S) (Prover_state : sig
    type t [@@deriving sexp, bin_io]
end) :
  S
  with module Snark_transition = Snark_transition
   and module Prover_state = Prover_state = struct
  module Snark_transition = Snark_transition
  module Prover_state = Prover_state

  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          { snark_transition: Snark_transition.value
          ; prover_state: Prover_state.t
          ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
        [@@deriving sexp, fields, bin_io]
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

  (* bin_io intentionally omitted *)
  type t = Stable.Latest.t =
    { snark_transition: Snark_transition.value
    ; prover_state: Prover_state.t
    ; staged_ledger_diff: Staged_ledger_diff.t }
  [@@deriving sexp, fields]

  let create ~snark_transition ~prover_state ~staged_ledger_diff =
    {snark_transition; staged_ledger_diff; prover_state}
end
