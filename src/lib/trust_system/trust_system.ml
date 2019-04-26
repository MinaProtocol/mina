[%%import
"../../config.mlh"]

(** The trust system, instantiated with Coda-specific stuff. *)
open Core

open Async

[%%if
consensus_mechanism = "proof_of_stake"]

[%%inject
"delta_int", delta]

let delta = float_of_int delta_int

[%%else]

let delta = 1.0

[%%endif]

module Actions = struct
  type action =
    | Gossiped_old_transition of int64
        (** Peer gossiped a transition which was too old. Includes time before cutoff period in which the transition was received, expressed in slots. *)
    | Gossiped_future_transition
        (** Peer gossiped a transition before its slot. *)
    | Gossiped_invalid_transition
        (** Peer gossiped an invalid transition to us. *)
    | Disconnected_chain
        (** Peer has been determined to be on a chain that is not connected to our chain. *)
    | Sent_bad_hash
        (** Peer sent us some data that doesn't hash to the expected value. *)
    | Violated_protocol
        (** Peer violated the specification of the protocol. *)
    | Made_request
        (** Peer made a valid request. This causes a small decrease to mitigate
            DoS. *)
    | Requested_unknown_item
        (** Peer requested something we don't know. They might be ahead of us or
          they might be malicious. *)
    | Fulfilled_request  (** Peer fulfilled a request we made. *)
  [@@deriving show]

  (** The action they took, paired with a message and associated JSON metadata
      for logging. *)
  type t = action * (string * (string, Yojson.Safe.json) List.Assoc.t) option

  let to_trust_response (action, _) =
    let open Peer_trust.Trust_response in
    (* FIXME figure out a good value for this *)
    let request_increment = Peer_trust.max_rate 10. in
    match action with
    | Gossiped_old_transition slot_diff ->
        (* We want to decrease the score exponentially based on how out of date the transition
         * we received was. We would like the base score decrease to be some constant
         * [c], and we would like to instantly ban any peers who send us transitions
         * received more than [Δ] slots out of date. Therefore, we want some function
         * [f] where [f(1) = c] and [f(Δ) >= 2]. We start by fitting an exponential function
         * such that [f(Δ) = 2]. [(1/y)x^2] should be [2] when [x] is [Δ], so if we solve for
         * [(1/y)Δ^2 = 2], we get [y = Δ^2/2]. Therefore, we can define our function
         * [f(x) = (1/(Δ^2/2))x^2]. This does not satisfy [f(1) = c], but since we only constrain
         * [f(Δ) >= 2], we can just offset the function by [c] in order to satisfy both constraints,
         * giving us [f(x) = (1/(Δ^2/2))x^2].
         *)
        let c = 0.1 in
        let y = (delta ** 2.0) /. 2.0 in
        let f x = (1.0 /. y *. (x ** 2.0)) +. c in
        Trust_decrease (f (Int64.to_float slot_diff))
    | Gossiped_future_transition ->
        Insta_ban
    | Gossiped_invalid_transition ->
        Insta_ban
    | Disconnected_chain ->
        Insta_ban
    | Sent_bad_hash ->
        Insta_ban
    | Violated_protocol ->
        Insta_ban
    | Made_request ->
        Trust_decrease request_increment
    | Requested_unknown_item ->
        Trust_decrease (Peer_trust.max_rate 1.)
    | Fulfilled_request ->
        (* trade 1:1 *) Trust_increase request_increment

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
  | Remote peer ->
      record t logger peer action
