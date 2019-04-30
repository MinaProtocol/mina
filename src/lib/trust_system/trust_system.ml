(** The trust system, instantiated with Coda-specific stuff. *)
open Core

open Async

module Actions = struct
  type action =
    | Sent_bad_hash
        (** Peer sent us some data that doesn't hash to the expected value *)
    | Violated_protocol  (** Peer violated the specification of the protocol *)
    | Made_request
        (** Peer made a valid request. This causes a small decrease to mitigate
            DoS. *)
    | Connected
        (** Peer connected to TCP server. Very small decrease to mitigate DoS *)
    | Requested_unknown_item
        (** Peer requested something we don't know. They might be ahead of us or
          they might be malicious. *)
    | Fulfilled_request  (** Peer fulfilled a request we made. *)
    | Epoch_ledger_provided  (** Special case of request fulfillment *)
  [@@deriving show]

  (** The action they took, paired with a message and associated JSON metadata
      for logging. *)
  type t = action * (string * (string, Yojson.Safe.json) List.Assoc.t) option

  let to_trust_response (action, _) =
    let open Peer_trust.Trust_response in
    (* FIXME figure out a good value for this *)
    let fulfilled_increment = Peer_trust.max_rate 10. in
    (* the summed decreases of a connection and request equals
       the increase of a fulfilled request *)
    let request_increment = 0.90 *. fulfilled_increment in
    let connected_increment = 0.10 *. fulfilled_increment in
    let epoch_ledger_provided_increment = 10. *. fulfilled_increment in
    match action with
    | Sent_bad_hash ->
        Insta_ban
    | Violated_protocol ->
        Insta_ban
    | Made_request ->
        Trust_decrease request_increment
    | Connected ->
        Trust_decrease connected_increment
    | Requested_unknown_item ->
        Trust_decrease (Peer_trust.max_rate 1.)
    | Fulfilled_request ->
        Trust_increase fulfilled_increment
    | Epoch_ledger_provided ->
        Trust_increase epoch_ledger_provided_increment

  let to_log : t -> string * (string, Yojson.Safe.json) List.Assoc.t =
   fun (action, extra_opt) ->
    match extra_opt with
    | None ->
        (show_action action, [])
    | Some (fmt, metadata) ->
        (sprintf !"%s (%s)" (show_action action) fmt, metadata)
end

module Banned_status = Banned_status
module Peer_status = Peer_status
module Peer_trust = Peer_trust.Make (Actions)
include Peer_trust

let record_envelope_sender :
    t -> Logger.t -> Envelope.Sender.t -> Actions.t -> unit Deferred.t =
 fun t logger sender action ->
  match sender with
  | Local ->
      let action_fmt, action_metadata = Actions.to_log action in
      Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:action_metadata
        "Attempted to record trust action of ourselves: %s" action_fmt ;
      Deferred.unit
  | Remote inet_addr ->
      record t logger inet_addr action
