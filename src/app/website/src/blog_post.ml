open Core
open Async
open Stationary
open Common

let title s =
  let open Html_concise in
  h1 [Style.just "f1 ddinexp tracked-tightish mb2"] [text s]

let author s =
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu metropolis mt0 mb0"]
    [text ("by " ^ s)]

let roman n =
  let symbols =
    [ (1000, "M")
    ; (900, "CM")
    ; (500, "D")
    ; (400, "CD")
    ; (100, "C")
    ; (90, "XC")
    ; (50, "L")
    ; (40, "XL")
    ; (10, "X")
    ; (9, "IX")
    ; (5, "V")
    ; (4, "IV")
    ; (1, "I") ]
  in
  List.fold symbols ~init:([], n) ~f:(fun (acc, n) (base, name) ->
      let q, r = (n / base, n mod base) in
      (List.init q ~f:(Fn.const name) @ acc, r) )
  |> fst |> List.rev |> String.concat

let date d =
  let month_day = Date.format d "%B %d" in
  let year = Date.year d in
  let s = month_day ^ " " ^ roman year in
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu o-50 metropolis mt0 mb35"]
    [text s]

let post name =
  let open Html_concise in
  let%map post = Post.load ("posts/" ^ name) in
  div
    [Style.just "mw65 ibmplex f5 center lh-copy blueblack"]
    [ title post.title
    ; author post.author
    ; date post.date
    ; div [Stationary.Attribute.class_ "blog-content"] [post.content] ]

let content name =
  let%map p = post name in
  wrap
    ~headers:
      [ Html.literal
          {html|<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.css" integrity="sha384-9eLZqc9ds8eNjO3TmqPeYcDj8n+Qfa4nuSiGYa6DjLNcv9BtN69ZIulL9+8CqC9Y" crossorigin="anonymous">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.js" integrity="sha384-K3vbOmF2BtaVai+Qk37uypf7VrgBubhQreNQe9aGsz9lB63dIFiQVlJbr92dw2Lx" crossorigin="anonymous"></script>|html}
      ; Html.literal
          {html|<link rel="stylesheet" href="/static/css/blog.css">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/contrib/auto-render.min.js" integrity="sha384-kmZOZB5ObwgQnS/DuDg6TScgOiWWBiVt0plIRkZCmE6rDZGrEOQeHM5PcHi+nyqe" crossorigin="anonymous"
    onload="renderMathInElement(document.body);"></script>|html}
      ]
    ~fixed_footer:false
    ~page_label:Links.(label blog)
    [(fun _ -> p)]
