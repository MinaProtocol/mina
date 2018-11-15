open Stdune
open Dune_file

type t =
  | Standalone of
      (File_tree.Dir.t * Super_context.Dir_with_dune.t option) option
  (* Directory not part of a multi-directory group. The argument is
     [None] for directory that are not from the source tree, such as
     generated ones. *)

  | Group_root of File_tree.Dir.t
                  * Super_context.Dir_with_dune.t
  (* Directory with [(include_subdirs x)] where [x] is not [no] *)

  | Is_component_of_a_group_but_not_the_root of
      Super_context.Dir_with_dune.t option
  (* Sub-directory of a [Group_root _] *)

let is_standalone = function
  | Standalone _ -> true
  | _ -> false

let cache = Hashtbl.create 32

let get_include_subdirs stanzas =
  List.fold_left stanzas ~init:None ~f:(fun acc stanza ->
    match stanza with
    | Include_subdirs (loc, x) ->
      if Option.is_some acc then
        Errors.fail loc "The 'include_subdirs' stanza cannot appear \
                         more than once";
      Some x
    | _ -> acc)

let check_no_module_consumer stanzas =
  List.iter stanzas ~f:(fun stanza ->
    match stanza with
    | Library { buildable; _} | Executables { buildable; _ }
    | Tests { exes = { buildable; _ }; _ } ->
      Errors.fail buildable.loc
        "This stanza is not allowed in a sub-directory of directory with \
         (include_subdirs unqualified).\n\
         Hint: add (include_subdirs no) to this file."
    | _ -> ())

let rec get sctx ~dir =
  match Hashtbl.find cache dir with
  | Some t -> t
  | None ->
    let t =
      match
        Option.bind (Path.drop_build_context dir)
          ~f:(File_tree.find_dir (Super_context.file_tree sctx))
      with
      | None -> begin
          match Path.parent dir with
          | None -> Standalone None
          | Some dir ->
            if is_standalone (get sctx ~dir) then
              Standalone None
            else
              Is_component_of_a_group_but_not_the_root None
        end
      | Some ft_dir ->
        let project_root =
          File_tree.Dir.project ft_dir
          |> Dune_project.root
          |> Path.of_local in
        match Super_context.stanzas_in sctx ~dir with
        | None ->
          if Path.equal dir project_root ||
             is_standalone (get sctx ~dir:(Path.parent_exn dir)) then
            Standalone (Some (ft_dir, None))
          else
            Is_component_of_a_group_but_not_the_root None
        | Some d ->
          match get_include_subdirs d.stanzas with
          | Some Unqualified ->
            Group_root (ft_dir, d)
          | Some No ->
            Standalone (Some (ft_dir, Some d))
          | None ->
            if dir <> project_root &&
               not (is_standalone (get sctx ~dir:(Path.parent_exn dir)))
            then begin
              check_no_module_consumer d.stanzas;
              Is_component_of_a_group_but_not_the_root (Some d)
            end else
              Standalone (Some (ft_dir, Some d))
    in
    Hashtbl.add cache dir t;
    t

let get_assuming_parent_is_part_of_group sctx ~dir ft_dir =
  match Hashtbl.find cache (File_tree.Dir.path ft_dir) with
  | Some t -> t
  | None ->
    let t =
      match Super_context.stanzas_in sctx ~dir with
      | None -> Is_component_of_a_group_but_not_the_root None
      | Some d ->
        match get_include_subdirs d.stanzas with
        | Some Unqualified ->
          Group_root (ft_dir, d)
        | Some No ->
          Standalone (Some (ft_dir, Some d))
        | None ->
          check_no_module_consumer d.stanzas;
          Is_component_of_a_group_but_not_the_root (Some d)
    in
    Hashtbl.add cache dir t;
    t

let clear_cache () =
  Hashtbl.reset cache
