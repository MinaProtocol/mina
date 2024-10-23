open Core_kernel
open Mina_base

module Common = struct
  module Wire = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { scan_state : Transaction_snark_scan_state.Wire.Stable.V2.t
          ; pending_coinbase : Pending_coinbase.Stable.V2.t
          }

        let to_latest = Fn.id

        let to_yojson { scan_state = _; pending_coinbase } =
          `Assoc
            [ ("scan_state", `String "<opaque>")
            ; ( "pending_coinbase"
              , Pending_coinbase.Stable.V2.to_yojson pending_coinbase )
            ]
      end
    end]
  end

  type t =
    { scan_state : Transaction_snark_scan_state.t
    ; pending_coinbase : Pending_coinbase.t
    }

  let create ~scan_state ~pending_coinbase = { scan_state; pending_coinbase }

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase
end

module Historical = struct
  type t =
    { transition : Mina_block.Validated.t
    ; common : Common.t
    ; staged_ledger_target_ledger_hash : Ledger_hash.t
    }

  let transition t = t.transition

  let staged_ledger_target_ledger_hash t = t.staged_ledger_target_ledger_hash

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common

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
    let common = Common.create ~scan_state ~pending_coinbase in
    { transition; common; staged_ledger_target_ledger_hash }
end

module Limited = struct
  [%%versioned
  module Stable = struct
    module V4 = struct
      type t =
        { transition :
            Mina_block.Stable.V2.t State_hash.With_state_hashes.Stable.V1.t
        ; protocol_states :
            Mina_state.Protocol_state.Value.Stable.V2.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common : Common.Wire.Stable.V2.t
        }

      let to_latest = Fn.id
    end

    (* TODO remove this type in a hardfork *)
    module V3 = struct
      type t =
        { transition :
            Mina_block.Stable.V2.t State_hash.With_state_hashes.Stable.V1.t
            * State_hash.Stable.V1.t Mina_stdlib.Nonempty_list.Stable.V1.t
        ; protocol_states :
            Mina_state.Protocol_state.Value.Stable.V2.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common : Common.Wire.Stable.V2.t
        }

      let to_latest : t -> V4.t =
       fun { transition = transition, _; protocol_states; common } ->
        { V4.transition; protocol_states; common }
    end
  end]

  let to_yojson { transition; protocol_states = _; common } =
    `Assoc
      [ ("transition", Mina_block.Validated.to_yojson transition)
      ; ("protocol_states", `String "<opaque>")
      ; ("common", Common.Stable.V2.to_yojson common)
      ]

  let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
    let common = { Common.Wire.scan_state; pending_coinbase } in
    { transition; common; protocol_states }

  let transition t = t.transition

  let hashes t = With_hash.hash t.transition

  let protocol_states t = t.protocol_states

  let scan_state t = t.common.scan_state

  let pending_coinbase t = t.common.pending_coinbase
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        { hash : State_hash.Stable.V1.t; common : Common.Wire.Stable.V2.t }
      [@@driving to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = { hash : State_hash.t; common : Common.Wire.t }
  [@@driving to_yojson]

  let hash t = t.hash

  let of_limited (l : Limited.t) =
    let hash = State_hash.With_state_hashes.state_hash l.transition in
    { hash; common = l.common }

  let upgrade t ~transition ~protocol_states =
    let hash = hash t in
    assert (State_hash.equal (Mina_block.Validated.state_hash transition) hash) ;
    let protocol_states =
      List.map protocol_states ~f:(fun (state_hash, s) ->
          { With_hash.data = s
          ; hash =
              { Mina_base.State_hash.State_hashes.state_hash
              ; state_body_hash = None
              }
          } )
    in
    let transition =
      Mina_block.forget_computed_hashes (Mina_block.Validated.forget transition)
    in
    ignore
      ( Transaction_snark_scan_state.check_required_protocol_states
          ~is_zkapp_transaction:
            Mina_transaction_logic.Transaction_applied.Wire.is_zkapp_transaction
          t.common.scan_state.scan_state
          t.common.scan_state.previous_incomplete_zkapp_updates ~protocol_states
        |> Or_error.ok_exn
        : Mina_state.Protocol_state.value State_hash.With_state_hashes.t list ) ;
    { Limited.transition; protocol_states; common = t.common }

  let create ~hash ~scan_state ~pending_coinbase =
    let common = { Common.Wire.scan_state; pending_coinbase } in
    { hash; common }

  let scan_state t = t.common.scan_state

  let pending_coinbase t = t.common.pending_coinbase
end

type t =
  { transition : Mina_block.Validated.t
  ; staged_ledger : Staged_ledger.t
  ; protocol_states :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  }

let minimize { transition; staged_ledger; protocol_states = _ } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common =
    { Common.Wire.scan_state = Transaction_snark_scan_state.to_wire scan_state
    ; pending_coinbase
    }
  in
  { Minimal.hash = Mina_block.Validated.state_hash transition; common }

let limit { transition; staged_ledger; protocol_states } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let transition =
    Mina_block.Validated.forget transition |> Mina_block.forget_computed_hashes
  in
  let common =
    { Common.Wire.scan_state = Transaction_snark_scan_state.to_wire scan_state
    ; pending_coinbase
    }
  in
  { Limited.transition; common; protocol_states }
