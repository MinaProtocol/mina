(** This library is internal to dune and guarantees no API stability. *)

module Bytes    = Bytes
module Filename = Filename
module String   = String
module Char     = Char
module Result   = Result
module Hashtbl  = MoreLabels.Hashtbl
module Lexing   = Lexing

type ('a, 'error) result = ('a, 'error) Result.t =
  | Ok    of 'a
  | Error of 'error
