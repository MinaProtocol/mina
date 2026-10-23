(** Context type threaded through every resolver in [Mock_schema].

    The context is the persona only: no network, no runtime, no clock. *)

type t = Persona.t
