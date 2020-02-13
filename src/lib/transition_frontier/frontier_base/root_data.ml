open Core_kernel
open Coda_base
open Coda_transition

module Historical = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest
          { transition
          ; scan_state
          ; pending_coinbase
          ; staged_ledger_target_ledger_hash } =
        { V2.transition
        ; scan_state= Staged_ledger.Scan_state.Stable.V1.to_latest scan_state
        ; pending_coinbase
        ; staged_ledger_target_ledger_hash }
    end
  end]

  type t = Stable.Latest.t =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t
    ; staged_ledger_target_ledger_hash: Ledger_hash.t }

  include (Stable.Latest : module type of Stable.Latest with type t := t)

  let of_breadcrumb breadcrumb =
    let transition = Breadcrumb.validated_transition breadcrumb in
    let staged_ledger = Breadcrumb.staged_ledger breadcrumb in
    let scan_state = Staged_ledger.scan_state staged_ledger in
    let pending_coinbase =
      Staged_ledger.pending_coinbase_collection staged_ledger
    in
    let staged_ledger_target_ledger_hash =
      Staged_ledger.hash staged_ledger |> Staged_ledger_hash.ledger_hash
    in
    {transition; scan_state; pending_coinbase; staged_ledger_target_ledger_hash}
end

module Limited = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest {transition; scan_state; pending_coinbase} =
        { V2.transition
        ; scan_state= Staged_ledger.Scan_state.Stable.V1.to_latest scan_state
        ; pending_coinbase }
    end
  end]

  type t = Stable.Latest.t =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t }

  include (Stable.Latest : module type of Stable.Latest with type t := t)
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }
      [@@deriving bin_io, version]

      let to_latest {hash; scan_state; pending_coinbase} =
        { V2.hash
        ; scan_state= Staged_ledger.Scan_state.Stable.V1.to_latest scan_state
        ; pending_coinbase }
    end
  end]

  type t = Stable.Latest.t =
    { hash: State_hash.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t }

  include (Stable.Latest : module type of Stable.Latest with type t := t)

  let of_limited {Limited.transition; scan_state; pending_coinbase} =
    let hash = External_transition.Validated.state_hash transition in
    {hash; scan_state; pending_coinbase}

  let upgrade {hash; scan_state; pending_coinbase} transition =
    assert (
      State_hash.equal
        (External_transition.Validated.state_hash transition)
        hash ) ;
    {Limited.transition; scan_state; pending_coinbase}
end

type t =
  {transition: External_transition.Validated.t; staged_ledger: Staged_ledger.t}

let minimize {transition; staged_ledger} =
  { Minimal.hash= External_transition.Validated.state_hash transition
  ; scan_state= Staged_ledger.scan_state staged_ledger
  ; pending_coinbase= Staged_ledger.pending_coinbase_collection staged_ledger
  }

let limit {transition; staged_ledger} =
  { Limited.transition
  ; scan_state= Staged_ledger.scan_state staged_ledger
  ; pending_coinbase= Staged_ledger.pending_coinbase_collection staged_ledger
  }
