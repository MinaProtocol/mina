(** Context type threaded through every resolver in [Mock_schema].

    For the v0.1 mock the context is just the persona — no network, no
    runtime, no clock. Future versions might thread mutable state for
    e.g. tracking which mutations were called in a session. *)

type t = Persona.t
