open! Stdune
open Import

type t =
  { project : Dune_project.t
  ; db      : Lib.DB.t
  ; root    : Path.t (* Path inside the build directory *)
  }

let root t = t.root
let name t = Dune_project.name t.project
let project t = t.project
let libs t = t.db

module DB = struct
  type scope = t

  module Project_name_map = Map.Make(Dune_project.Name)

  type t =
    { by_dir  : (Path.t, scope) Hashtbl.t
    ; by_name : scope Project_name_map.t
    ; context : string
    }

  let find_by_dir t dir =
    let rec loop d =
      match Hashtbl.find t.by_dir d with
      | Some scope -> scope
      | None ->
        if Path.is_root d || not (Path.is_managed d) then
          Exn.code_error "Scope.DB.find_by_dir got an invalid path"
            [ "dir"    , Path.to_sexp dir
            ; "context", Sexp.Encoder.string t.context
            ];
        match Path.parent d with
        | None ->
          Exn.code_error "find_by_dir: invalid directory"
            [ "d", Path.to_sexp d
            ; "dir", Path.to_sexp dir
            ]
        | Some d ->
          let scope = loop d in
          Hashtbl.add t.by_dir d scope;
          scope
    in
    loop dir

  let find_by_name t name =
    match Project_name_map.find t.by_name name with
    | Some x -> x
    | None ->
      Exn.code_error "Scope.DB.find_by_name"
        [ "name"   , Dune_project.Name.to_sexp name
        ; "context", Sexp.Encoder.string t.context
        ; "names",
          Sexp.Encoder.(list Dune_project.Name.to_sexp)
            (Project_name_map.keys t.by_name)
        ]

  let create ~projects ~context ~installed_libs ~ext_lib ~ext_obj
        internal_libs =
    let projects_by_name =
      List.map projects ~f:(fun (project : Dune_project.t) ->
        (Dune_project.name project, project))
      |> Project_name_map.of_list
      |> function
      | Ok x -> x
      | Error (_name, project1, project2) ->
        let to_sexp (project : Dune_project.t) =
          Sexp.Encoder.(pair Dune_project.Name.to_sexp Path.Local.to_sexp)
            (Dune_project.name project, Dune_project.root project)
        in
        Exn.code_error "Scope.DB.create got two projects with the same name"
          [ "project1", to_sexp project1
          ; "project2", to_sexp project2
          ]
    in
    let libs_by_project_name =
      List.map internal_libs ~f:(fun (dir, (lib : Dune_file.Library.t)) ->
        (Dune_project.name lib.project, (dir, lib)))
      |> Project_name_map.of_list_multi
    in
    let by_name_cell = ref Project_name_map.empty in
    let public_libs =
      let public_libs =
        List.filter_map internal_libs ~f:(fun (_dir, lib) ->
          Option.map lib.public ~f:(fun p ->
            (Dune_file.Public_lib.name p, lib.project)))
        |> Lib_name.Map.of_list
        |> function
        | Ok x -> x
        | Error (name, _, _) ->
          match
            List.filter_map internal_libs ~f:(fun (_dir, lib) ->
              Option.bind lib.public ~f:(fun p ->
                Option.some_if (name = Dune_file.Public_lib.name p)
                  lib.buildable.loc))
          with
          | [] | [_] -> assert false
          | loc1 :: loc2 :: _ ->
            die "Public library %a is defined twice:\n\
                 - %s\n\
                 - %s"
              Lib_name.pp_quoted name
              (Loc.to_file_colon_line loc1)
              (Loc.to_file_colon_line loc2)
      in
      Lib.DB.create ()
        ~parent:installed_libs
        ~resolve:(fun name ->
          match Lib_name.Map.find public_libs name with
          | None -> Not_found
          | Some project ->
            let scope =
              Option.value_exn
                (Project_name_map.find !by_name_cell (Dune_project.name project))
            in
            Redirect (Some scope.db, name))
        ~all:(fun () -> Lib_name.Map.keys public_libs)
    in
    let by_name =
      let build_context_dir = Path.relative Path.build_dir context in
      Project_name_map.merge projects_by_name libs_by_project_name
        ~f:(fun _name project libs ->
          let project = Option.value_exn project in
          let libs = Option.value libs ~default:[] in
          let db =
            Lib.DB.create_from_library_stanzas libs ~parent:public_libs ~ext_lib
              ~ext_obj
          in
          let root =
            Path.append_local build_context_dir (Dune_project.root project) in
          Some { project; db; root })
    in
    by_name_cell := by_name;
    let by_dir = Hashtbl.create 1024 in
    Project_name_map.iter by_name ~f:(fun scope ->
      Hashtbl.add by_dir scope.root scope);
    ({ by_name; by_dir; context }, public_libs)
end
