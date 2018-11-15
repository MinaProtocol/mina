let path_sep =
  if Sys.win32 then
    ';'
  else
    ':'

let parse_path ?(sep=path_sep) s =
  String.split s ~on:sep
  |> List.filter_map ~f:(function
    | "" -> None
    | p -> Some (Path.of_filename_relative_to_initial_cwd p))

let cons_path p ~_PATH =
  let p = Path.to_absolute_filename p in
  match _PATH with
  | None -> p
  | Some s -> Printf.sprintf "%s%c%s" p path_sep s

let exe = if Sys.win32 then ".exe" else ""

let best_prog dir prog =
  let fn = Path.relative dir (prog ^ ".opt" ^ exe) in
  if Path.exists fn then
    Some fn
  else
    let fn = Path.relative dir (prog ^ exe) in
    if Path.exists fn then
      Some fn
    else
      None

let which ~path prog =
  let rec search = function
    | [] -> None
    | dir :: rest ->
      match best_prog dir prog with
      | None -> search rest
      | Some fn -> Some fn
  in
  search path

let make ~path =
  match which ~path "gmake" with
  | None -> which ~path "make"
  | some -> some
