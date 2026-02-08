(** Mina manifest system.

    Inspired by the Tezos/Octez manifest
    (https://gitlab.com/tezos/tezos/-/tree/master/manifest).

    Generates dune files from centralized OCaml declarations. *)

open Dune_s_expr

module Ppx = struct
  type t = string list

  let minimal = [ "ppx_version" ]

  let standard = [ "ppx_version"; "ppx_jane" ]

  let mina = [ "ppx_mina"; "ppx_version"; "ppx_jane" ]

  let mina_rich =
    [ "ppx_mina"
    ; "ppx_version"
    ; "ppx_jane"
    ; "ppx_deriving.std"
    ; "ppx_deriving_yojson"
    ]

  let snarky = [ "ppx_jane"; "ppx_deriving.eq" ]

  let custom ppxes = ppxes

  let extend preset extras = preset @ extras
end

type dep_kind = Opam | Local | Submodule

type dep = { name : string; kind : dep_kind }

let opam name = { name; kind = Opam }

let local name = { name; kind = Local }

let submodule name = { name; kind = Submodule }

type library_target =
  { l_public_name : string option
  ; l_internal_name : string
  ; l_path : string
  ; l_synopsis : string option
  ; l_deps : dep list
  ; l_ppx : Ppx.t option
  ; l_kind : string option
  ; l_inline_tests : bool
  ; l_inline_tests_bare : bool
  ; l_inline_tests_deps : string list
  ; l_bisect_sigterm : bool
  ; l_no_instrumentation : bool
  ; l_modes : string list
  ; l_flags : Dune_s_expr.t list
  ; l_library_flags : string list
  ; l_modules : string list
  ; l_modules_exclude : string list
  ; l_modules_without_implementation : string list
  ; l_virtual_modules : string list
  ; l_default_implementation : string option
  ; l_implements : string option
  ; l_foreign_stubs : (string * string list) option
  ; l_c_library_flags : string list
  ; l_preprocessor_deps : string list
  ; l_ppx_runtime_libraries : string list
  ; l_wrapped : bool option
  ; l_enabled_if : string option
  ; l_js_of_ocaml : Dune_s_expr.t option
  ; l_opam_deps : string list
  ; l_extra_stanzas : Dune_s_expr.t list
  }

type executable_target =
  { e_public_name : string option
  ; e_internal_name : string
  ; e_package : string option
  ; e_path : string
  ; e_deps : dep list
  ; e_ppx : Ppx.t option
  ; e_modules : string list
  ; e_modes : string list
  ; e_flags : Dune_s_expr.t list
  ; e_link_flags : string list
  ; e_bisect_sigterm : bool
  ; e_no_instrumentation : bool
  ; e_forbidden_libraries : string list
  ; e_preprocessor_deps : string list
  ; e_enabled_if : string option
  ; e_opam_deps : string list
  ; e_extra_stanzas : Dune_s_expr.t list
  }

type test_target =
  { t_internal_name : string
  ; t_package : string option
  ; t_path : string
  ; t_deps : dep list
  ; t_ppx : Ppx.t option
  ; t_modules : string list
  ; t_flags : Dune_s_expr.t list
  ; t_file_deps : string list
  ; t_enabled_if : string option
  ; t_no_instrumentation : bool
  ; t_extra_stanzas : Dune_s_expr.t list
  }

type target =
  | Library of library_target
  | Executable of executable_target
  | Test of test_target
  | File_stanzas of string * Dune_s_expr.t list

let targets : target list ref = ref []

let reset () = targets := []

let opt condition sexpr = if condition then [ sexpr ] else []

let opt_some o f = match o with Some v -> [ f v ] | None -> []

let derive_internal_name s =
  String.map (fun c -> if c = '.' || c = '-' then '_' else c) s

let library ?internal_name ?(path = "") ?synopsis ?(deps = []) ?ppx ?kind
    ?(inline_tests = false) ?(inline_tests_bare = false)
    ?(inline_tests_deps = []) ?(bisect_sigterm = false)
    ?(no_instrumentation = false) ?(modes = []) ?(flags = [])
    ?(library_flags = []) ?(modules = []) ?(modules_exclude = [])
    ?(modules_without_implementation = []) ?(virtual_modules = [])
    ?default_implementation ?implements ?foreign_stubs ?(c_library_flags = [])
    ?(preprocessor_deps = []) ?(ppx_runtime_libraries = []) ?wrapped ?enabled_if
    ?js_of_ocaml ?(opam_deps = []) ?(extra_stanzas = []) public_name =
  let iname =
    match internal_name with
    | Some n ->
        n
    | None ->
        derive_internal_name public_name
  in
  let t =
    Library
      { l_public_name = Some public_name
      ; l_internal_name = iname
      ; l_path = path
      ; l_synopsis = synopsis
      ; l_deps = deps
      ; l_ppx = ppx
      ; l_kind = kind
      ; l_inline_tests = inline_tests
      ; l_inline_tests_bare = inline_tests_bare
      ; l_inline_tests_deps = inline_tests_deps
      ; l_bisect_sigterm = bisect_sigterm
      ; l_no_instrumentation = no_instrumentation
      ; l_modes = modes
      ; l_flags = flags
      ; l_library_flags = library_flags
      ; l_modules = modules
      ; l_modules_exclude = modules_exclude
      ; l_modules_without_implementation = modules_without_implementation
      ; l_virtual_modules = virtual_modules
      ; l_default_implementation = default_implementation
      ; l_implements = implements
      ; l_foreign_stubs = foreign_stubs
      ; l_c_library_flags = c_library_flags
      ; l_preprocessor_deps = preprocessor_deps
      ; l_ppx_runtime_libraries = ppx_runtime_libraries
      ; l_wrapped = wrapped
      ; l_enabled_if = enabled_if
      ; l_js_of_ocaml = js_of_ocaml
      ; l_opam_deps = opam_deps
      ; l_extra_stanzas = extra_stanzas
      }
  in
  targets := t :: !targets ;
  local public_name

let private_library ?(path = "") ?synopsis ?(deps = []) ?ppx ?kind
    ?(inline_tests = false) ?(inline_tests_bare = false)
    ?(inline_tests_deps = []) ?(bisect_sigterm = false)
    ?(no_instrumentation = false) ?(modes = []) ?(flags = [])
    ?(library_flags = []) ?(modules = []) ?(modules_exclude = [])
    ?(modules_without_implementation = []) ?(virtual_modules = [])
    ?default_implementation ?implements ?foreign_stubs ?(c_library_flags = [])
    ?(preprocessor_deps = []) ?(ppx_runtime_libraries = []) ?wrapped ?enabled_if
    ?js_of_ocaml ?(opam_deps = []) ?(extra_stanzas = []) name =
  let t =
    Library
      { l_public_name = None
      ; l_internal_name = name
      ; l_path = path
      ; l_synopsis = synopsis
      ; l_deps = deps
      ; l_ppx = ppx
      ; l_kind = kind
      ; l_inline_tests = inline_tests
      ; l_inline_tests_bare = inline_tests_bare
      ; l_inline_tests_deps = inline_tests_deps
      ; l_bisect_sigterm = bisect_sigterm
      ; l_no_instrumentation = no_instrumentation
      ; l_modes = modes
      ; l_flags = flags
      ; l_library_flags = library_flags
      ; l_modules = modules
      ; l_modules_exclude = modules_exclude
      ; l_modules_without_implementation = modules_without_implementation
      ; l_virtual_modules = virtual_modules
      ; l_default_implementation = default_implementation
      ; l_implements = implements
      ; l_foreign_stubs = foreign_stubs
      ; l_c_library_flags = c_library_flags
      ; l_preprocessor_deps = preprocessor_deps
      ; l_ppx_runtime_libraries = ppx_runtime_libraries
      ; l_wrapped = wrapped
      ; l_enabled_if = enabled_if
      ; l_js_of_ocaml = js_of_ocaml
      ; l_opam_deps = opam_deps
      ; l_extra_stanzas = extra_stanzas
      }
  in
  targets := t :: !targets ;
  local name

let executable ?package ?internal_name ?(path = "") ?(deps = []) ?ppx
    ?(modules = []) ?(modes = []) ?(flags = []) ?(link_flags = [])
    ?(bisect_sigterm = false) ?(no_instrumentation = false)
    ?(forbidden_libraries = []) ?(preprocessor_deps = []) ?enabled_if
    ?(opam_deps = []) ?(extra_stanzas = []) public_name =
  let iname =
    match internal_name with
    | Some n ->
        n
    | None ->
        derive_internal_name public_name
  in
  let t =
    Executable
      { e_public_name = Some public_name
      ; e_internal_name = iname
      ; e_package = package
      ; e_path = path
      ; e_deps = deps
      ; e_ppx = ppx
      ; e_modules = modules
      ; e_modes = modes
      ; e_flags = flags
      ; e_link_flags = link_flags
      ; e_bisect_sigterm = bisect_sigterm
      ; e_no_instrumentation = no_instrumentation
      ; e_forbidden_libraries = forbidden_libraries
      ; e_preprocessor_deps = preprocessor_deps
      ; e_enabled_if = enabled_if
      ; e_opam_deps = opam_deps
      ; e_extra_stanzas = extra_stanzas
      }
  in
  targets := t :: !targets

let private_executable ?package ?(path = "") ?(deps = []) ?ppx ?(modules = [])
    ?(modes = []) ?(flags = []) ?(link_flags = []) ?(bisect_sigterm = false)
    ?(no_instrumentation = false) ?(forbidden_libraries = [])
    ?(preprocessor_deps = []) ?enabled_if ?(opam_deps = [])
    ?(extra_stanzas = []) name =
  let t =
    Executable
      { e_public_name = None
      ; e_internal_name = name
      ; e_package = package
      ; e_path = path
      ; e_deps = deps
      ; e_ppx = ppx
      ; e_modules = modules
      ; e_modes = modes
      ; e_flags = flags
      ; e_link_flags = link_flags
      ; e_bisect_sigterm = bisect_sigterm
      ; e_no_instrumentation = no_instrumentation
      ; e_forbidden_libraries = forbidden_libraries
      ; e_preprocessor_deps = preprocessor_deps
      ; e_enabled_if = enabled_if
      ; e_opam_deps = opam_deps
      ; e_extra_stanzas = extra_stanzas
      }
  in
  targets := t :: !targets

let test ?package ?(path = "") ?(deps = []) ?ppx ?(modules = []) ?(flags = [])
    ?(file_deps = []) ?enabled_if ?(no_instrumentation = false)
    ?(extra_stanzas = []) name =
  let t =
    Test
      { t_internal_name = name
      ; t_package = package
      ; t_path = path
      ; t_deps = deps
      ; t_ppx = ppx
      ; t_modules = modules
      ; t_flags = flags
      ; t_file_deps = file_deps
      ; t_enabled_if = enabled_if
      ; t_no_instrumentation = no_instrumentation
      ; t_extra_stanzas = extra_stanzas
      }
  in
  targets := t :: !targets

let file_stanzas ~path stanzas =
  targets := File_stanzas (path, stanzas) :: !targets

let render_deps deps =
  let opam_deps = List.filter (fun d -> d.kind = Opam) deps in
  let local_deps = List.filter (fun d -> d.kind <> Opam) deps in
  let has_both = opam_deps <> [] && local_deps <> [] in
  if has_both then
    "libraries"
    @: [ Comment "opam libraries" ]
    @ List.map (fun d -> atom d.name) opam_deps
    @ [ Comment "local libraries" ]
    @ List.map (fun d -> atom d.name) local_deps
  else "libraries" @: List.map (fun d -> atom d.name) deps

let render_ppx ppxes = "preprocess" @: [ "pps" @: List.map atom ppxes ]

let render_instrumentation ?(sigterm = false) () =
  if sigterm then
    "instrumentation"
    @: [ "backend" @: [ atom "bisect_ppx"; atom "--bisect-sigterm" ] ]
  else "instrumentation" @: [ "backend" @: [ atom "bisect_ppx" ] ]

let render_inline_tests ?(bare = false) ?(deps = []) () =
  if bare && deps = [] then List [ Atom "inline_tests" ]
  else
    let fields =
      ( if bare then []
      else [ "flags" @: [ atom "-verbose"; atom "-show-counts" ] ] )
      @ if deps <> [] then [ "deps" @: List.map atom deps ] else []
    in
    "inline_tests" @: fields

let render_foreign_stubs lang names =
  "foreign_stubs"
  @: [ "language" @: [ atom lang ]; "names" @: List.map atom names ]

let generate_library_sexpr lib =
  let fields =
    [ "name" @: [ atom lib.l_internal_name ] ]
    @ opt_some lib.l_public_name (fun pn -> "public_name" @: [ atom pn ])
    @ opt_some lib.l_kind (fun k -> "kind" @: [ atom k ])
    @ opt lib.l_inline_tests
        (render_inline_tests ~bare:lib.l_inline_tests_bare
           ~deps:lib.l_inline_tests_deps () )
    @ ( match lib.l_foreign_stubs with
      | Some (lang, names) ->
          [ render_foreign_stubs lang names ]
      | None ->
          [] )
    @ (if lib.l_flags <> [] then [ "flags" @: lib.l_flags ] else [])
    @ (if lib.l_deps <> [] then [ render_deps lib.l_deps ] else [])
    @ ( if lib.l_library_flags <> [] then
        [ "library_flags" @: List.map atom lib.l_library_flags ]
      else [] )
    @ ( if lib.l_virtual_modules <> [] then
        [ "virtual_modules" @: List.map atom lib.l_virtual_modules ]
      else [] )
    @ opt_some lib.l_default_implementation (fun impl ->
          "default_implementation" @: [ atom impl ] )
    @ opt_some lib.l_implements (fun impl -> "implements" @: [ atom impl ])
    @ ( if lib.l_modes <> [] then [ "modes" @: List.map atom lib.l_modes ]
      else [] )
    @ ( if not lib.l_no_instrumentation then
        [ render_instrumentation ~sigterm:lib.l_bisect_sigterm () ]
      else [] )
    @ (match lib.l_ppx with Some ppxes -> [ render_ppx ppxes ] | None -> [])
    @ opt_some lib.l_synopsis (fun s -> "synopsis" @: [ atom s ])
    @ ( if lib.l_modules <> [] then [ "modules" @: List.map atom lib.l_modules ]
      else if lib.l_modules_exclude <> [] then
        [ "modules"
          @: atom ":standard" :: atom "\\"
             :: List.map atom lib.l_modules_exclude
        ]
      else [] )
    @ ( if lib.l_modules_without_implementation <> [] then
        [ "modules_without_implementation"
          @: List.map atom lib.l_modules_without_implementation
        ]
      else [] )
    @ ( if lib.l_c_library_flags <> [] then
        [ "c_library_flags" @: List.map atom lib.l_c_library_flags ]
      else [] )
    @ ( if lib.l_preprocessor_deps <> [] then
        [ "preprocessor_deps" @: List.map atom lib.l_preprocessor_deps ]
      else [] )
    @ ( if lib.l_ppx_runtime_libraries <> [] then
        [ "ppx_runtime_libraries" @: List.map atom lib.l_ppx_runtime_libraries ]
      else [] )
    @ opt_some lib.l_wrapped (fun w ->
          "wrapped" @: [ atom (if w then "true" else "false") ] )
    @ opt_some lib.l_enabled_if (fun e -> "enabled_if" @: [ atom e ])
    @ opt_some lib.l_js_of_ocaml (fun j -> j)
  in
  "library" @: fields

let generate_executable_sexpr exe =
  let fields =
    opt_some exe.e_package (fun pkg -> "package" @: [ atom pkg ])
    @ [ "name" @: [ atom exe.e_internal_name ] ]
    @ opt_some exe.e_public_name (fun pn -> "public_name" @: [ atom pn ])
    @ ( if exe.e_modules <> [] then [ "modules" @: List.map atom exe.e_modules ]
      else [] )
    @ ( if exe.e_modes <> [] then [ "modes" @: List.map atom exe.e_modes ]
      else [] )
    @ (if exe.e_flags <> [] then [ "flags" @: exe.e_flags ] else [])
    @ ( if exe.e_link_flags <> [] then
        [ "link_flags" @: List.map atom exe.e_link_flags ]
      else [] )
    @ (if exe.e_deps <> [] then [ render_deps exe.e_deps ] else [])
    @ ( if exe.e_forbidden_libraries <> [] then
        [ "forbidden_libraries" @: List.map atom exe.e_forbidden_libraries ]
      else [] )
    @ ( if not exe.e_no_instrumentation then
        [ render_instrumentation ~sigterm:exe.e_bisect_sigterm () ]
      else [] )
    @ ( if exe.e_preprocessor_deps <> [] then
        [ "preprocessor_deps" @: List.map atom exe.e_preprocessor_deps ]
      else [] )
    @ (match exe.e_ppx with Some ppxes -> [ render_ppx ppxes ] | None -> [])
    @ opt_some exe.e_enabled_if (fun e -> "enabled_if" @: [ atom e ])
  in
  "executable" @: fields

let generate_test_sexpr t =
  let fields =
    [ "name" @: [ atom t.t_internal_name ] ]
    @ opt_some t.t_package (fun pkg -> "package" @: [ atom pkg ])
    @ ( if t.t_modules <> [] then [ "modules" @: List.map atom t.t_modules ]
      else [] )
    @ (if t.t_flags <> [] then [ "flags" @: t.t_flags ] else [])
    @ ( if t.t_file_deps <> [] then [ "deps" @: List.map atom t.t_file_deps ]
      else [] )
    @ opt_some t.t_enabled_if (fun cond -> "enabled_if" @: [ atom cond ])
    @ (if t.t_deps <> [] then [ render_deps t.t_deps ] else [])
    @ (if not t.t_no_instrumentation then [ render_instrumentation () ] else [])
    @ match t.t_ppx with Some ppxes -> [ render_ppx ppxes ] | None -> []
  in
  "test" @: fields

let dune_header =
  "; This file was automatically generated, do not edit.\n\
   ; Edit the manifest in manifest/product_mina.ml and run\n\
   ; manifest/main.exe to update.\n\n"

let write_file path content =
  let dir = Filename.dirname path in
  let rec mkdir_p d =
    if Sys.file_exists d then ()
    else (
      mkdir_p (Filename.dirname d) ;
      try Unix.mkdir d 0o755 with Unix.Unix_error _ -> () )
  in
  mkdir_p dir ;
  let oc = open_out path in
  output_string oc content ; close_out oc

let target_path = function
  | Library l ->
      l.l_path
  | Executable e ->
      e.e_path
  | Test t ->
      t.t_path
  | File_stanzas (p, _) ->
      p

let check_mode = ref false

type check_result =
  { path : string; status : [ `Ok | `Differs of string option | `New ] }

let check () =
  let all_targets = List.rev !targets in
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun t ->
      let path = target_path t in
      let existing = try Hashtbl.find tbl path with Not_found -> [] in
      Hashtbl.replace tbl path (existing @ [ t ]) )
    all_targets ;
  let paths =
    Hashtbl.fold (fun k _ acc -> k :: acc) tbl [] |> List.sort String.compare
  in
  List.filter_map
    (fun path ->
      if path = "" then None
      else
        let targets_in_dir = Hashtbl.find tbl path in
        let stanzas =
          List.concat_map
            (fun t ->
              match t with
              | Library l ->
                  generate_library_sexpr l :: l.l_extra_stanzas
              | Executable e ->
                  generate_executable_sexpr e :: e.e_extra_stanzas
              | Test tt ->
                  generate_test_sexpr tt :: tt.t_extra_stanzas
              | File_stanzas (_, ss) ->
                  ss )
            targets_in_dir
        in
        let file_path = Filename.concat path "dune" in
        let existing_stanzas =
          try Some (parse_file file_path) with _ -> None
        in
        match existing_stanzas with
        | None ->
            Some { path = file_path; status = `New }
        | Some existing ->
            if equal_stanzas stanzas existing then
              Some { path = file_path; status = `Ok }
            else
              let gen = List.filter_map strip_comments stanzas in
              let old = List.filter_map strip_comments existing in
              let detail =
                match (gen, old) with
                | g :: _, o :: _ ->
                    diff g o
                | _ ->
                    Some
                      (Printf.sprintf "stanza count: %d vs %d" (List.length gen)
                         (List.length old) )
              in
              Some { path = file_path; status = `Differs detail } )
    paths

let opam_header =
  "# This file was automatically generated, do not edit.\n\
   # Edit the manifest in manifest/product_mina.ml and run\n\
   # manifest/main.exe to update.\n"

let generate_opam_content ~synopsis ~opam_deps =
  let buf = Buffer.create 256 in
  Buffer.add_string buf opam_header ;
  Buffer.add_string buf "opam-version: \"2.0\"\n" ;
  Buffer.add_string buf "version: \"0.1\"\n" ;
  ( match synopsis with
  | Some s ->
      Buffer.add_string buf (Printf.sprintf "synopsis: \"%s\"\n" s)
  | None ->
      () ) ;
  Buffer.add_string buf "build: [\n" ;
  Buffer.add_string buf
    "  [\"dune\" \"build\" \"--only\" \"src\" \"--root\" \".\" \"-j\" jobs \
     \"@install\"]\n" ;
  Buffer.add_string buf "]\n" ;
  if opam_deps <> [] then (
    Buffer.add_string buf "\n" ;
    Buffer.add_string buf "depends: [\n" ;
    List.iter
      (fun dep -> Buffer.add_string buf (Printf.sprintf "  \"%s\"\n" dep))
      opam_deps ;
    Buffer.add_string buf "]\n" ) ;
  Buffer.contents buf

let generate_opam_files targets =
  (* Collect all packages that need opam files *)
  let packages = Hashtbl.create 32 in
  List.iter
    (fun t ->
      match t with
      | Library l ->
          if l.l_opam_deps <> [] then
            let pkg =
              match l.l_public_name with
              | Some pn ->
                  pn
              | None ->
                  l.l_internal_name
            in
            let base_pkg =
              match String.index_opt pkg '.' with
              | Some i ->
                  String.sub pkg 0 i
              | None ->
                  pkg
            in
            Hashtbl.replace packages base_pkg
              (l.l_synopsis, l.l_opam_deps, l.l_path)
      | Executable e ->
          if e.e_opam_deps <> [] then
            let pkg =
              match e.e_package with
              | Some p ->
                  p
              | None -> (
                  match e.e_public_name with
                  | Some pn ->
                      pn
                  | None ->
                      e.e_internal_name )
            in
            Hashtbl.replace packages pkg (None, e.e_opam_deps, e.e_path)
      | Test _ | File_stanzas _ ->
          () )
    targets ;
  if Hashtbl.length packages > 0 then (
    Printf.printf "Generating opam files...\n" ;
    Hashtbl.iter
      (fun pkg (synopsis, opam_deps, path) ->
        let content = generate_opam_content ~synopsis ~opam_deps in
        let file_path = Filename.concat path (pkg ^ ".opam") in
        if !check_mode then Printf.printf "  %s (check)\n" file_path
        else (
          write_file file_path content ;
          Printf.printf "  %s (written)\n" file_path ) )
      packages )

let generate () =
  let all_targets = List.rev !targets in
  (* Group targets by path *)
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun t ->
      let path = target_path t in
      let existing = try Hashtbl.find tbl path with Not_found -> [] in
      Hashtbl.replace tbl path (existing @ [ t ]) )
    all_targets ;
  let mode = if !check_mode then "Checking" else "Generating" in
  Printf.printf "%s dune files...\n" mode ;
  let errors = ref 0 in
  (* Sort paths for deterministic output *)
  let paths =
    Hashtbl.fold (fun k _ acc -> k :: acc) tbl [] |> List.sort String.compare
  in
  List.iter
    (fun path ->
      if path = "" then
        Printf.eprintf "  Warning: target with empty path, skipping\n"
      else
        let targets_in_dir = Hashtbl.find tbl path in
        let stanzas =
          List.concat_map
            (fun t ->
              match t with
              | Library l ->
                  generate_library_sexpr l :: l.l_extra_stanzas
              | Executable e ->
                  generate_executable_sexpr e :: e.e_extra_stanzas
              | Test tt ->
                  generate_test_sexpr tt :: tt.t_extra_stanzas
              | File_stanzas (_, ss) ->
                  ss )
            targets_in_dir
        in
        let content = dune_header ^ to_string stanzas in
        let file_path = Filename.concat path "dune" in
        (* Read existing file for comparison *)
        let existing_stanzas =
          try Some (parse_file file_path) with _ -> None
        in
        (* Structural comparison *)
        let is_equivalent =
          match existing_stanzas with
          | None ->
              false
          | Some existing ->
              equal_stanzas stanzas existing
        in
        if !check_mode then
          (* Check mode: don't write, just report *)
          match existing_stanzas with
          | None ->
              Printf.printf "  %s (new)\n" file_path
          | Some existing ->
              if is_equivalent then Printf.printf "  %s (ok)\n" file_path
              else (
                Printf.printf "  %s (DIFFERS)\n" file_path ;
                let gen = List.filter_map strip_comments stanzas in
                let old = List.filter_map strip_comments existing in
                ( match (gen, old) with
                | g :: _, o :: _ -> (
                    match diff g o with
                    | Some d ->
                        Printf.printf "    %s\n" d
                    | None ->
                        Printf.printf "    (diff in later stanza)\n" )
                | _ ->
                    Printf.printf "    (stanza count: %d vs %d)\n"
                      (List.length gen) (List.length old) ) ;
                incr errors )
        else (
          (* Generate mode: write file *)
          write_file file_path content ;
          if is_equivalent then Printf.printf "  %s (ok)\n" file_path
          else Printf.printf "  %s (written)\n" file_path ) )
    paths ;
  (* Generate opam files *)
  generate_opam_files all_targets ;
  if !check_mode then
    Printf.printf "Done. %d file(s) with differences.\n" !errors
  else Printf.printf "Done. %d file(s) written.\n" (List.length paths)
