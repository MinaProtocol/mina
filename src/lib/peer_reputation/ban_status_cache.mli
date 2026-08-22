(** Daemon-side mirror of the helper's ban lists.

    Two tables ([banned_peers], [banned_ips]) rebuilt wholesale from
    {!Handle.bans} on every poll. There is no logic here: the helper
    bounds and expires entries; this cache only presents them (node status,
    the [banned_peers] gauge, GraphQL). *)

open Async_kernel
open Network_peer

(** Wire/presentation snapshot: the identities currently banned. Expiry is
    deliberately not carried; use {!until_of_peer}/{!until_of_ip}. *)
module Snapshot : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        { banned_peers : Peer.Id.Stable.V1.t list
        ; banned_ips : Peer.Inet_addr.Stable.V1.t list
        }
      [@@deriving sexp, to_yojson, of_yojson]
    end
  end]

  val empty : t
end

type t

val create : logger:Logger.t -> Handle.t -> t

(** Rebuild the tables from [Handle.bans] once. *)
val refresh : t -> unit Deferred.t

(** Start polling every [interval] (default 30s), refreshing immediately. *)
val start : ?interval:Core.Time.Span.t -> t -> unit

(** Replace the tables from a list of entries (no RPC). Exposed for tests. *)
val set_entries : t -> Handle.Entry.t list -> unit

val snapshot : t -> Snapshot.t

val is_banned_peer : t -> Peer.Id.t -> bool

val is_banned_ip : t -> Core.Unix.Inet_addr.t -> bool

val is_banned :
  t -> peer_id:Peer.Id.t -> ip:Core.Unix.Inet_addr.t option -> bool

(** Expiry of an automatic ban; [None] if not banned or banned
    indefinitely (manual). *)
val until_of_peer : t -> Peer.Id.t -> Core.Time.t option

val until_of_ip : t -> Core.Unix.Inet_addr.t -> Core.Time.t option

(** Current bans as entries ([until] = [None] for manual/indefinite). *)
val entries : t -> Handle.Entry.t list
