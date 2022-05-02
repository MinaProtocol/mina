open Core
open Async_kernel
open Network_peer
module Id = Libp2p_ipc.Subscription_id

type 'a t =
  { topic : string
  ; id : Id.t
  ; mutable closed : bool
  ; logger_metadata : 'a -> (string * Yojson.Safe.t) list
  ; validator :
      'a Envelope.Incoming.t -> Validation_callback.t -> unit Deferred.t
  ; encode : 'a -> string
  ; on_decode_failure :
      [ `Ignore | `Call of string Envelope.Incoming.t -> Error.t -> unit ]
  ; decode : string -> 'a Or_error.t
  }

type e = E : 'a t -> e

let id { id; _ } = id

let topic { topic; _ } = topic

let subscribe ~helper ~topic ~logger_metadata ~encode ~decode ~on_decode_failure
    ~validator =
  let open Deferred.Or_error.Let_syntax in
  let subscription_id = Id.create () in
  let%map _ =
    Libp2p_helper.do_rpc helper
      (module Libp2p_ipc.Rpcs.Subscribe)
      (Libp2p_ipc.Rpcs.Subscribe.create_request ~topic ~subscription_id)
  in
  { topic
  ; id = subscription_id
  ; closed = false
  ; logger_metadata
  ; encode
  ; on_decode_failure
  ; decode
  ; validator
  }

let unsubscribe ~helper sub =
  let open Deferred.Or_error.Let_syntax in
  if not sub.closed then
    let%map _ =
      Libp2p_helper.do_rpc helper
        (module Libp2p_ipc.Rpcs.Unsubscribe)
        (Libp2p_ipc.Rpcs.Unsubscribe.create_request ~subscription_id:sub.id)
    in
    sub.closed <- true
  else Deferred.Or_error.error_string "already unsubscribed"

let handle_and_validate sub ~validation_expiration ~(sender : Peer.t)
    ~data:raw_data =
  let open Libp2p_ipc.Reader.ValidationResult in
  let wrap_message data =
    if
      Unix.Inet_addr.equal sender.host (Unix.Inet_addr.of_string "127.0.0.1")
      && Int.equal sender.libp2p_port 0
    then Envelope.Incoming.local data
    else Envelope.Incoming.wrap_peer ~sender ~data
  in
  match sub.decode raw_data with
  | Ok data -> (
      let validation_callback =
        Validation_callback.create validation_expiration
      in
      let%bind () = sub.validator (wrap_message data) validation_callback in
      match%map Validation_callback.await validation_callback with
      | Some `Accept ->
          `Validation_result Accept
      | Some `Reject ->
          `Validation_result Reject
      | Some `Ignore ->
          `Validation_result Ignore
      | None ->
          `Validation_timeout (sub.logger_metadata data) )
  | Error e ->
      ( match sub.on_decode_failure with
      | `Ignore ->
          ()
      | `Call f ->
          f (wrap_message raw_data) e ) ;
      Mina_metrics.(Counter.inc_one Network.gossip_messages_failed_to_decode) ;
      return (`Decoding_error e)

let publish_raw ~logger ~helper ~topic data =
  match%map
    Libp2p_helper.do_rpc helper
      (module Libp2p_ipc.Rpcs.Publish)
      (Libp2p_ipc.Rpcs.Publish.create_request ~topic ~data)
  with
  | Ok _ ->
      ()
  | Error e ->
      [%log' error logger] "error while publishing message on $topic: $err"
        ~metadata:
          [ ("topic", `String topic); ("err", Error_json.error_to_yojson e) ]

let publish ~logger ~helper { topic; encode; _ } message =
  publish_raw ~logger ~helper ~topic (encode message)
