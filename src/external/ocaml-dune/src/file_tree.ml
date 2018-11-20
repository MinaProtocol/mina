open! Stdune
open! Import

let standard_ignore_dirs =
  let open Re in
  [ empty
  ; seq [set "._"; rep any]
  ]
  |> alt
  |> Glob.of_re
  |> Predicate_lang.of_glob

module Dune_file = struct
  module Plain = struct
    type t =
      { path          : Path.t
      ; mutable sexps : Dune_lang.Ast.t list
      }
  end

  module Contents = struct
    type t =
      | Plain of Plain.t
      | Ocaml_script of Path.t
  end

  type t =
    { contents : Contents.t
    ; kind     : Dune_lang.Syntax.t
    }

  let path t =
    match t.contents with
    | Plain         x -> x.path
    | Ocaml_script  p -> p

  let extract_ignored_subdirs =
    let no_osl =
      let open Dune_lang.Decoder in
      plain_string (fun ~loc dn ->
        if Filename.dirname dn <> Filename.current_dir_name ||
           match dn with
           | "" | "." | ".." -> true
           | _ -> false
        then
          of_sexp_errorf loc "Invalid sub-directory name %S" dn
        else
          dn)
      |> list
      >>| (fun l -> Predicate_lang.of_string_set (String.Set.of_list l))
    in
    let osl = Predicate_lang.decode in
    let stanza =
      let open Dune_lang.Decoder in
      Syntax.get_exn Stanza.syntax >>= fun v ->
      let subdirs =
        if Syntax.Version.Infix.(v >= (1, 6)) then
          osl
        else
          no_osl
      in
      sum ["ignored_subdirs", subdirs]
    in
    fun ~project sexps ->
      let ignored_subdirs, sexps =
        List.partition_map sexps ~f:(fun sexp ->
          match (sexp : Dune_lang.Ast.t) with
          | List (_, (Atom (_, A "ignored_subdirs") :: _)) ->
            let stanza =
              Dune_project.set_parsing_context project stanza in
            Left (Dune_lang.Decoder.parse stanza Univ_map.empty sexp)
          | _ -> Right sexp)
      in
      let ignored_subdirs = Predicate_lang.union ignored_subdirs in
      (ignored_subdirs, sexps)

  let load file ~project ~kind =
    Io.with_lexbuf_from_file file ~f:(fun lb ->
      let contents, ignored_subdirs =
        if Dune_lexer.is_script lb then
          (Contents.Ocaml_script file, standard_ignore_dirs)
        else
          let sexps =
            Dune_lang.Parser.parse lb
              ~lexer:(Dune_lang.Lexer.of_syntax kind) ~mode:Many
          in
          let ignored_subdirs, sexps =
            extract_ignored_subdirs ~project sexps in
          (Plain { path = file; sexps }, ignored_subdirs)
      in
      ({ contents; kind }, ignored_subdirs))
end

let load_jbuild_ignore path =
  List.filteri (Io.lines_of_file path) ~f:(fun i fn ->
    if Filename.dirname fn = Filename.current_dir_name then
      true
    else begin
      Errors.(warn (Loc.of_pos
                      ( Path.to_string path
                      , i + 1, 0
                      , String.length fn
                      ))
                "subdirectory expression %s ignored" fn);
      false
    end)
  |> String.Set.of_list
  |> Predicate_lang.of_string_set

module Dir = struct
  type t =
    { path     : Path.t
    ; ignored  : bool
    ; contents : contents Lazy.t
    }

  and contents =
    { files     : String.Set.t
    ; sub_dirs  : t String.Map.t
    ; dune_file : Dune_file.t option
    ; project   : Dune_project.t
    }

  let contents t = Lazy.force t.contents

  let path t = t.path
  let ignored t = t.ignored

  let files     t = (contents t).files
  let sub_dirs  t = (contents t).sub_dirs
  let dune_file t = (contents t).dune_file
  let project   t = (contents t).project

  let file_paths t =
    Path.Set.of_string_set (files t) ~f:(Path.relative t.path)

  let sub_dir_names t =
    String.Map.foldi (sub_dirs t) ~init:String.Set.empty
      ~f:(fun s _ acc -> String.Set.add acc s)

  let sub_dir_paths t =
    String.Map.foldi (sub_dirs t) ~init:Path.Set.empty
      ~f:(fun s _ acc -> Path.Set.add acc (Path.relative t.path s))

  let rec fold t ~traverse_ignored_dirs ~init:acc ~f =
    if not traverse_ignored_dirs && t.ignored then
      acc
    else
      let acc = f t acc in
      String.Map.fold (sub_dirs t) ~init:acc ~f:(fun t acc ->
        fold t ~traverse_ignored_dirs ~init:acc ~f)
end

type t =
  { root : Dir.t
  ; dirs : (Path.t, Dir.t) Hashtbl.t
  }

let root t = t.root

module File = struct
  type t =
    { ino : int
    ; dev : int
    }

  let compare a b =
    match Int.compare a.ino b.ino with
    | Eq -> Int.compare a.dev b.dev
    | ne -> ne

  let dummy = { ino = 0; dev = 0 }

  let of_stats (st : Unix.stats) =
    { ino = st.st_ino
    ; dev = st.st_dev
    }
end

module File_map = Map.Make(File)

let is_temp_file fn =
  String.is_prefix fn ~prefix:".#"
  || String.is_suffix fn ~suffix:".swp"
  || String.is_suffix fn ~suffix:"~"

let load ?(extra_ignored_subtrees=Path.Set.empty) path =
  let rec walk path ~dirs_visited ~project ~ignored : Dir.t =
    let contents = lazy (
      let files, sub_dirs =
        Path.readdir_unsorted path
        |> List.filter_partition_map ~f:(fun fn ->
          let path = Path.relative path fn in
          if Path.is_in_build_dir path then
            Skip
          else begin
            let is_directory, file =
              match Unix.stat (Path.to_string path) with
              | exception _ -> (false, File.dummy)
              | { st_kind = S_DIR; _ } as st ->
                (true, File.of_stats st)
              | _ ->
                (false, File.dummy)
            in
            if is_directory then
              Right (fn, path, file)
            else if is_temp_file fn then
              Skip
            else
              Left fn
          end)
      in
      let files = String.Set.of_list files in
      let sub_dirs =
        List.sort
          ~compare:(fun (a, _, _) (b, _, _) -> String.compare a b)
          sub_dirs
      in
      let project, dune_file, ignored_subdirs =
        if ignored then
          (project, None, standard_ignore_dirs)
        else
          let project =
            Option.value (Dune_project.load ~dir:path ~files) ~default:project
          in
          let dune_file, ignored_subdirs =
            match List.filter ["dune"; "jbuild"] ~f:(String.Set.mem files) with
            | [] -> (None, standard_ignore_dirs )
            | [fn] ->
              if fn = "dune" then
                Dune_project.ensure_project_file_exists project;
              let dune_file, ignored_subdirs =
                Dune_file.load (Path.relative path fn)
                  ~project
                  ~kind:(Option.value_exn (Dune_lang.Syntax.of_basename fn))
              in
              (Some dune_file, ignored_subdirs)
            | _ ->
              die "Directory %s has both a 'dune' and 'jbuild' file.\n\
                   This is not allowed"
                (Path.to_string_maybe_quoted path)
          in
          let ignored_subdirs =
            if String.Set.mem files "jbuild-ignore" then
              Predicate_lang.union
                [ ignored_subdirs
                ; load_jbuild_ignore (Path.relative path "jbuild-ignore")
                ]
            else
              ignored_subdirs
          in
          (project, dune_file, ignored_subdirs)
      in
      let is_ignored =
        let ignored = lazy (
          lazy (List.map sub_dirs ~f:(fun (a, _, _) -> a))
          |> Predicate_lang.filter ignored_subdirs
               ~standard:standard_ignore_dirs
          |> String.Set.of_list
        ) in
        String.Set.mem (Lazy.force ignored)
      in
      let sub_dirs =
        List.fold_left sub_dirs ~init:String.Map.empty
          ~f:(fun acc (fn, path, file) ->
            let dirs_visited =
              if Sys.win32 then
                dirs_visited
              else
                match File_map.find dirs_visited file with
                | None -> File_map.add dirs_visited file path
                | Some first_path ->
                  die "Path %s has already been scanned. \
                       Cannot scan it again through symlink %s"
                    (Path.to_string_maybe_quoted first_path)
                    (Path.to_string_maybe_quoted path)
            in
            let ignored =
              ignored
              || is_ignored fn
              || Path.Set.mem extra_ignored_subtrees path
            in
            String.Map.add acc fn
              (walk path ~dirs_visited ~project ~ignored))
      in
      { Dir. files; sub_dirs; dune_file; project })
    in
    { path
    ; contents
    ; ignored
    }
  in
  let root =
    walk path
      ~dirs_visited:(File_map.singleton
                       (File.of_stats (Unix.stat (Path.to_string path)))
                       path)
      ~ignored:false
      ~project:(Lazy.force Dune_project.anonymous)
  in
  let dirs = Hashtbl.create 1024      in
  Hashtbl.add dirs Path.root root;
  { root; dirs }

let fold t ~traverse_ignored_dirs ~init ~f =
  Dir.fold t.root ~traverse_ignored_dirs ~init ~f

let rec find_dir t path =
  if not (Path.is_managed path) then
    None
  else
    match Hashtbl.find t.dirs path with
    | Some _ as res -> res
    | None ->
      match
        let open Option.O in
        Path.parent path
        >>= find_dir t
        >>= fun parent ->
        String.Map.find (Dir.sub_dirs parent) (Path.basename path)
      with
      | Some dir as res ->
        Hashtbl.add t.dirs path dir;
        res
      | None ->
        (* We don't cache failures in [t.dirs]. The expectation is
           that these only happen when the user writes an invalid path
           in a jbuild file, so there is no need to cache them. *)
        None

let files_of t path =
  match find_dir t path with
  | None -> Path.Set.empty
  | Some dir ->
    Path.Set.of_string_set (Dir.files dir) ~f:(Path.relative path)

let file_exists t path fn =
  match find_dir t path with
  | None -> false
  | Some dir -> String.Set.mem (Dir.files dir) fn

let dir_exists t path = Option.is_some (find_dir t path)

let exists t path =
  dir_exists t path ||
  file_exists t (Path.parent_exn path) (Path.basename path)

let files_recursively_in t ?(prefix_with=Path.root) path =
  match find_dir t path with
  | None -> Path.Set.empty
  | Some dir ->
    Dir.fold dir ~init:Path.Set.empty ~traverse_ignored_dirs:true
      ~f:(fun dir acc ->
        let path = Path.append prefix_with (Dir.path dir) in
        String.Set.fold (Dir.files dir) ~init:acc ~f:(fun fn acc ->
          Path.Set.add acc (Path.relative path fn)))
