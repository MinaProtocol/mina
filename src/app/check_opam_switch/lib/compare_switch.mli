(** Compares the [opam_export_path] argument with the current switch.
    We check that packages from the [installed] section, and the overlays (which look like inlined .opam files) are present in the current switch. *)
val compare_with_current_switch : string -> unit
