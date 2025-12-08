open Core_kernel
open Mina_base

module Common = struct
  [%%versioned
  module Stable = struct
    (* TODO: split out V3 as a new type, remove the "option" from [block_data_opt] *)
    module V3 = struct
      type t =
        { scan_state : Staged_ledger.Scan_state.Stable.V3.t
        ; pending_coinbase : Pending_coinbase.Stable.V2.t
        ; block_data_opt : Block_data.Stable.V1.t option
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
        ; block_data_opt = None
        }
    end
  end]

  let create ~scan_state ~pending_coinbase ~block_data_opt =
    { scan_state; pending_coinbase; block_data_opt }

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase

  let protocol_state t =
    Option.map t.block_data_opt ~f:(fun t -> t.protocol_state)
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
  type t =
    { state_hash : State_hash.Stable.Latest.t
    ; protocol_states_for_scan_state :
        Mina_state.Protocol_state.Value.Stable.Latest.t
        Mina_base.State_hash.With_state_hashes.Stable.Latest.t
        list
    ; scan_state : Staged_ledger.Scan_state.Stable.Latest.t
    ; pending_coinbase : Pending_coinbase.Stable.Latest.t
    ; protocol_state : Mina_state.Protocol_state.Value.Stable.Latest.t
    ; block_tag :
        ( State_hash.Stable.Latest.t
        , Mina_block.Stable.Latest.t )
        Multi_key_file_storage.Tag.Stable.Latest.t
    }
  [@@deriving bin_io_unversioned, fields]

  let to_yojson { state_hash; _ } =
    `Assoc [ ("state_hash", State_hash.to_yojson state_hash) ]

  let create ~block_tag ~state_hash ~scan_state ~pending_coinbase
      ~protocol_states_for_scan_state ~protocol_state =
    { state_hash
    ; protocol_states_for_scan_state
    ; scan_state
    ; pending_coinbase
    ; protocol_state
    ; block_tag
    }

  let scan_state t = t.scan_state

  let pending_coinbase t = t.pending_coinbase

  let block_tag t = t.block_tag

  let protocol_state t = t.protocol_state
end

module Minimal = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t =
        { state_hash : State_hash.Stable.V1.t; common : Common.Stable.V3.t }

      let to_latest = Fn.id
    end

    module V2 = struct
      type t =
        { state_hash : State_hash.Stable.V1.t; common : Common.Stable.V2.t }

      let to_latest { state_hash; common } =
        { V3.state_hash; common = Common.Stable.V2.to_latest common }
    end
  end]

  type t = Stable.Latest.t = { state_hash : State_hash.t; common : Common.t }
  [@@deriving fields]

  let common t = t.common

  let block_data_opt t = t.common.block_data_opt

  let upgrade t ~protocol_states_for_scan_state ~protocol_state ~block_tag =
    (* TODO: make common always contain block_data and then remove three last parameters of this function *)
    let protocol_states_for_scan_state =
      List.map protocol_states_for_scan_state ~f:(fun (state_hash, s) ->
          { With_hash.data = s
          ; hash =
              { Mina_base.State_hash.State_hashes.state_hash
              ; state_body_hash = None
              }
          } )
    in
    ignore
      ( Staged_ledger.Scan_state.check_required_protocol_states
          t.common.scan_state ~protocol_states:protocol_states_for_scan_state
        |> Or_error.ok_exn
        : Mina_state.Protocol_state.value State_hash.With_state_hashes.t list ) ;
    { Limited.state_hash = t.state_hash
    ; protocol_states_for_scan_state
    ; scan_state = t.common.scan_state
    ; pending_coinbase = t.common.pending_coinbase
    ; block_tag
    ; protocol_state
    }

  let create ~state_hash ~scan_state ~pending_coinbase ~block_tag
      ~protocol_state ~delta_block_chain_proof =
    let common =
      { Common.scan_state
      ; pending_coinbase
      ; block_data_opt =
          Some { block_tag; protocol_state; delta_block_chain_proof }
      }
    in
    { state_hash; common }

  let of_common ~state_hash common = { state_hash; common }

  let scan_state t = Common.scan_state t.common

  let pending_coinbase t = Common.pending_coinbase t.common
end

type t =
  { block_tag : Mina_block.Stable.Latest.t Mina_base.State_hash.File_storage.tag
  ; state_hash : State_hash.t
  ; protocol_state : Mina_state.Protocol_state.Value.t
  ; scan_state : Staged_ledger.Scan_state.t
  ; pending_coinbase : Pending_coinbase.t
  ; protocol_states_for_scan_state :
      Mina_state.Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
      list
  ; delta_block_chain_proof : State_hash.t Mina_stdlib.Nonempty_list.t
  }

let minimize
    { scan_state
    ; pending_coinbase
    ; protocol_states_for_scan_state = _
    ; block_tag
    ; state_hash
    ; delta_block_chain_proof
    ; protocol_state
    } =
  let common =
    Common.create ~scan_state ~pending_coinbase
      ~block_data_opt:
        (Some { block_tag; protocol_state; delta_block_chain_proof })
  in
  { Minimal.state_hash; common }

let limit
    { scan_state
    ; pending_coinbase
    ; protocol_states_for_scan_state
    ; block_tag
    ; state_hash
    ; delta_block_chain_proof = _
    ; protocol_state
    } =
  { Limited.block_tag
  ; protocol_state
  ; protocol_states_for_scan_state
  ; state_hash
  ; scan_state
  ; pending_coinbase
  }

let to_common
    { scan_state
    ; pending_coinbase
    ; block_tag
    ; protocol_state
    ; delta_block_chain_proof
    ; _
    } =
  Common.create ~scan_state ~pending_coinbase
    ~block_data_opt:(Some { block_tag; protocol_state; delta_block_chain_proof })
