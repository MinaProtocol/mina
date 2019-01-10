open! Core

type t =
  | Local
  | Remote : _ Remote_executable.t -> t
