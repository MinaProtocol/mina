open Core_kernel
open Async_kernel
open Network_peer
module Id = Libp2p_ipc.Subscription_id

type 'a t

type e = E : 'a t -> e

val id : 'a t -> Id.t

val topic : 'a t -> string

val subscribe :
     helper:Libp2p_helper.t
  -> topic:string
  -> encode:('a -> string)
  -> decode:(string -> 'a Or_error.t)
  -> on_decode_failure:
       [ `Ignore | `Call of string Envelope.Incoming.t -> Error.t -> unit ]
  -> validator:
       ('a Envelope.Incoming.t -> Validation_callback.t -> unit Deferred.t)
  -> 'a t Deferred.Or_error.t

val unsubscribe : helper:Libp2p_helper.t -> 'a t -> unit Deferred.Or_error.t

val handle_and_validate :
     'a t
  -> validation_expiration:Time_ns.t
  -> sender:Peer.t
  -> data:string
  -> [ `Validation_result of Libp2p_ipc.validation_result
     | `Validation_timeout
     | `Decoding_error of Error.t ]
     Deferred.t

val publish :
  logger:Logger.t -> helper:Libp2p_helper.t -> 'a t -> 'a -> unit Deferred.t

val publish_raw :
     logger:Logger.t
  -> helper:Libp2p_helper.t
  -> topic:string
  -> string
  -> unit Deferred.t
