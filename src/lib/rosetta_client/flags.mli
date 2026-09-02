(** Command-line flags shared by every Rosetta CLI.

    A binary built on this library asks for {!client} and gets the whole
    connection surface -- [--rosetta-uri], [--blockchain], [--network]
    and a timeout -- already turned into an {!Http.t}.  It does not see
    the environment variables or the fallback values at all, so two
    binaries cannot document the same flag differently or drift apart on
    what it defaults to.

    Each flag falls back to its environment variable and then to
    {!Defaults}; a flag given on the command line always wins, and a
    variable that is set but blank counts as unset.

    {ul
    {- [MINA_ROSETTA_URI] — base URL of the Rosetta server.}
    {- [MINA_ROSETTA_BLOCKCHAIN] — [network_identifier.blockchain].}
    {- [MINA_ROSETTA_NETWORK] — [network_identifier.network].}} *)

(** [timeout ~default] is [--timeout SECONDS], the seconds allowed for
    one request/response exchange.  Binaries differ on what a sensible
    wait is -- a readiness probe wants a quick verdict, an interactive
    query does not -- so the default is the caller's to pick. *)
val timeout : default:float -> float Command.Param.t

(** [client ~timeout] is the connection flags, assembled into a client.
    Pass {!timeout} to let the user set the timeout, or
    [Command.Param.return t] to fix it. *)
val client : timeout:float Command.Param.t -> Http.t Command.Param.t
