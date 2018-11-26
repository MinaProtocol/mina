open Stdune

module Context = Dune.Context
module Build = Dune.Build
module Build_system = Dune.Build_system
module Log = Dune.Log

let die = Dune.Import.die
let hint = Dune.Import.hint

type t =
  | File      of Path.t
  | Alias     of Alias.t

type resolve_input =
  | Path of Path.t
  | String of string

let request (setup : Dune.Main.setup) targets =
  let open Build.O in
  List.fold_left targets ~init:(Build.return ()) ~f:(fun acc target ->
    acc >>>
    match target with
    | File path -> Build.path path
    | Alias { Alias. name; recursive; dir; contexts } ->
      let contexts = List.map ~f:Dune.Context.name contexts in
      (if recursive then
         Build_system.Alias.dep_rec_multi_contexts
       else
         Build_system.Alias.dep_multi_contexts)
        ~dir ~name ~file_tree:setup.file_tree ~contexts)

let log_targets ~log targets =
  List.iter targets ~f:(function
    | File path ->
      Log.info log @@ "- " ^ (Path.to_string path)
    | Alias a -> Log.info log (Alias.to_log_string a));
  flush stdout

let target_hint (setup : Dune.Main.setup) path =
  assert (Path.is_managed path);
  let sub_dir = Option.value ~default:path (Path.parent path) in
  let candidates = Build_system.all_targets setup.build_system in
  let candidates =
    if Path.is_in_build_dir path then
      candidates
    else
      List.map candidates ~f:(fun path ->
        match Path.extract_build_context path with
        | None -> path
        | Some (_, path) -> path)
  in
  let candidates =
    (* Only suggest hints for the basename, otherwise it's slow when there are
       lots of files *)
    List.filter_map candidates ~f:(fun path ->
      if Path.equal (Path.parent_exn path) sub_dir then
        Some (Path.to_string path)
      else
        None)
  in
  let candidates = String.Set.of_list candidates |> String.Set.to_list in
  hint (Path.to_string path) candidates

let resolve_path path ~(setup : Dune.Main.setup) =
  Util.check_path setup.contexts path;
  let can't_build path =
    Error (path, target_hint setup path);
  in
  if Dune.File_tree.dir_exists setup.file_tree path then
    Ok [ Alias (Alias.in_dir ~name:"default" ~recursive:true
                  ~contexts:setup.contexts path) ]
  else if not (Path.is_managed path) then
    Ok [File path]
  else if Path.is_in_build_dir path then begin
    if Build_system.is_target setup.build_system path then
      Ok [File path]
    else
      can't_build path
  end else
    match
      List.filter_map setup.contexts ~f:(fun ctx ->
        let path = Path.append ctx.Context.build_dir path in
        if Build_system.is_target setup.build_system path then
          Some (File path)
        else
          None)
    with
    | [] -> can't_build path
    | l  -> Ok l

let resolve_target common ~(setup : Dune.Main.setup) s =
  match Alias.of_string common s ~contexts:setup.contexts with
  | Some a -> Ok [Alias a]
  | None ->
    let path = Path.relative Path.root (Common.prefix_target common s) in
    resolve_path path ~setup

let resolve_targets_mixed ~log common (setup : Dune.Main.setup) user_targets =
  match user_targets with
  | [] -> []
  | _ ->
    let targets =
      List.map user_targets ~f:(function
        | String s -> resolve_target common ~setup s
        | Path p -> resolve_path p ~setup) in
    if common.config.display = Verbose then begin
      Log.info log "Actual targets:";
      List.concat_map targets ~f:(function
        | Ok targets -> targets
        | Error _ -> [])
      |> log_targets ~log
    end;
    targets

let resolve_targets ~log common (setup : Dune.Main.setup) user_targets =
  List.map ~f:(fun s -> String s) user_targets
  |> resolve_targets_mixed ~log common setup

let resolve_targets_exn ~log common setup user_targets =
  resolve_targets ~log common setup user_targets
  |> List.concat_map ~f:(function
    | Error (path, hint) ->
      die "Don't know how to build %a%s" Path.pp path hint
    | Ok targets ->
      targets)
