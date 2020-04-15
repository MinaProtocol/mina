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

module Common = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { scan_state: Staged_ledger.Scan_state.Stable.V1.t
        ; pending_coinbase: Pending_coinbase.Stable.V1.t
        ; protocol_states:
            ( Coda_base.State_hash.Stable.V1.t
            * Coda_state.Protocol_state.Value.Stable.V1.t )
            list }

      let to_latest = Fn.id

      let to_yojson {scan_state= _; pending_coinbase; protocol_states= _} =
        `Assoc
          [ ("scan_state", `String "<opaque>")
          ; ("pending_coinbase", Pending_coinbase.to_yojson pending_coinbase)
          ; ("protocol_states", `String "<opaque>") ]
    end
  end]

  type t = Stable.Latest.t =
    { scan_state: Staged_ledger.Scan_state.t
    ; pending_coinbase: Pending_coinbase.t
    ; protocol_states:
        (Coda_base.State_hash.t * Coda_state.Protocol_state.Value.t) list }

  [%%define_locally
  Stable.Latest.(to_yojson)]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'transition t = {transition: 'transition; common: Common.Stable.V1.t}
      [@@deriving to_yojson]
    end
  end]

  type 'transition t = 'transition Stable.Latest.t =
    {transition: 'transition; common: Common.t}
  [@@deriving to_yojson]

  let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
    let common = {Common.scan_state; pending_coinbase; protocol_states} in
    {transition; common}

  let of_transition_and_common ~transition ~common = {transition; common}

  let transition t = t.transition

  let common t = t.common

  let scan_state t = t.common.scan_state

  let pending_coinbase t = t.common.pending_coinbase

  let protocol_states t = t.common.protocol_states
end

module Limited = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = External_transition.Validated.Stable.V1.t Poly.Stable.V1.t
      [@@deriving to_yojson]

      let to_latest = Fn.id

      (*let to_yojson
          {transition; common} =
        `Assoc
          [ ("transition", External_transition.Validated.to_yojson transition)
          ; ("common", Common.to_yojson common)]*)
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson]

  [%%define_locally
  Poly.
    ( create
    , transition
    , common
    , scan_state
    , pending_coinbase
    , protocol_states
    , of_transition_and_common )]
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = State_hash.Stable.V1.t Poly.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  [%%define_locally
  Poly.
    ( create
    , transition
    , common
    , scan_state
    , pending_coinbase
    , protocol_states
    , of_transition_and_common )]

  let hash = transition

  let of_limited (l : Limited.t) =
    let hash =
      External_transition.Validated.state_hash (Limited.transition l)
    in
    of_transition_and_common ~transition:hash ~common:(Limited.common l)

  let upgrade t ~transition =
    let hash = hash t in
    assert (
      State_hash.equal
        (External_transition.Validated.state_hash transition)
        hash ) ;
    Limited.of_transition_and_common ~transition ~common:(common t)

  let create ~hash = create ~transition:hash
end

type t =
  { transition: External_transition.Validated.t
  ; staged_ledger: Staged_ledger.t
  ; protocol_states:
      (Coda_base.State_hash.t * Coda_state.Protocol_state.Value.t) list }

let minimize {transition; staged_ledger; protocol_states} =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  Minimal.create
    ~hash:(External_transition.Validated.state_hash transition)
    ~scan_state ~protocol_states ~pending_coinbase

let limit {transition; staged_ledger; protocol_states} =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  Limited.create ~transition ~scan_state ~protocol_states ~pending_coinbase
