exception Not_initializing

(** Get the current instance of [Coda_lib] that plugins are being loaded for.

    This should be called during plugin initialization and stored in the plugin
    state. Calling this at any other time will raise a [Not_initializing]
    exception.
*)
val get_coda_lib : unit -> Coda_lib.t

(** Initialize plugins from the list of paths given.

    Plugin paths should normally end in [.cmxs].
    The [Coda_lib.t] argument is returned by [get_coda_lib] while
    initialization is in progress.
*)
val init_plugins : logger:Logger.t -> Coda_lib.t -> string list -> unit
