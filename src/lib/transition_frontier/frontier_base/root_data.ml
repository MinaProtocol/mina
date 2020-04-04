open Core_kernel
open Coda_base
open Coda_transition

module Historical = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; staged_ledger_target_ledger_hash: Ledger_hash.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t
    ; staged_ledger_target_ledger_hash: Ledger_hash.t }

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
    module V1 = struct
      type t =
        { transition: External_transition.Validated.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }

      let to_latest = Fn.id

      let to_yojson {transition; scan_state= _; pending_coinbase} =
        `Assoc
          [ ("transition", External_transition.Validated.to_yojson transition)
          ; ("scan_state", `String "<opaque>")
          ; ("pending_coinbase", Pending_coinbase.to_yojson pending_coinbase)
          ]
    end
  end]

  type t = Stable.Latest.t =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t }

  [%%define_locally
  Stable.Latest.(to_yojson)]
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { hash: State_hash.Stable.V1.t
        ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { hash: State_hash.t
    ; scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t }

  let of_limited {Limited.Stable.V1.transition; scan_state; pending_coinbase} =
    let hash = External_transition.Validated.state_hash transition in
    {hash; scan_state; pending_coinbase}

  let upgrade {hash; scan_state; pending_coinbase} transition =
    assert (
      State_hash.equal
        (External_transition.Validated.state_hash transition)
        hash ) ;
    {Limited.Stable.V1.transition; scan_state; pending_coinbase}
end

type t =
  {transition: External_transition.Validated.t; staged_ledger: Staged_ledger.t}

let minimize {transition; staged_ledger} =
  let open Minimal.Stable.Latest in
  { hash= External_transition.Validated.state_hash transition
  ; scan_state= Staged_ledger.scan_state staged_ledger
  ; pending_coinbase= Staged_ledger.pending_coinbase_collection staged_ledger
  }

let limit {transition; staged_ledger} =
  let open Limited.Stable.Latest in
  { transition
  ; scan_state= Staged_ledger.scan_state staged_ledger
  ; pending_coinbase= Staged_ledger.pending_coinbase_collection staged_ledger
  }
