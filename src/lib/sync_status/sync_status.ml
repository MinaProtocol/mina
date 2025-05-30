open Core_kernel

(** Sync_status represent states interacting with peers in the Mina protocol.
    When the protocol is starting, the node should be in the CONNECT state
    trying to connect to a peer. Once it connects to a peer, the node should be
    in the LISTENING state waiting for peers to send a message to them. When
    the node receives a constant flow of messages, its state should be SYNCED.
    However, when the node is bootstrapping, its state is BOOTSTRAPPING. If it
    hasn’t received messages for some time (see [Mina_lib.offline_time]), then
    it is OFFLINE.
*)
let to_string = function
  | `Connecting ->
      "Connecting"
  | `Listening ->
      "Listening"
  | `Offline ->
      "Offline"
  | `Bootstrap ->
      "Bootstrap"
  | `Synced ->
      "Synced"
  | `Catchup ->
      "Catchup"

let of_string string =
  match String.lowercase string with
  | "connecting" ->
      Ok `Connecting
  | "listening" ->
      Ok `Listening
  | "offline" ->
      Ok `Offline
  | "bootstrap" ->
      Ok `Bootstrap
  | "synced" ->
      Ok `Synced
  | "catchup" ->
      Ok `Catchup
  | status ->
      Error (Error.createf !"%s is not a valid status" status)

let to_yojson status = `String (to_string status)

let of_yojson : Yojson.Safe.t -> (_, string) Result.t = function
  | `String s ->
      Result.map_error ~f:Error.to_string_hum (of_string s)
  | _ ->
      Error "expected string"

module T = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        [ `Connecting | `Listening | `Offline | `Bootstrap | `Synced | `Catchup ]
      [@@deriving sexp, hash, compare, equal, enumerate]

      let to_latest = Fn.id

      let to_yojson = to_yojson

      let of_yojson = of_yojson

      module T = struct
        type typ = t [@@deriving sexp, hash, compare, equal, enumerate]

        type t = typ [@@deriving sexp, hash, compare, equal, enumerate]
      end

      include Hashable.Make (T)
    end
  end]
end

include T
include Hashable.Make (T)
