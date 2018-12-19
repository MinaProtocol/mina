open Core
open Async
open Stationary_std_internal

type t =
  | Html of string * Html.t
  | Collect_output of { prog : string; args : string list; name : string }
  | Of_path of { path : string; name : string }

let of_html ~name html =
  validate_filename name;
  Html (name, html)

let of_path ?name path =
  let name =
    match name with
    | Some name -> name
    | None -> Filename.basename path
  in
  Of_path {path; name}

let collect_output ~name ~prog ~args =
  Collect_output {name; prog; args}
;;

let build t ~in_directory =
  match t with
  | Html (name, html) ->
    let%bind contents = Html.to_string html in
    Writer.save (in_directory ^/ name) ~contents:("<!DOCTYPE html>" ^ contents)
  | Of_path {name; path} ->
    Process.run_expect_no_output_exn ~prog:"cp"
      ~args:[ path; in_directory ^/ name ]
      ()
  | Collect_output {name; prog; args} ->
    Process.create ~prog ~args () >>= fun proc ->
    let proc = Or_error.ok_exn proc in
    Writer.open_file (in_directory ^/ name) >>= fun writer ->
    Reader.transfer (Process.stdout proc) (Writer.pipe writer)
;;
