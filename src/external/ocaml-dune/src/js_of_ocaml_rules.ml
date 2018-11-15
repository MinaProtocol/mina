open! Stdune
open Import
open! No_io
open Build.O

module SC = Super_context

let dev_mode sctx = SC.profile sctx = "dev"

let separate_compilation_enabled = dev_mode

let pretty    sctx = if dev_mode sctx then ["--pretty"           ] else []
let sourcemap sctx = if dev_mode sctx then ["--source-map-inline"] else []

let standard sctx = pretty sctx @ sourcemap sctx

let install_jsoo_hint = "try: opam install js_of_ocaml-compiler"

let in_build_dir ~ctx args =
  Path.L.relative ctx.Context.build_dir (".js" :: args)

let runtime_file ~sctx file =
  match
    Artifacts.file_of_lib (SC.artifacts sctx)
      ~loc:Loc.none
      ~lib:(Lib_name.of_string_exn ~loc:None "js_of_ocaml-compiler") ~file
  with
  | Error _ ->
    Arg_spec.Dyn (fun _ ->
      Utils.library_not_found ~context:(SC.context sctx).name
        ~hint:install_jsoo_hint
        "js_of_ocaml-compiler")
  | Ok f -> Arg_spec.Dep f

let js_of_ocaml_rule sctx ~dir ~flags ~spec ~target =
  let jsoo =
    SC.resolve_program sctx ~dir ~loc:None ~hint:install_jsoo_hint
      "js_of_ocaml" in
  let runtime = runtime_file ~sctx "runtime.js" in
  Build.run ~dir
    jsoo
    [ Arg_spec.Dyn flags
    ; Arg_spec.A "-o"; Target target
    ; Arg_spec.A "--no-runtime"; runtime
    ; spec
    ]

let standalone_runtime_rule cc ~javascript_files ~target =
  let spec =
    Arg_spec.S
      [ Arg_spec.of_result_map (Compilation_context.requires cc) ~f:(fun libs ->
          Arg_spec.Deps (Lib.L.jsoo_runtime_files libs))
      ; Arg_spec.Deps javascript_files
      ]
  in
  Build.arr (fun (cm_files, flags) -> (cm_files, "--runtime-only" :: flags))
  >>>
  js_of_ocaml_rule
    (Compilation_context.super_context cc)
    ~dir:(Compilation_context.dir cc)
    ~flags:(fun (_,flags) -> As flags) ~target ~spec

let exe_rule cc ~javascript_files ~src ~target =
  let dir = Compilation_context.dir cc in
  let sctx = Compilation_context.super_context cc in
  let spec =
    Arg_spec.S
      [ Arg_spec.of_result_map (Compilation_context.requires cc)
          ~f:(fun libs -> Arg_spec.Deps (Lib.L.jsoo_runtime_files libs))
      ; Arg_spec.Deps javascript_files
      ; Arg_spec.Dep src
      ]
  in
  js_of_ocaml_rule sctx ~dir ~flags:(fun (_,flags) -> As flags) ~spec ~target

let jsoo_archives ~ctx lib =
  match Lib.jsoo_archive lib with
  | Some a -> [a]
  | None ->
    List.map (Lib.archives lib).byte ~f:(fun archive ->
      in_build_dir ~ctx
        [ Lib_name.to_string (Lib.name lib)
        ; Path.basename archive ^ ".js"
        ])

let link_rule cc ~runtime ~target =
  let sctx = Compilation_context.super_context cc in
  let ctx = Compilation_context.context cc in
  let dir = Compilation_context.dir cc in
  let get_all (cm, _) =
    Arg_spec.of_result_map (Compilation_context.requires cc) ~f:(fun libs ->
      let all_libs = List.concat_map libs ~f:(jsoo_archives ~ctx) in
      (* Special case for the stdlib because it is not referenced in the META *)
      let all_libs = in_build_dir ~ctx ["stdlib"; "stdlib.cma.js"] :: all_libs in
      let all_other_modules =
        List.map cm ~f:(fun m -> Path.extend_basename m ~suffix:".js")
      in
      Arg_spec.Deps (List.concat [all_libs;all_other_modules]))
  in
  let jsoo_link =
    SC.resolve_program sctx ~dir ~loc:None
      ~hint:install_jsoo_hint "jsoo_link" in
  Build.run ~dir:(Compilation_context.dir cc)
    jsoo_link
    [ Arg_spec.A "-o"; Target target
    ; Arg_spec.Dep runtime
    ; Arg_spec.As (sourcemap sctx)
    ; Arg_spec.Dyn get_all
    ]

let build_cm cctx ~(js_of_ocaml:Dune_file.Js_of_ocaml.t) ~src ~target =
  let sctx = Compilation_context.super_context cctx in
  let dir = Compilation_context.dir cctx in
  if separate_compilation_enabled sctx
  then
    let spec = Arg_spec.Dep src in
    let flags =
      let scope = Compilation_context.scope cctx in
      SC.expand_and_eval_set sctx ~scope ~dir js_of_ocaml.flags
        ~standard:(Build.return (standard sctx))
    in
    [ flags
      >>>
      js_of_ocaml_rule sctx ~dir ~flags:(fun flags -> As flags) ~spec ~target
    ]
  else []

let setup_separate_compilation_rules sctx components =
  if separate_compilation_enabled sctx
  then
    match components with
    | [] | _ :: _ :: _ -> ()
    | [pkg] ->
      let pkg = Lib_name.of_string_exn ~loc:None pkg in
      let ctx = SC.context sctx in
      match Lib.DB.find (SC.installed_libs sctx) pkg with
      | Error _ -> ()
      | Ok pkg ->
        let archives = (Lib.archives pkg).byte in
        let archives =
          (* Special case for the stdlib because it is not referenced
             in the META *)
          match Lib_name.to_string (Lib.name pkg) with
          | "stdlib" -> Path.relative ctx.stdlib_dir "stdlib.cma" :: archives
          | _ -> archives
        in
        List.iter archives ~f:(fun fn ->
          let name = Path.basename fn in
          let src = Path.relative (Lib.src_dir pkg) name in
          let lib_name = Lib_name.to_string (Lib.name pkg) in
          let target =
            in_build_dir ~ctx [lib_name ; sprintf "%s.js" name]
          in
          let dir = in_build_dir ~ctx [lib_name] in
          let spec = Arg_spec.Dep src in
          SC.add_rule sctx ~dir
            (Build.return (standard sctx)
             >>>
             js_of_ocaml_rule sctx ~dir ~flags:(fun flags ->
               As flags) ~spec ~target))

let build_exe cc ~js_of_ocaml ~src =
  let {Dune_file.Js_of_ocaml.javascript_files; _} = js_of_ocaml in
  let javascript_files =
    List.map javascript_files ~f:(Path.relative (Compilation_context.dir cc)) in
  let mk_target ext = Path.extend_basename src ~suffix:ext in
  let target = mk_target ".js" in
  let standalone_runtime = mk_target ".runtime.js" in
  if separate_compilation_enabled (Compilation_context.super_context cc) then
    [ link_rule cc ~runtime:standalone_runtime ~target
    ; standalone_runtime_rule cc ~javascript_files ~target:standalone_runtime
    ]
  else
    [ exe_rule cc ~javascript_files ~src ~target ]
