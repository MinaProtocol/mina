(** Watermarking *)

(** Expand watermarks in source files, similarly to what topkg does.

    This is only used when a package is pinned. *)

val subst : ?name:string -> unit -> unit Fiber.t
