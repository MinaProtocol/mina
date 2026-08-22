(** Thin, stateless daemon-side handle to the peer ban/trust machinery owned by
    the libp2p helper.

    The helper owns all ban state and logic (strike counts, expiry schedule,
    persistence, gating). The daemon only tells it "this peer misbehaved"
    ({!ban}), "this peer was useful" ({!useful}), or relays operator commands
    (manual ban/unban, trust/untrust), and can ask for the current lists. *)

open Async_kernel
open Network_peer

module Kind : sig
  type t = Peer_id | Ip [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
end

(** A banned or trusted entry, as reported by the helper. [until = None] means
    the entry is manual/indefinite (operator-authored, persisted by the
    helper); [Some t] is the expiry of an automatic ban. Trusted entries always
    have [until = None]. *)
module Entry : sig
  type t = { kind : Kind.t; identity : string; until : Core.Time.t option }
  [@@deriving sexp, equal, compare, yojson]
end

type t

(** Backend: the record of operations a concrete implementation provides. *)
type impl =
  { ban :
         manual:bool
      -> peer_id:Peer.Id.t
      -> ip:Core.Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; unban :
         peer_id:Peer.Id.t
      -> ip:Core.Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; bans : unit -> Entry.t list Deferred.Or_error.t
  ; trust :
         peer_id:Peer.Id.t
      -> ip:Core.Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; untrust :
         peer_id:Peer.Id.t
      -> ip:Core.Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; trusted : unit -> Entry.t list Deferred.Or_error.t
  ; useful : peer_id:Peer.Id.t -> unit
  }

(** A handle that does nothing: bans/trust are silently dropped, lists are
    empty. For tests and harnesses without a libp2p helper. *)
val null : t

(** A handle whose backend is installed later with {!bind} (the helper is
    spawned after most daemon components are configured). Until bound,
    mutations return an error, lists are empty, and [useful] is a no-op. *)
val create : unit -> t

(** Install the backend. No-op on {!null}; raises if a {!create}d handle was
    already bound. *)
val bind : t -> impl -> unit

(** Automatic ban of a misbehaving peer: the helper computes the ban duration
    from its own strike count for this peer. Fire-and-forget; failures are
    logged. *)
val ban :
     t
  -> logger:Logger.t
  -> ?reason:string
  -> ?metadata:(string * Yojson.Safe.t) list
  -> Peer.t
  -> unit

(** Manual (operator) ban: indefinite, persisted by the helper. *)
val ban_manual :
     t
  -> peer_id:Peer.Id.t
  -> ip:Core.Unix.Inet_addr.t option
  -> unit Deferred.Or_error.t

val unban :
     t
  -> peer_id:Peer.Id.t
  -> ip:Core.Unix.Inet_addr.t option
  -> unit Deferred.Or_error.t

val bans : t -> Entry.t list Deferred.Or_error.t

val trust :
     t
  -> peer_id:Peer.Id.t
  -> ip:Core.Unix.Inet_addr.t option
  -> unit Deferred.Or_error.t

val untrust :
     t
  -> peer_id:Peer.Id.t
  -> ip:Core.Unix.Inet_addr.t option
  -> unit Deferred.Or_error.t

val trusted : t -> Entry.t list Deferred.Or_error.t

(** Tell the helper this peer sent us useful data (keep-alive / DHT
    peer-protection signal). Fire-and-forget. *)
val useful : t -> Peer.Id.t -> unit

(** Like {!useful}, but for an envelope sender; [Local] senders are ignored. *)
val useful_sender : t -> Envelope.Sender.t -> unit

(** Like {!ban}, but for an envelope sender; [Local] senders are ignored. *)
val ban_sender :
     t
  -> logger:Logger.t
  -> ?reason:string
  -> ?metadata:(string * Yojson.Safe.t) list
  -> Envelope.Sender.t
  -> unit
