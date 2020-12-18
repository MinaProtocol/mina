exception Not_initializing

(** Get the current instance of [Mina_lib] that plugins are being loaded for.

    This should be called during plugin initialization and stored in the plugin
    state. Calling this at any other time will raise a [Not_initializing]
    exception.
*)
val get_mina_lib : unit -> Mina_lib.t

(** Initialize plugins from the list of paths given.

    Plugin paths should normally end in [.cmxs].
    The [Mina_lib.t] argument is returned by [get_mina_lib] while
    initialization is in progress.
*)
val init_plugins : logger:Logger.t -> Mina_lib.t -> string list -> unit
