open Core_kernel
open Mina_base

module Common = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        { scan_state : Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase : Pending_coinbase.Stable.V2.t
        }

      let to_latest = Fn.id
    end
  end]

  module Serializable_type = struct
    type raw_serializable = Stable.Latest.t

    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { scan_state : Staged_ledger.Scan_state.Serializable_type.Stable.V2.t
          ; pending_coinbase : Pending_coinbase.Stable.V2.t
          }

        let to_latest = Fn.id
      end
    end]

    let to_raw_serializable : t -> raw_serializable =
     fun { scan_state; pending_coinbase } ->
      { scan_state =
          Staged_ledger.Scan_state.Serializable_type.to_raw_serializable
            scan_state
      ; pending_coinbase
      }
  end

  type t =
    { scan_state : Staged_ledger.Scan_state.t
    ; pending_coinbase : Pending_coinbase.t
    }

  let to_yojson { scan_state = _; pending_coinbase } =
    `Assoc
      [ ("scan_state", `String "<opaque>")
      ; ( "pending_coinbase"
        , Pending_coinbase.Stable.V2.to_yojson pending_coinbase )
      ]

  let create ~scan_state ~pending_coinbase = { scan_state; pending_coinbase }

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase

  let read_all_proofs_from_disk { scan_state; pending_coinbase } =
    { Stable.Latest.pending_coinbase
    ; scan_state = Staged_ledger.Scan_state.read_all_proofs_from_disk scan_state
    }

  let to_serializable_type : t -> Serializable_type.t =
   fun { scan_state; pending_coinbase } ->
    { scan_state = Staged_ledger.Scan_state.to_serializable_type scan_state
    ; pending_coinbase
    }
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
      Breadcrumb.staged_ledger_hash breadcrumb |> Staged_ledger_hash.ledger_hash
    in
    let common = Common.create ~scan_state ~pending_coinbase in
    { transition; common; staged_ledger_target_ledger_hash }
end

module Limited = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t =
        { transition : Mina_block.Validated.Stable.V2.t
        ; protocol_states :
            Mina_state.Protocol_state.Value.Stable.V2.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common : Common.Stable.V2.t
        }
      [@@deriving fields]

      let to_latest = Fn.id

      let hashes t = Mina_block.Validated.Stable.Latest.hashes t.transition

      let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
        let common = { Common.Stable.V2.scan_state; pending_coinbase } in
        { transition; common; protocol_states }
    end
  end]

  module Serializable_type = struct
    [%%versioned
    module Stable = struct
      module V3 = struct
        type t =
          { transition : Mina_block.Validated.Serializable_type.Stable.V2.t
          ; protocol_states :
              Mina_state.Protocol_state.Value.Stable.V2.t
              Mina_base.State_hash.With_state_hashes.Stable.V1.t
              list
          ; common : Common.Serializable_type.Stable.V2.t
          }
        [@@deriving fields]

        let to_latest = Fn.id
      end
    end]

    let hashes t =
      Mina_block.Validated.Serializable_type.Stable.Latest.hashes t.transition

    let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
      let common = { Common.Serializable_type.scan_state; pending_coinbase } in
      { transition; common; protocol_states }
  end

  type t =
    { transition : Mina_block.Validated.t
    ; protocol_states :
        Mina_state.Protocol_state.Value.t
        Mina_base.State_hash.With_state_hashes.t
        list
    ; common : Common.t
    }
  [@@deriving fields]

  let to_yojson { transition; protocol_states = _; common } =
    `Assoc
      [ ("transition", Mina_block.Validated.to_yojson transition)
      ; ("protocol_states", `String "<opaque>")
      ; ("common", Common.to_yojson common)
      ]

  let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
    let common = { Common.scan_state; pending_coinbase } in
    { transition; common; protocol_states }

  let hashes t = With_hash.hash @@ Mina_block.Validated.forget t.transition

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = { hash : State_hash.Stable.V1.t; common : Common.Stable.V2.t }
      [@@deriving fields]

      let of_limited ~common hash = { hash; common }

      let to_latest = Fn.id

      let common t = t.common

      let scan_state t = t.common.Common.Stable.Latest.scan_state

      let pending_coinbase t = t.common.Common.Stable.Latest.pending_coinbase
    end
  end]

  module Serializable_type = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { hash : State_hash.Stable.V1.t
          ; common : Common.Serializable_type.Stable.V2.t
          }
        [@@deriving fields]

        let of_limited ~common hash = { hash; common }

        let to_latest = Fn.id

        let common t = t.common

        let scan_state t = t.common.Common.Serializable_type.scan_state

        let pending_coinbase t =
          t.common.Common.Serializable_type.pending_coinbase
      end
    end]
  end

  type t = { hash : State_hash.t; common : Common.t } [@@deriving fields]

  let of_limited ~common hash = { hash; common }

  let upgrade t ~transition ~protocol_states =
    assert (State_hash.equal (Mina_block.Validated.state_hash transition) t.hash) ;
    let protocol_states =
      List.map protocol_states ~f:(fun (state_hash, s) ->
          { With_hash.data = s
          ; hash =
              { Mina_base.State_hash.State_hashes.state_hash
              ; state_body_hash = None
              }
          } )
    in
    ignore
      ( Staged_ledger.Scan_state.check_required_protocol_states
          t.common.scan_state ~protocol_states
        |> Or_error.ok_exn
        : Mina_state.Protocol_state.value State_hash.With_state_hashes.t list ) ;
    { Limited.transition; protocol_states; common = t.common }

  let create ~hash ~scan_state ~pending_coinbase =
    let common = { Common.scan_state; pending_coinbase } in
    { hash; common }

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common

  let read_all_proofs_from_disk
      { hash; common = { scan_state; pending_coinbase } } =
    { Stable.Latest.hash
    ; common =
        { pending_coinbase
        ; scan_state =
            Staged_ledger.Scan_state.read_all_proofs_from_disk scan_state
        }
    }
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
  let common = Common.create ~scan_state ~pending_coinbase in
  { Minimal.hash = Mina_block.Validated.state_hash transition; common }

let limit { transition; staged_ledger; protocol_states } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  { Limited.transition; common; protocol_states }
