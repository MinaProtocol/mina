(** Fallback values shared by every Rosetta CLI.

    Every CLI built on this library connects to the same server with the
    same network_identifier, so the values they fall back to when a flag
    is omitted are defined once, here, rather than once per binary.
    {!Http.create} uses them as its optional-argument defaults, and
    {!Flags} as the last step of its flag/environment/fallback chain. *)

(** Base URL of a Rosetta server running next to the daemon
    ([http://localhost:3087]). *)
val base_uri : string

(** [network_identifier.blockchain] for every Mina network ([mina]). *)
val blockchain : string

(** [network_identifier.network] ([testnet]). *)
val network : string

(** Seconds allowed for one request/response exchange with the Rosetta
    server, from sending the request to reading the last byte of the
    response body.  Sized for a readiness probe; an interactive CLI
    should pick a longer one. *)
val http_timeout : float
