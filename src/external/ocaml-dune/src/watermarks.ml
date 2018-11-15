open! Stdune
open Import
open Fiber.O

let is_a_source_file fn =
  match Filename.extension fn with
  | ".flv"
  | ".gif"
  | ".ico"
  | ".jpeg"
  | ".jpg"
  | ".mov"
  | ".mp3"
  | ".mp4"
  | ".otf"
  | ".pdf"
  | ".png"
  | ".ttf"
  | ".woff" -> false
  | _ -> true

let make_watermark_map ~name ~version ~commit =
  let opam_file = Opam_file.load (Path.in_source (name ^ ".opam")) in
  let version_num =
    Option.value ~default:version (String.drop_prefix version ~prefix:"v") in
  let opam_var name sep =
    match Opam_file.get_field opam_file name with
    | None -> Error (sprintf "variable %S not found in opam file" name)
    | Some value ->
      let err = Error (sprintf "invalid value for variable %S in opam file" name) in
      match value with
      | String (_, s) -> Ok s
      | List (_, l) -> begin
          match
            List.fold_left l ~init:(Ok []) ~f:(fun acc v ->
              match acc with
              | Error _ -> acc
              | Ok l ->
                match v with
                | OpamParserTypes.String (_, s) -> Ok (s :: l)
                | _ -> err)
          with
          | Error _ as e -> e
          | Ok l -> Ok (String.concat ~sep (List.rev l))
        end
      | _ -> err
  in
  String.Map.of_list_exn
    [ "NAME"           , Ok name
    ; "VERSION"        , Ok version
    ; "VERSION_NUM"    , Ok version_num
    ; "VCS_COMMIT_ID"  , Ok commit
    ; "PKG_MAINTAINER" , opam_var "maintainer"  ", "
    ; "PKG_AUTHORS"    , opam_var "authors"     ", "
    ; "PKG_HOMEPAGE"   , opam_var "homepage"    " "
    ; "PKG_ISSUES"     , opam_var "bug-reports" " "
    ; "PKG_DOC"        , opam_var "doc"         " "
    ; "PKG_LICENSE"    , opam_var "license"     ", "
    ; "PKG_REPO"       , opam_var "dev-repo"    " "
    ]

let subst_string s path ~map =
  let len = String.length s in
  let longest_var = String.longest (String.Map.keys map) in
  let double_percent_len = String.length "%%" in
  let loc_of_offset ~ofs ~len =
    let rec loop lnum bol i =
      if i = ofs then
        let pos =
          { Lexing.
            pos_fname = Path.to_string path
          ; pos_cnum  = i
          ; pos_lnum  = lnum
          ; pos_bol   = bol
          }
        in
        { Loc.start = pos; stop  = { pos with pos_cnum = pos.pos_cnum + len } }
      else
        match s.[i] with
        | '\n' -> loop (lnum + 1) (i + 1) (i + 1)
        | _    -> loop lnum bol (i + 1)
    in
    loop 1 0 0
  in
  let rec loop i acc =
    if i = len then
      acc
    else
      match s.[i] with
      | '%' -> after_percent (i + 1) acc
      | _ -> loop (i + 1) acc
  and after_percent i acc =
    if i = len then
      acc
    else
      match s.[i] with
      | '%' -> after_double_percent ~start:(i - 1) (i + 1) acc
      | _ -> loop (i + 1) acc
  and after_double_percent ~start i acc =
    if i = len then
      acc
    else
      match s.[i] with
      | '%' -> after_double_percent ~start:(i - 1) (i + 1) acc
      | 'A'..'Z' | '_' -> in_var ~start (i + 1) acc
      | _ -> loop (i + 1) acc
  and in_var ~start i acc =
    if i - start > longest_var + double_percent_len then
      loop i acc
    else if i = len then
      acc
    else
      match s.[i] with
      | '%' -> end_of_var ~start (i + 1) acc
      | 'A'..'Z' | '_' -> in_var ~start (i + 1) acc
      | _ -> loop (i + 1) acc
  and end_of_var ~start i acc =
    if i = len then
      acc
    else
      match s.[i] with
      | '%' -> begin
          let var = String.sub s ~pos:(start + 2) ~len:(i - start - 3) in
          match String.Map.find map var with
          | None -> in_var ~start:(i - 1) (i + 1) acc
          | Some (Ok repl) ->
            let acc = (start, i + 1, repl) :: acc in
            loop (i + 1) acc
          | Some (Error msg) ->
            let loc = loc_of_offset ~ofs:start ~len:(i + 1 - start) in
            Errors.fail loc "%s" msg
        end
      | _ -> loop (i + 1) acc
  in
  match List.rev (loop 0 []) with
  | [] -> None
  | repls ->
    let result_len =
      List.fold_left repls ~init:(String.length s) ~f:(fun acc (a, b, repl) ->
        acc - (b - a) + String.length repl)
    in
    let buf = Buffer.create result_len in
    let pos =
      List.fold_left repls ~init:0 ~f:(fun pos (a, b, repl) ->
        Buffer.add_substring buf s pos (a - pos);
        Buffer.add_string buf repl;
        b)
    in
    Buffer.add_substring buf s pos (len - pos);
    Some (Buffer.contents buf)

let subst_file path ~map =
  let s = Io.read_file path in
  let s =
    if Path.is_root path
    && String.is_suffix (Path.to_string path) ~suffix:".opam" then
      "version: \"%%" ^ "VERSION_NUM" ^ "%%\"\n" ^ s
    else
      s
  in
  match subst_string s ~map path with
  | None -> ()
  | Some s -> Io.write_file path s

let read_project_name () =
  Dune_project.read_name (Path.in_source Dune_project.filename)

let get_name ~files ?name () =
  let package_names =
    List.filter_map files ~f:(fun fn ->
      if Filename.dirname fn = "." then
        match Filename.split_extension fn with
        | s, ".opam" -> Some s
        | _ -> None
      else
        None)
  in
  if package_names = [] then
    die "@{<error>Error@}: no <package>.opam files found.";
  let name =
    match Which_program.t with
    | Dune -> begin
        assert (Option.is_none name);
        if not (List.mem ~set:files Dune_project.filename) then
          die "@{<error>Error@}: There is no dune-project file in the current \
               directory, please add one with a (name <name>) field in it.\n\
               Hint: dune subst must be executed from the root of the project.";
        match read_project_name () with
        | None ->
          die "@{<error>Error@}: The project name is not defined, please add \
               a (name <name>) field to your dune-project file."
        | Some name -> name
      end
    | Jbuilder ->
      match name with
      | Some name -> name
      | None ->
        match
          if List.mem ~set:files Dune_project.filename then
            read_project_name ()
          else
            None
        with
        | Some name -> name
        | None ->
          let name =
            let prefix = String.longest_prefix package_names in
            if prefix = "" then
              None
            else
              match String.drop_suffix prefix ~suffix:"-"
                  , String.drop_suffix prefix ~suffix:"_" with
              | Some _, Some _ -> assert false
              | None, None ->
                Option.some_if (List.mem ~set:package_names prefix) prefix
              | (Some _ as p), None
              | None, (Some _ as p) -> p
          in
          match name with
          | Some name -> name
          | None ->
            die "@{<error>Error@}: cannot determine name automatically.\n\
                 You must pass a [--name] command line argument."
  in
  if not (List.mem name ~set:package_names) then
    die "@{<error>Error@}: file %s.opam doesn't exist." name;
  name

let subst_git ?name () =
  let rev = "HEAD" in
  let git =
    match Bin.which ~path:(Env.path Env.initial) "git" with
    | Some x -> x
    | None -> Utils.program_not_found "git" ~loc:None
  in
  let env = Env.initial in
  Fiber.fork_and_join
    (fun () ->
       Fiber.fork_and_join
         (fun () ->
            Process.run_capture Strict git ["describe"; "--always"; "--dirty"]
              ~env)
         (fun () ->
            Process.run_capture Strict git ["rev-parse"; rev]
              ~env))
    (fun () ->
       Process.run_capture_lines Strict git ["ls-tree"; "-r"; "--name-only"; rev]
         ~env)
  >>= fun ((version, commit), files) ->
  let version = String.trim version in
  let commit  = String.trim commit  in
  let name = get_name ~files ?name () in
  let watermarks = make_watermark_map ~name ~version ~commit in
  List.iter files ~f:(fun fn ->
    if is_a_source_file fn then
      subst_file (Path.in_source fn) ~map:watermarks);
  Fiber.return ()

let subst ?name () =
  if Sys.file_exists ".git" then
    subst_git ?name ()
  else
    Fiber.return ()
