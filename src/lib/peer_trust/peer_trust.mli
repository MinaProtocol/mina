(** Module handling peer "trust" scores. Trust scores are initialized at 0,
    bounded between -1 and +1, increase when peers do good things, and decrease
    when they do bad things. If a peer's trust becomes <= -1, or takes an action
    that causes an instant ban, it gets banned. This module tracks, stores and
    updates trust, and notifies the rest of the system when a peer is banned. It
    does *not* specify specific things that cause trust to change, or how much,
    or actually do anything when a peer should be banned. That's the
    responsibility of the caller, which is coda_base. *)

open Core
open Async
open Pipe_lib

(** What we do in response to some trust-affecting action. *)
module Trust_response : sig
  type t =
    | Insta_ban  (** Ban the peer immediately *)
    | Trust_increase of float  (** Increase trust by the specified amount. *)
    | Trust_decrease of float  (** Decrease trust by the specified amount. *)
end

module Banned_status : module type of Banned_status

module Peer_status : module type of Peer_status

(** Interface for trust-affecting actions. *)
module type Action_intf = sig
  (** The type of trust-affecting actions. For the log messages to be
      grammatical, the constructors should be past tense verbs. *)
  type t [@@deriving sexp_of]

  val to_trust_response : t -> Trust_response.t
end

val max_rate : float -> float
(** Trust increment that sets a maximum rate of doing a bad thing (presuming the
    peer does no good things) in actions/second. *)

(* TODO consider deduplicating somehow, maybe with an intf.ml, or by getting rid
   of this definition entirely. *)

(** An instantiated peer trust module *)
module type S = sig
  type t

  (** The data identifying a peer. *)
  type peer

  (** Some action a peer took that affects trust. *)
  type action

  val create : db_dir:string -> t
  (** Set up the trust system. Pass the directory to store the trust database
      in. *)

  val ban_pipe : t -> peer Strict_pipe.Reader.t
  (** Get the pipe of ban events. The purpose of this is to allow us to
      proactively disconnect from peers when they're banned. You *must* consume
      this, otherwise the program will block indefinitely when a peer is
      banned. *)

  val record : t -> Logger.t -> peer -> action -> unit Deferred.t
  (** Record an action a peer took. This may result in a ban event being
      emitted *)

  val lookup : t -> peer -> Peer_status.t
  (** Look up the score of a peer and whether it's banned .*)

  val close : t -> unit
  (** Shut down. *)
end
(* FIXME The parameter docs don't render :( *)

(** Instantiate the module.
    @param Action Actions that affect trust *)
module Make (Action : Action_intf) :
  S
  with type peer := Unix.Inet_addr.Blocking_sexp.t
   and type action := Action.t
