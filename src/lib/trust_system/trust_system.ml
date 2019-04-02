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
    | Requested_unknown_item
        (** Peer requested something we don't know. They might be ahead of us or
          they might be malicious. *)
  [@@deriving show]

  (** The action they took, paired with a message and associated JSON metadata
      for logging. *)
  type t = action * (string * (string, Yojson.Safe.json) List.Assoc.t) option

  let to_trust_response (action, _) =
    let open Peer_trust.Trust_response in
    match action with
    | Sent_bad_hash -> Insta_ban
    | Violated_protocol -> Insta_ban
    (* FIXME figure out a good value for this *)
    | Made_request -> Trust_decrease (Peer_trust.max_rate 10.)
    | Requested_unknown_item -> Trust_decrease (Peer_trust.max_rate 1.)

  let to_log : t -> string * (string, Yojson.Safe.json) List.Assoc.t =
   fun (action, extra_opt) ->
    match extra_opt with
    | None -> (show_action action, [])
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
  | Remote {host; _} -> record t logger host action
