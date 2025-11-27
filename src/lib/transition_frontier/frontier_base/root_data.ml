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

    (* TODO replace block with block tag *)
    module V4 = struct
      type t =
        { block_tag :
            ( State_hash.Stable.V1.t
            , Mina_block.Stable.V2.t )
            Multi_key_file_storage.Tag.Stable.V1.t
        ; state_hash : State_hash.Stable.V1.t
        ; protocol_states :
            Mina_state.Protocol_state.Value.Stable.V2.t
            Mina_base.State_hash.With_state_hashes.Stable.V1.t
            list
        ; common : Common.Stable.V3.t
        }
      [@@deriving fields]

      let to_latest = Fn.id
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
        let state_hash =
          (Mina_block.Validated.Stable.Latest.hashes transition).state_hash
        in
        (* We use append out of caution here, in case part of the system already
           migrated to the new format and the file exists *)
        let block_tag =
          State_hash.File_storage.append_values_exn state_hash ~f:(fun writer ->
              State_hash.File_storage.write_value writer
                (module Mina_block.Stable.Latest)
                (Mina_block.Validated.Stable.Latest.block transition) )
        in
        { V4.block_tag
        ; state_hash
        ; protocol_states
        ; common = Common.Stable.V2.to_latest common
        }
    end
  end]

  type t = Stable.Latest.t =
    { block_tag : Mina_block.Stable.Latest.t State_hash.File_storage.tag
    ; state_hash : State_hash.Stable.V1.t
    ; protocol_states :
        Mina_state.Protocol_state.Value.t
        Mina_base.State_hash.With_state_hashes.t
        list
    ; common : Common.t
    }
  [@@deriving fields]

  let to_yojson { state_hash; common; _ } =
    `Assoc
      [ ("state_hash", State_hash.to_yojson state_hash)
      ; ("common", Common.to_yojson common)
      ]

  let create ~block_tag ~state_hash ~scan_state ~pending_coinbase
      ~protocol_states =
    let common = { Common.scan_state; pending_coinbase } in
    { block_tag; state_hash; protocol_states; common }

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t =
        { state_hash : State_hash.Stable.V1.t; common : Common.Stable.V3.t }
      [@@deriving fields]

      let of_limited ~common state_hash = { state_hash; common }

      let to_latest = Fn.id

      let common t = t.common

      let scan_state t = t.common.Common.Stable.Latest.scan_state

      let pending_coinbase t = t.common.Common.Stable.Latest.pending_coinbase
    end

    module V2 = struct
      type t =
        { state_hash : State_hash.Stable.V1.t; common : Common.Stable.V2.t }

      let to_latest { state_hash; common } =
        { V3.state_hash; common = Common.Stable.V2.to_latest common }
    end
  end]

  type t = { state_hash : State_hash.t; common : Common.t } [@@deriving fields]

  let of_limited ~common state_hash = { state_hash; common }

  let upgrade t ~block_tag ~protocol_states =
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
    { Limited.block_tag
    ; state_hash = t.state_hash
    ; protocol_states
    ; common = t.common
    }

  let create ~state_hash ~scan_state ~pending_coinbase =
    let common = { Common.scan_state; pending_coinbase } in
    { state_hash; common }

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

type t =
  { block_tag : Mina_block.Stable.Latest.t Mina_base.State_hash.File_storage.tag
  ; state_hash : State_hash.t
  ; staged_ledger : Staged_ledger.t
  ; protocol_states :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  ; delta_block_chain_proof : State_hash.t Mina_stdlib.Nonempty_list.t
  }

let minimize
    { staged_ledger
    ; protocol_states = _
    ; block_tag = _
    ; state_hash
    ; delta_block_chain_proof = _
    } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  { Minimal.state_hash; common }

let limit
    { staged_ledger
    ; protocol_states
    ; block_tag
    ; state_hash
    ; delta_block_chain_proof = _
    } =
  let scan_state = Staged_ledger.scan_state staged_ledger in
  let pending_coinbase =
    Staged_ledger.pending_coinbase_collection staged_ledger
  in
  let common = Common.create ~scan_state ~pending_coinbase in
  { Limited.block_tag; common; protocol_states; state_hash }
