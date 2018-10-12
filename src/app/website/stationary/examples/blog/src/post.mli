open Core
open Stationary

type t =
  { date       : Date.t
  ; title      : string
  ; paragraphs : string list
  }
  [@@deriving sexp]

val to_html : t -> Html.t

val filename : t -> string
