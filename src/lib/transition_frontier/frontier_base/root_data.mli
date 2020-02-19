open Coda_base
open Coda_transition

(* Historical root data is similar to Limited root data, except that it also
 * contains a recording of some extra computed staged ledger properties that
 * were available on a breadcrumb in the transition frontier when this was
 * created. *)
module Historical : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        { transition: External_transition.Validated.Stable.V2.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }
    end

    module V1 : sig
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }

      val to_latest : t -> V2.t
    end
  end]

  type t =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t
    ; staged_ledger_target_ledger_hash: Ledger_hash.t }

  val of_breadcrumb : Breadcrumb.t -> t
end

(* Limited root data is similar to Minimal root data, except that it contains
 * the full validated transition at a root instead of just a pointer to one *)
module Limited : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        { transition: External_transition.Validated.Stable.V2.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
    end

    module V1 : sig
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }

      val to_latest : t -> V2.t
    end
  end]

  type t = Stable.Latest.t
end

(* Minimal root data contains the smallest amount of information about a root.
 * It contains a hash pointing to the root transition, and the auxilliary data
 * needed to reconstruct the staged ledger at that point (scan_state,
 * pending_coinbase).
 *)
module Minimal : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
    end

    module V1 : sig
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }

      val to_latest : t -> V2.t
    end
  end]

  type t = Stable.Latest.t =
    { hash: State_hash.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t }

  val of_limited : Limited.t -> t

  val upgrade : t -> External_transition.Validated.t -> Limited.t
end

type t =
  {transition: External_transition.Validated.t; staged_ledger: Staged_ledger.t}

val minimize : t -> Minimal.t

val limit : t -> Limited.t
