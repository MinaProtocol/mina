open Core_kernel
open Mina_base
open Network_peer

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { node_ip_addr : Peer.Inet_addr.Stable.V1.t
      ; node_peer_id : Peer.Id.Stable.V1.t
            [@to_yojson fun peer_id -> `String peer_id]
            [@of_yojson
              function `String s -> Ok s | _ -> Error "expected string"]
      ; sync_status : Sync_status.Stable.V1.t
      ; peers : Peer.Stable.V1.t list
      ; block_producers : Signature_lib.Public_key.Compressed.Stable.V1.t list
      ; protocol_state_hash : State_hash.Stable.V1.t
      ; ban_statuses :
          (Peer.Stable.V1.t * Trust_system.Peer_status.Stable.V1.t) list
      ; k_block_hashes_and_timestamps :
          (State_hash.Stable.V1.t * Bounded_types.String.Stable.V1.t) list
      ; git_commit : Bounded_types.String.Stable.V1.t
      ; uptime_minutes : int
      ; block_height_opt : int option [@default None]
      }
    [@@deriving to_yojson, of_yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      { node_ip_addr : Peer.Inet_addr.Stable.V1.t
      ; node_peer_id : Peer.Id.Stable.V1.t
            [@to_yojson fun peer_id -> `String peer_id]
            [@of_yojson
              function `String s -> Ok s | _ -> Error "expected string"]
      ; sync_status : Sync_status.Stable.V1.t
      ; peers : Peer.Stable.V1.t list
      ; block_producers : Signature_lib.Public_key.Compressed.Stable.V1.t list
      ; protocol_state_hash : State_hash.Stable.V1.t
      ; ban_statuses :
          (Peer.Stable.V1.t * Trust_system.Peer_status.Stable.V1.t) list
      ; k_block_hashes_and_timestamps :
          (State_hash.Stable.V1.t * Bounded_types.String.Stable.V1.t) list
      ; git_commit : Bounded_types.String.Stable.V1.t
      ; uptime_minutes : int
      }
    [@@deriving to_yojson, of_yojson]

    let to_latest status : Latest.t =
      { node_ip_addr = status.node_ip_addr
      ; node_peer_id = status.node_peer_id
      ; sync_status = status.sync_status
      ; peers = status.peers
      ; block_producers = status.block_producers
      ; protocol_state_hash = status.protocol_state_hash
      ; ban_statuses = status.ban_statuses
      ; k_block_hashes_and_timestamps = status.k_block_hashes_and_timestamps
      ; git_commit = status.git_commit
      ; uptime_minutes = status.uptime_minutes
      ; block_height_opt = None
      }
  end
end]

type response = (t, Error.t) result

let response_to_yojson (response : response) : Yojson.Safe.t =
  match response with
  | Ok status ->
      to_yojson status
  | Error err ->
      `Assoc [ ("error", Error_json.error_to_yojson err) ]
