#!/usr/bin/env utop
#require "core"
open Core

let rec filter_bin ls ~f =
  match ls with
  | [] -> []
  | [x] -> failwith "error: filter_bin on a single element string"
  | x :: y :: [] ->
      if f x y then [y] else []
  | x :: (y :: _ as t) ->
      if f x y then
        y :: filter_bin t ~f
      else
        filter_bin t ~f

let () =
  In_channel.(input_lines stdin)
  |> List.map ~f:Float.of_string
  |> filter_bin ~f:(>)
  |> List.iter ~f:(fun n -> print_endline (Float.to_string n))
