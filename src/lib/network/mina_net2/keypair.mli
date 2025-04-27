open Async
open Core
open Network_peer

[%%versioned:
module Stable : sig
  module V1 : sig
    type t
  end
end]

(** Securely generate a new keypair. *)
val generate_random : Libp2p_helper.t -> t Deferred.t

(** Formats this keypair to a comma-separated list of public key, secret key, and peer_id. *)
val to_string : t -> string

(** Undo [to_string t].

    Only fails if the string has the wrong format, not if the embedded
    keypair data is corrupt. *)
val of_string : string -> t Or_error.t

val to_peer_id : t -> Peer.Id.t

val secret : t -> string
