open Stdune

let die = Dune.Import.die

type t =
  { name : string
  ; recursive : bool
  ; dir : Path.t
  ; contexts : Dune.Context.t list
  }

let to_log_string { name ; recursive; dir ; contexts = _ } =
  sprintf "- %s alias %s%s/%s"
    (if recursive then "recursive " else "")
    (if recursive then "@@" else "@")
    (Path.to_string_maybe_quoted dir)
    name

let in_dir ~name ~recursive ~contexts dir =
  Util.check_path contexts dir;
  match Path.extract_build_context dir with
  | None ->
    { dir
    ; recursive
    ; name
    ; contexts
    }
  | Some ("install", _) ->
    die "Invalid alias: %s.\n\
         There are no aliases in %s."
      (Path.to_string_maybe_quoted Path.(relative build_dir "install"))
      (Path.to_string_maybe_quoted dir)
  | Some (ctx, dir) ->
    { dir
    ; recursive
    ; name
    ; contexts =
        [List.find_exn contexts ~f:(fun c -> Dune.Context.name c = ctx)]
    }

let of_string common s ~contexts =
  if not (String.is_prefix s ~prefix:"@") then
    None
  else
    let pos, recursive =
      if String.length s >= 2 && s.[1] = '@' then
        (2, false)
      else
        (1, true)
    in
    let s = String.drop s pos in
    let path = Path.relative Path.root (Common.prefix_target common s) in
    if Path.is_root path then
      die "@@ on the command line must be followed by a valid alias name"
    else if not (Path.is_managed path) then
      die "@@ on the command line must be followed by a relative path"
    else
      let dir = Path.parent_exn path in
      let name = Path.basename path in
      Some (in_dir ~name ~recursive ~contexts dir)
