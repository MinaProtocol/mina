open Core
open Async
open Stationary
open Common

let title s =
  let open Html_concise in
  h1 [Style.just "f2"] [text s]

let author s =
  let open Html_concise in
  h4 [Style.just "f6 tracked ttu"] [text s]

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
  let s = month_day ^ " " ^ roman 2019 in
  let open Html_concise in
  h4 [Style.just "f6 tracked ttu o-50"] [text s]

let post name =
  let open Html_concise in
  let%map post = Post.load "posts/snarky.markdown" in
  div
    [Style.just "mw65 ibmplex f5 center lh-copy blueblack"]
    [title post.title; author post.author; date post.date; post.content]

let content name =
  let%map p = post name in
  wrap ~fixed_footer:false ~page_label:Links.(label blog) [(fun _ -> p)]
