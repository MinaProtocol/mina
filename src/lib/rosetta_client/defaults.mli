(** Fallback values shared by every Rosetta CLI.

    Both [rosetta-client] and [rosetta-healthcheck] connect to the same
    server with the same network_identifier, so the values they fall back
    to when a flag is omitted are defined once, here, rather than once per
    binary.  {!Http.create} uses the same values as its optional-argument
    defaults.

    Each value has an environment-variable override, so an operator who
    always talks to the same server can export it once instead of
    repeating flags on every invocation.  A flag, when given, always wins
    over the environment variable.

    {ul
    {- [MINA_ROSETTA_URI] — base URL of the Rosetta server.}
    {- [MINA_ROSETTA_BLOCKCHAIN] — [network_identifier.blockchain].}
    {- [MINA_ROSETTA_NETWORK] — [network_identifier.network].}} *)

(** Name of the environment variable that overrides {!base_uri}. *)
val uri_env_var : string

(** Name of the environment variable that overrides {!blockchain}. *)
val blockchain_env_var : string

(** Name of the environment variable that overrides {!network}. *)
val network_env_var : string

(** Base URL of a Rosetta server running next to the daemon
    ([http://localhost:3087]). *)
val base_uri : string

(** [network_identifier.blockchain] for every Mina network ([mina]). *)
val blockchain : string

(** [network_identifier.network] ([testnet]). *)
val network : string

(** Seconds allowed for one request/response exchange with the Rosetta
    server, from sending the request to reading the last byte of the
    response body. *)
val http_timeout : float

(** [base_uri_from_env ()] is [$MINA_ROSETTA_URI] when that variable is
    set, and {!base_uri} otherwise. *)
val base_uri_from_env : unit -> string

(** [blockchain_from_env ()] is [$MINA_ROSETTA_BLOCKCHAIN] when that
    variable is set, and {!blockchain} otherwise. *)
val blockchain_from_env : unit -> string

(** [network_from_env ()] is [$MINA_ROSETTA_NETWORK] when that variable
    is set, and {!network} otherwise. *)
val network_from_env : unit -> string
