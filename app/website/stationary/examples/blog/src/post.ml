open Core
open Stationary

type t =
  { date       : Date.t
  ; title      : string
  ; paragraphs : string list
  }
  [@@deriving sexp]

let to_html { date; title; paragraphs } =
  let open Html in
  node "div" []
    [ node "h2" [] [ text title ]
    ; node "h1" [] [ text (Date.format date "%B %e, %Y") ]
    ; node "div" []
        (List.map ~f:(fun p -> node "p" [] [ text p ])
           paragraphs)
    ]

let filename {title;_} =
  let s =
    String.map ~f:(fun c -> if c = ' ' then '-' else c) title
    |> String.filter ~f:(fun c ->
        Char.is_alphanum c
        || c = '-'
        || c = '_'
      )
  in
  s ^ ".html"

