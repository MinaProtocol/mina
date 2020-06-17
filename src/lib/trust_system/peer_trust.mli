(** Module handling peer "trust" scores. Trust scores are initialized at 0,
    bounded between -1 and +1, increase when peers do good things, and decrease
    when they do bad things. If a peer's trust becomes <= -1, or takes an action
    that causes an instant ban, it gets banned. This module tracks, stores and
    updates trust, and notifies the rest of the system when a peer is banned. It
    does *not* specify specific things that cause trust to change, or how much,
    or actually do anything when a peer should be banned. That's the
    responsibility of the caller, which is Trust_system. *)

open Async
open Core
open Pipe_lib

(** What we do in response to some trust-affecting action. *)
module Trust_response : sig
  type t =
    | Insta_ban  (** Ban the peer immediately *)
    | Trust_increase of float  (** Increase trust by the specified amount. *)
    | Trust_decrease of float  (** Decrease trust by the specified amount. *)
end

(** Interface for trust-affecting actions. *)
module type Action_intf = sig
  (** The type of trust-affecting actions. For the log messages to be
      grammatical, the constructors should be past tense verbs. *)
  type t

  val to_trust_response : t -> Trust_response.t

  (** Convert an action into a format string and a set of metadata for
      logging *)
  val to_log : t -> string * (string, Yojson.Safe.t) List.Assoc.t
end

(** Trust increment that sets a maximum rate of doing a bad thing (presuming the
    peer does no good things) in actions/second. *)
val max_rate : float -> float

(* FIXME The parameter docs don't render :( *)

(** Instantiate the module.
    @param Action Actions that affect trust *)
module Make (Action : Action_intf) : sig
  type t

  (** Set up the trust system. Pass the directory to store the trust database
      in. *)
  val create : string -> t

  (** Get a fake trust system, for tests. *)
  val null : unit -> t

  (** Get the pipe of ban events. The purpose of this is to allow us to
      proactively disconnect from peers when they're banned. You *must* consume
      this, otherwise the program will block indefinitely when a peer is
      banned. *)
  val ban_pipe :
    t -> (Unix.Inet_addr.Blocking_sexp.t * Time.t) Strict_pipe.Reader.t

  (** Record an action a peer took. This may result in a ban event being
      emitted *)
  val record :
       t
    -> Logger.t
    -> Unix.Inet_addr.Blocking_sexp.t
    -> Action.t
    -> unit Deferred.t

  (** Look up the score of a peer and whether it's banned .*)
  val lookup : t -> Unix.Inet_addr.Blocking_sexp.t -> Peer_status.t

  (** reset peer status; return the reset status *)
  val reset : t -> Unix.Inet_addr.Blocking_sexp.t -> Peer_status.t

  (** get all peer, status pairs in the trust system *)
  val peer_statuses :
    t -> (Unix.Inet_addr.Blocking_sexp.t * Peer_status.t) list

  (** Shut down. *)
  val close : t -> unit

  module For_tests : sig
    (** Get a pipe of the actions being recorded. Close it when you're done to
        avoid a memory leak. *)
    val get_action_pipe :
      t -> (Action.t * Unix.Inet_addr.Blocking_sexp.t) Pipe.Reader.t
  end
end
