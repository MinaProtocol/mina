open Core

type t = Unbanned | Banned_until of Time.t
