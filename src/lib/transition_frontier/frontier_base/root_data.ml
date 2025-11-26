open Core_kernel
open Mina_base

module Common = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type t =
        { scan_state : Staged_ledger.Scan_state.Stable.V3.t
        ; pending_coinbase : Pending_coinbase.Stable.V2.t
        }

      let to_latest = Fn.id
    end

    module V2 = struct
      type t =
        { scan_state : Staged_ledger.Scan_state.Stable.V2.t
        ; pending_coinbase : Pending_coinbase.Stable.V2.t
        }

      let to_latest { scan_state; pending_coinbase } =
        { V3.scan_state =
            Staged_ledger.Scan_state.Stable.V2.to_latest scan_state
        ; pending_coinbase
        }
    end
  end]

  let to_yojson { scan_state = _; pending_coinbase } =
    `Assoc
      [ ("scan_state", `String "<opaque>")
      ; ( "pending_coinbase"
        , Pending_coinbase.Stable.V2.to_yojson pending_coinbase )
      ]

  let create ~scan_state ~pending_coinbase = { scan_state; pending_coinbase }

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase
end

module Historical = struct
  type t =
    { block_tag : Network_types.Block.data_tag
    ; staged_ledger_aux_and_pending_coinbases :
        Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag
    ; required_state_hashes : State_hash.Set.t
    ; protocol_state_with_hashes :
        Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t
    }
  [@@deriving fields]

  let protocol_state t = With_hash.data t.protocol_state_with_hashes

  let create ~block_tag ~staged_ledger_aux_and_pending_coinbases
      ~required_state_hashes ~protocol_state_with_hashes =
    { block_tag
    ; staged_ledger_aux_and_pending_coinbases
    ; required_state_hashes
    ; protocol_state_with_hashes
    }
end

module Limited = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V4 = struct
      type t =
        { transition : Mina_block.Validated.Stable.V2.t
        ; protocol_states :
            Mina_state.Protocol_state.Value.Stable.V2.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common : Common.Stable.V3.t
        }
      [@@deriving fields]

      let to_latest = Fn.id

      let hashes t = Mina_block.Validated.Stable.Latest.hashes t.transition

      let create ~transition ~scan_state ~pending_coinbase ~protocol_states =
        let common = { Common.Stable.V3.scan_state; pending_coinbase } in
        { transition; common; protocol_states }
    end

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

      let to_latest { transition; protocol_states; common } =
        { V4.transition
        ; protocol_states
        ; common = Common.Stable.V2.to_latest common
        }
    end
  end]

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

    module V3 = struct
      type t = { hash : State_hash.Stable.V1.t; common : Common.Stable.V3.t }
      [@@deriving fields]

      let of_limited ~common hash = { hash; common }

      let to_latest = Fn.id

      let common t = t.common

      let scan_state t = t.common.Common.Stable.Latest.scan_state

      let pending_coinbase t = t.common.Common.Stable.Latest.pending_coinbase
    end

    module V2 = struct
      type t = { hash : State_hash.Stable.V1.t; common : Common.Stable.V2.t }

      let to_latest { hash; common } =
        { V3.hash; common = Common.Stable.V2.to_latest common }
    end
  end]

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
end

type t =
  { transition : Mina_block.Validated.t
  ; staged_ledger : Staged_ledger.t
  ; protocol_states :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  ; block_tag : Mina_block.Stable.Latest.t Mina_base.State_hash.File_storage.tag
  }

let minimize { transition; staged_ledger; protocol_states = _; block_tag = _ } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  { Minimal.hash = Mina_block.Validated.state_hash transition; common }

let limit { transition; staged_ledger; protocol_states; block_tag = _ } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  { Limited.transition; common; protocol_states }
