open Core_kernel
open Mina_base

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      { protocol_state : Mina_state.Protocol_state.Value.Stable.V2.t
      ; block_tag :
          ( State_hash.Stable.V1.t
          , Mina_block.Stable.V2.t )
          Multi_key_file_storage.Tag.Stable.V1.t
      ; delta_block_chain_proof :
          State_hash.Stable.V1.t Mina_stdlib.Nonempty_list.Stable.V1.t
      }

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { protocol_state : Mina_state.Protocol_state.value
  ; block_tag : Mina_block.Stable.Latest.t Mina_base.State_hash.File_storage.tag
  ; delta_block_chain_proof : State_hash.t Mina_stdlib.Nonempty_list.t
  }

let validated_of_stable ~signature_kind ~proof_cache_db ~state_hash transition =
  let block =
    { With_hash.data = transition
    ; hash = { State_hash.State_hashes.state_hash; state_body_hash = None }
    }
  in
  let parent_hash =
    block |> With_hash.data |> Mina_block.Stable.Latest.header
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let cached_block =
    With_hash.map
      ~f:(Mina_block.write_all_proofs_to_disk ~signature_kind ~proof_cache_db)
      block
  in
  (* TODO: the delta transition chain proof is incorrect (same behavior the daemon used to have, but we should probably fix this?) *)
  Mina_block.Validated.unsafe_of_trusted_block
    ~delta_block_chain_proof:(Mina_stdlib.Nonempty_list.singleton parent_hash)
    (`This_block_is_trusted_to_be_safe cached_block)

module Staged_ledger_data = struct
  type t =
    Mina_ledger.Mask_maps.Stable.Latest.t
    * Staged_ledger.Scan_state.Application_data.t
end

module Full = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { header : Mina_block.Header.Stable.V2.t
        ; block_tag :
            ( State_hash.Stable.V1.t
            , Mina_block.Stable.V2.t )
            Multi_key_file_storage.Tag.Stable.V1.t
        ; delta_block_chain_proof :
            State_hash.Stable.V1.t Mina_stdlib.Nonempty_list.Stable.V1.t
        ; staged_ledger_data :
            Mina_ledger.Mask_maps.Stable.V1.t
            * Staged_ledger.Scan_state.Application_data.Stable.V1.t
              (* TODO consider removing the field, it's not used on lite breadcrumb *)
        ; accounts_created : Account_id.Stable.V2.t list
        ; staged_ledger_aux_and_pending_coinbases_cached :
            ( State_hash.Stable.V1.t
            , Network_types.Staged_ledger_aux_and_pending_coinbases.Data.Stable
              .V1
              .t )
            Multi_key_file_storage.Tag.Stable.V1.t
            option
        ; transaction_hashes_unordered :
            Mina_transaction.Transaction_hash.Stable.V1.t list
        ; command_stats : Command_stats.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  let read_block { Stable.Latest.block_tag; _ } =
    State_hash.File_storage.read (module Mina_block.Stable.Latest) block_tag

  let to_validated_block ~signature_kind ~proof_cache_db ~state_hash
      transition_data =
    read_block transition_data
    |> Or_error.map
         ~f:(validated_of_stable ~signature_kind ~proof_cache_db ~state_hash)
end
