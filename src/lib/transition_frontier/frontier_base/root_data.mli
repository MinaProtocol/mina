open Coda_base
open Coda_transition

module Minimal : sig
  module Stable : sig
    module V1 : sig
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
      [@@deriving bin_io, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t
end

(** A root transition is a representation of the
 *  change that occurs in a transition frontier when the
 *  root is transitioned. It contains a pointer to the new
 *  root, as well as pointers to all the nodes which are removed
 *  by transitioning the root.
 *)
module Transition : sig
  module Stable : sig
    module V1 : sig
      type t =
        { new_root: Minimal.Stable.V1.t
        ; garbage: State_hash.Stable.V1.t list }
      [@@deriving bin_io, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t
end

type t =
  { transition: External_transition.Validated.t
  ; staged_ledger: Staged_ledger.t }

val minimize : t -> Minimal.t
