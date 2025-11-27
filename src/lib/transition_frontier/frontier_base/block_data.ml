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
