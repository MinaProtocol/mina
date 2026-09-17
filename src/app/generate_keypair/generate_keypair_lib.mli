(** Entrypoint for the [mina-generate-keypair] applet.

    [run ()] is the whole of the old executable body, including the [version] /
    [-version] special case on [Sys.get_argv]. *)
val run : unit -> unit
