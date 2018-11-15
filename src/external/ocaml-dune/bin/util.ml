open! Stdune
open Dune
open Import

let check_path contexts =
  let contexts =
    String.Set.of_list (List.map contexts ~f:(fun c -> c.Context.name))
  in
  fun path ->
    let internal path =
      die "This path is internal to dune: %s"
        (Path.to_string_maybe_quoted path)
    in
    if Path.is_in_build_dir path then
      match Path.extract_build_context path with
      | None -> internal path
      | Some (name, _) ->
        if name = "" || name.[0] = '.' then internal path;
        if not (name = "install" || String.Set.mem contexts name) then
          die "%s refers to unknown build context: %s%s"
            (Path.to_string_maybe_quoted path)
            name
            (hint name (String.Set.to_list contexts))

let find_root () =
  let cwd = Sys.getcwd () in
  let rec loop counter ~candidates ~to_cwd dir =
    let files = Sys.readdir dir |> Array.to_list |> String.Set.of_list in
    if String.Set.mem files Workspace.filename then
      cont counter ~candidates:((0, dir, to_cwd) :: candidates) dir ~to_cwd
    else if Which_program.t = Jbuilder && String.Set.exists files ~f:(fun fn ->
      String.is_prefix fn ~prefix:"jbuild-workspace") then
      cont counter ~candidates:((1, dir, to_cwd) :: candidates) dir ~to_cwd
    else if String.Set.mem files Dune_project.filename then
      cont counter ~candidates:((2, dir, to_cwd) :: candidates) dir ~to_cwd
    else
      cont counter ~candidates dir ~to_cwd
  and cont counter ~candidates ~to_cwd dir =
    if counter > String.length cwd then
      candidates
    else
      let parent = Filename.dirname dir in
      if parent = dir then
        candidates
      else
        let base = Filename.basename dir in
        loop (counter + 1) parent ~candidates ~to_cwd:(base :: to_cwd)
  in
  match loop 0 ~candidates:[] ~to_cwd:[] cwd with
  | [] -> (cwd, [])
  | l ->
    let lowest_priority =
      List.fold_left l ~init:max_int ~f:(fun acc (prio, _, _) ->
        min acc prio)
    in
    let (_, dir, to_cwd) =
      List.find_exn l ~f:(fun (prio, _, _) -> prio = lowest_priority)
    in
    (dir, to_cwd)
