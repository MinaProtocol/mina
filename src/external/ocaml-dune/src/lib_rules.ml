open! Stdune
open Import
open Build.O
open! No_io

module Buildable = Dune_file.Buildable
module Library = Dune_file.Library
module Mode_conf = Dune_file.Mode_conf

module SC = Super_context

module Gen (P : Install_rules.Params) = struct
  module Odoc = Odoc.Gen(P)

  let sctx = P.sctx
  let ctx = SC.context sctx

  let opaque = SC.opaque sctx

  module Virtual = Virtual_rules.Gen(P)

  (* Library stuff *)

  let msvc_hack_cclibs =
    List.map ~f:(fun lib ->
      let lib =
        match String.drop_prefix lib ~prefix:"-l" with
        | None -> lib
        | Some l -> l ^ ".lib"
      in
      Option.value ~default:lib (String.drop_prefix ~prefix:"-l" lib))

  let build_lib (lib : Library.t) ~scope ~flags ~dir ~obj_dir ~mode
        ~top_sorted_modules ~modules =
    Option.iter (Context.compiler ctx mode) ~f:(fun compiler ->
      let target = Library.archive lib ~dir ~ext:(Mode.compiled_lib_ext mode) in
      let stubs_flags =
        if not (Library.has_stubs lib) then
          []
        else
          let stubs_name = Library.stubs_name lib in
          match mode with
          | Byte -> ["-dllib"; "-l" ^ stubs_name; "-cclib"; "-l" ^ stubs_name]
          | Native -> ["-cclib"; "-l" ^ stubs_name]
      in
      let map_cclibs =
        (* https://github.com/ocaml/dune/issues/119 *)
        if ctx.ccomp_type = "msvc" then
          msvc_hack_cclibs
        else
          fun x -> x
      in
      let artifacts ~ext modules =
        List.map modules ~f:(Module.obj_file ~obj_dir ~ext)
      in
      let obj_deps =
        Build.paths (artifacts modules ~ext:(Cm_kind.ext (Mode.cm_kind mode)))
      in
      let obj_deps =
        match mode with
        | Byte   -> obj_deps
        | Native ->
          obj_deps >>>
          Build.paths (artifacts modules ~ext:ctx.ext_obj)
      in
      SC.add_rule ~dir sctx ~loc:lib.buildable.loc
        (obj_deps
         >>>
         Build.fanout4
           (top_sorted_modules >>^artifacts ~ext:(Cm_kind.ext (Mode.cm_kind mode)))
           (SC.expand_and_eval_set sctx ~scope ~dir lib.c_library_flags
              ~standard:(Build.return []))
           (Ocaml_flags.get flags mode)
           (SC.expand_and_eval_set sctx ~scope ~dir lib.library_flags
              ~standard:(Build.return []))
         >>>
         Build.run (Ok compiler) ~dir:ctx.build_dir
           [ Dyn (fun (_, _, flags, _) -> As flags)
           ; A "-a"; A "-o"; Target target
           ; As stubs_flags
           ; Dyn (fun (_, cclibs, _, _) -> Arg_spec.quote_args "-cclib" (map_cclibs cclibs))
           ; Dyn (fun (_, _, _, library_flags) -> As library_flags)
           ; As (match lib.kind with
               | Normal -> []
               | Ppx_deriver | Ppx_rewriter -> ["-linkall"])
           ; Dyn (fun (cm_files, _, _, _) -> Deps cm_files)
           ; Hidden_targets
               (match mode with
                | Byte -> []
                | Native -> [Library.archive lib ~dir ~ext:ctx.ext_lib])
           ]))

  (* If the compiler reads the cmi for module alias even with
     [-w -49 -no-alias-deps], we must sandbox the build of the
     alias module since the modules it references are built after. *)
  let alias_module_build_sandbox =
    Ocaml_version.always_reads_alias_cmi ctx.version

  let build_alias_module { Lib_modules.Alias_module.main_module_name
                         ; alias_module } ~dir
        ~modules ~modules_of_vlib ~cctx ~dynlink ~js_of_ocaml =
    let file =
      match Module.impl alias_module with
      | Some f -> f
      | None -> Option.value_exn (Module.intf alias_module)
    in
    let modules =
      match modules_of_vlib with
      | None -> modules
      | Some vlib ->
        Module.Name.Map.merge modules vlib ~f:(fun _ impl vlib ->
          match impl, vlib with
          | None, None -> assert false
          | Some _, (None | Some _) -> impl
          | _, Some vlib -> Option.some_if (Module.is_public vlib) vlib
        )
    in
    SC.add_rule sctx ~dir
      (Build.return
         (Module.Name.Map.values
            (Module.Name.Map.remove modules (Module.name alias_module))
          |> List.map ~f:(fun (m : Module.t) ->
            let name = Module.Name.to_string (Module.name m) in
            sprintf "(** @canonical %s.%s *)\n\
                     module %s = %s\n"
              (Module.Name.to_string main_module_name)
              name
              name
              (Module.Name.to_string (Module.real_unit_name m))
          )
          |> String.concat ~sep:"\n")
       >>> Build.write_file_dyn file.path);
    let cctx = Compilation_context.for_alias_module cctx in
    Module_compilation.build_module cctx alias_module
      ~js_of_ocaml
      ~dynlink
      ~sandbox:alias_module_build_sandbox
      ~dep_graphs:(Ocamldep.Dep_graphs.dummy alias_module)

  let build_wrapped_compat_modules (lib : Library.t)
        cctx
        ~js_of_ocaml
        ~dynlink
        ~modules
        ~wrapped_compat =
    let transition_message =
      match lib.wrapped with
      | Simple _ -> "" (* will never be accessed anyway *)
      | Yes_with_transition r -> r
    in
    Module.Name.Map.iteri wrapped_compat ~f:(fun name m ->
      let main_module_name =
        match Library.main_module_name lib with
        | This (Some mmn) -> Module.Name.to_string mmn
        | _ -> assert false
      in
      let contents =
        let name = Module.Name.to_string name in
        let hidden_name = sprintf "%s__%s" main_module_name name in
        let real_name = sprintf "%s.%s" main_module_name name in
        sprintf {|[@@@deprecated "%s. Use %s instead."] include %s|}
          transition_message real_name hidden_name
      in
      let source_path = Option.value_exn (Module.file m Impl) in
      Build.return contents
      >>> Build.write_file_dyn source_path
      |> SC.add_rule sctx ~dir:(Compilation_context.dir cctx)
    );
    let dep_graphs =
      Ocamldep.Dep_graphs.wrapped_compat ~modules ~wrapped_compat
    in
    let cctx = Compilation_context.for_wrapped_compat cctx wrapped_compat in
    Module_compilation.build_modules cctx ~js_of_ocaml ~dynlink ~dep_graphs

  let build_c_file (lib : Library.t) ~scope ~dir ~includes (loc, src, dst) =
    SC.add_rule sctx ~loc ~dir
      (SC.expand_and_eval_set sctx ~scope ~dir lib.c_flags
         ~standard:(Build.return (Context.cc_g ctx))
       >>>
       Build.run
         (* We have to execute the rule in the library directory as
            the .o is produced in the current directory *)
         ~dir:(Path.parent_exn src)
         (Ok ctx.ocamlc)
         [ A "-g"
         ; includes
         ; Dyn (fun c_flags -> Arg_spec.quote_args "-ccopt" c_flags)
         ; A "-o"; Target dst
         ; Dep src
         ]);
    dst

  let build_cxx_file (lib : Library.t) ~scope ~dir ~includes (loc, src, dst) =
    let open Arg_spec in
    let output_param =
      if ctx.ccomp_type = "msvc" then
        [Concat ("", [A "/Fo"; Target dst])]
      else
        [A "-o"; Target dst]
    in
    SC.add_rule sctx ~loc ~dir
      (SC.expand_and_eval_set sctx ~scope ~dir lib.cxx_flags
         ~standard:(Build.return (Context.cc_g ctx))
       >>>
       Build.run
         (* We have to execute the rule in the library directory as
            the .o is produced in the current directory *)
         ~dir:(Path.parent_exn src)
         (SC.resolve_program ~loc:None ~dir sctx ctx.c_compiler)
         ([ S [A "-I"; Path ctx.stdlib_dir]
          ; As (SC.cxx_flags sctx)
          ; includes
          ; Dyn (fun cxx_flags -> As cxx_flags)
          ] @ output_param @
          [ A "-c"; Dep src
          ]));
    dst

  let ocamlmklib (lib : Library.t) ~dir ~scope ~o_files ~sandbox ~custom
        ~targets =
    SC.add_rule sctx ~sandbox ~dir
      ~loc:lib.buildable.loc
      (SC.expand_and_eval_set sctx ~scope ~dir
         lib.c_library_flags ~standard:(Build.return [])
       >>>
       Build.run ~dir:ctx.build_dir
         (Ok ctx.ocamlmklib)
         [ A "-g"
         ; if custom then A "-custom" else As []
         ; A "-o"
         ; Path (Library.stubs lib ~dir)
         ; Deps o_files
         ; Dyn (fun cclibs ->
             (* https://github.com/ocaml/dune/issues/119 *)
             if ctx.ccomp_type = "msvc" then
               let cclibs = msvc_hack_cclibs cclibs in
               Arg_spec.quote_args "-ldopt" cclibs
             else
               As cclibs
           )
         ; Hidden_targets targets
         ])

  let build_self_stubs lib ~scope ~dir ~o_files =
    let static = Library.stubs_archive lib ~dir ~ext_lib:ctx.ext_lib in
    let dynamic = Library.dll lib ~dir ~ext_dll:ctx.ext_dll in
    let modes =
      Mode_conf.Set.eval lib.modes
        ~has_native:(Option.is_some ctx.ocamlopt) in
    let ocamlmklib = ocamlmklib lib ~scope ~dir ~o_files in
    if modes.native &&
       modes.byte   &&
       Dynlink_supported.get lib.dynlink ctx.supports_shared_libraries
    then begin
      (* If we build for both modes and support dynlink, use a
         single invocation to build both the static and dynamic
         libraries *)
      ocamlmklib ~sandbox:false ~custom:false ~targets:[static; dynamic]
    end else begin
      ocamlmklib ~sandbox:false ~custom:true ~targets:[static];
      (* We can't tell ocamlmklib to build only the dll, so we
         sandbox the action to avoid overriding the static archive *)
      ocamlmklib ~sandbox:true ~custom:false ~targets:[dynamic]
    end

  let build_o_files lib ~dir ~scope ~requires ~dir_contents =
    let all_dirs = Dir_contents.dirs dir_contents in
    let h_files =
      List.fold_left all_dirs ~init:[] ~f:(fun acc dc ->
        String.Set.fold (Dir_contents.text_files dc) ~init:acc
          ~f:(fun fn acc ->
            if String.is_suffix fn ~suffix:".h" then
              Path.relative (Dir_contents.dir dc) fn :: acc
            else
              acc))
    in
    let all_dirs = Path.Set.of_list (List.map all_dirs ~f:Dir_contents.dir) in
    let resolve_name ~ext (loc, fn) =
      let p = Path.relative dir (fn ^ ext) in
      if not (match Path.parent p with
        | None -> false
        | Some p -> Path.Set.mem all_dirs p) then
        Errors.fail loc
          "File %a is not part of the current directory group. \
           This is not allowed."
          Path.pp (Path.drop_optional_build_context p)
      ;
      (loc, p, Path.relative dir (fn ^ ctx.ext_obj))
    in
    let includes =
      Arg_spec.S
        [ Hidden_deps h_files
        ; Arg_spec.of_result_map requires ~f:(fun libs ->
            S [ Lib.L.c_include_flags libs ~stdlib_dir:ctx.stdlib_dir
              ; Hidden_deps (Lib_file_deps.L.file_deps sctx libs ~exts:[".h"])
              ])
        ]
    in
    List.map lib.c_names ~f:(fun name ->
      build_c_file   lib ~scope ~dir ~includes (resolve_name name ~ext:".c")
    ) @ List.map lib.cxx_names ~f:(fun name ->
      build_cxx_file lib ~scope ~dir ~includes (resolve_name name ~ext:".cpp")
    )

  let build_stubs lib ~dir ~scope ~requires ~dir_contents ~vlib_stubs_o_files =
    let lib_o_files =
      if Library.has_stubs lib then
        build_o_files lib ~dir ~scope ~requires ~dir_contents
      else
        []
    in
    match vlib_stubs_o_files @ lib_o_files with
    | [] -> ()
    | o_files -> build_self_stubs lib ~dir ~scope ~o_files

  let build_shared lib ~dir ~flags ~(ctx : Context.t) =
    Option.iter ctx.ocamlopt ~f:(fun ocamlopt ->
      let src = Library.archive lib ~dir ~ext:(Mode.compiled_lib_ext Native) in
      let dst = Library.archive lib ~dir ~ext:".cmxs" in
      let build =
        Build.dyn_paths (Build.arr (fun () ->
          [Library.archive lib ~dir ~ext:ctx.ext_lib]))
        >>>
        Ocaml_flags.get flags Native
        >>>
        Build.run ~dir:ctx.build_dir
          (Ok ocamlopt)
          [ Dyn (fun flags -> As flags)
          ; A "-shared"; A "-linkall"
          ; A "-I"; Path dir
          ; A "-o"; Target dst
          ; Dep src
          ]
      in
      let build =
        if Library.has_stubs lib then
          Build.path (Library.stubs_archive ~dir lib ~ext_lib:ctx.ext_lib)
          >>>
          build
        else
          build
      in
      SC.add_rule sctx build ~dir)

  let setup_file_deps lib ~dir ~obj_dir ~modules ~modules_of_vlib =
    let add_cms ~cm_kind ~init = Module.Name.Map.fold ~init ~f:(fun m acc ->
      match Module.cm_file m ~obj_dir cm_kind with
      | None -> acc
      | Some fn -> Path.Set.add acc fn)
    in
    List.iter Cm_kind.all ~f:(fun cm_kind ->
      let files = add_cms ~cm_kind ~init:Path.Set.empty modules in
      let files = add_cms ~cm_kind ~init:files modules_of_vlib in
      Lib_file_deps.setup_file_deps_alias sctx ~dir lib ~exts:[Cm_kind.ext cm_kind]
        files);

    Lib_file_deps.setup_file_deps_group_alias sctx ~dir lib ~exts:[".cmi"; ".cmx"];
    Lib_file_deps.setup_file_deps_alias sctx ~dir lib ~exts:[".h"]
      (List.map lib.install_c_headers ~f:(fun header ->
         Path.relative dir (header ^ ".h"))
       |> Path.Set.of_list)

  let setup_build_archives (lib : Dune_file.Library.t)
        ~wrapped_compat ~cctx ~(dep_graphs : Ocamldep.Dep_graphs.t)
        ~vlib_dep_graphs =
    let dir = Compilation_context.dir cctx in
    let obj_dir = Compilation_context.obj_dir cctx in
    let scope = Compilation_context.scope cctx in
    let flags = Compilation_context.flags cctx in
    let modules = Compilation_context.modules cctx in
    let js_of_ocaml = lib.buildable.js_of_ocaml in
    let modules_of_vilb = Compilation_context.modules_of_vlib cctx in
    let modules =
      match lib.stdlib with
      | Some { exit_module = Some name; _ } -> begin
          match Module.Name.Map.find modules name with
          | None -> modules
          | Some m ->
            (* These files needs to be alongside stdlib.cma as the
               compiler implicitly adds this module. *)
            List.iter [".cmx"; ".cmo"; ctx.ext_obj] ~f:(fun ext ->
              let src = Module.obj_file m ~obj_dir ~ext in
              let dst = Module.obj_file m ~obj_dir:dir ~ext in
              SC.add_rule sctx ~dir (Build.copy ~src ~dst));
            Module.Name.Map.remove modules name
        end
      | _ ->
        modules
    in
    let modules = List.rev_append
                    (Module.Name_map.impl_only modules)
                    (Module.Name_map.impl_only modules_of_vilb) in
    let wrapped_compat = Module.Name.Map.values wrapped_compat in
    (* Compatibility modules have implementations so we can just append them.
       We append the modules at the end as no library modules depend on
       them. *)
    let top_sorted_modules =
      match vlib_dep_graphs with
      | None ->
        Ocamldep.Dep_graph.top_closed_implementations dep_graphs.impl modules
        >>^ fun modules -> modules @ wrapped_compat
      | Some (vlib_dep_graphs : Ocamldep.Dep_graphs.t) ->
        Ocamldep.Dep_graph.top_closed_multi_implementations
          [ vlib_dep_graphs.impl
          ; dep_graphs.impl
          ]
          modules
    in
    (let modules = modules @ wrapped_compat in
     List.iter Mode.all ~f:(fun mode ->
       build_lib lib ~scope ~flags ~dir ~obj_dir ~mode ~top_sorted_modules
         ~modules));
    (* Build *.cma.js *)
    SC.add_rules sctx ~dir (
      let src =
        Library.archive lib ~dir
          ~ext:(Mode.compiled_lib_ext Mode.Byte) in
      let target =
        Path.relative obj_dir (Path.basename src)
        |> Path.extend_basename ~suffix:".js" in
      Js_of_ocaml_rules.build_cm cctx ~js_of_ocaml ~src ~target);
    if Dynlink_supported.By_the_os.get ctx.natdynlink_supported then
        build_shared lib ~dir ~flags ~ctx

  let library_rules (lib : Library.t) ~dir_contents ~dir ~scope
        ~compile_info ~dir_kind =
    let obj_dir = Utils.library_object_directory ~dir (snd lib.name) in
    let private_obj_dir = Utils.library_private_obj_dir ~obj_dir in
    let requires = Lib.Compile.requires compile_info in
    let dep_kind =
      if lib.optional then Lib_deps_info.Kind.Optional else Required
    in
    let flags = SC.ocaml_flags sctx ~dir lib.buildable in
    let lib_modules =
      Dir_contents.modules_of_library dir_contents ~name:(Library.best_name lib)
    in
    Check_rules.add_obj_dir sctx ~dir ~obj_dir;
    if Lib_modules.has_private_modules lib_modules then
      Check_rules.add_obj_dir sctx ~dir ~obj_dir:private_obj_dir;
    let source_modules = Lib_modules.modules lib_modules in
    let impl = Virtual.impl ~lib ~scope ~modules:source_modules in
    Option.iter impl ~f:(Virtual.setup_copy_rules_for_impl ~dir);
    (* Preprocess before adding the alias module as it doesn't need
       preprocessing *)
    let pp =
      Preprocessing.make sctx ~dir ~dep_kind ~scope
        ~preprocess:lib.buildable.preprocess
        ~preprocessor_deps:
          (SC.Deps.interpret sctx ~scope ~dir
             lib.buildable.preprocessor_deps)
        ~lint:lib.buildable.lint
        ~lib_name:(Some (snd lib.name))
        ~dir_kind
    in

    let lib_modules =
      Preprocessing.pp_modules pp source_modules
      |> Lib_modules.set_modules lib_modules
    in

    let alias_module = Lib_modules.alias_module lib_modules in
    let modules = Lib_modules.for_compilation lib_modules in

    let cctx =
      Compilation_context.create ()
        ~super_context:sctx
        ?modules_of_vlib:(
          Option.map impl ~f:(fun impl ->
            Virtual_rules.Implementation.vlib_modules impl
            |> Lib_modules.modules ))
        ~scope
        ~dir
        ~dir_kind
        ~obj_dir
        ~private_obj_dir
        ~modules
        ?alias_module
        ?lib_interface_module:(Lib_modules.lib_interface_module lib_modules)
        ~flags
        ~requires
        ~preprocessing:pp
        ~no_keep_locs:lib.no_keep_locs
        ~opaque
        ?stdlib:lib.stdlib
    in

    let dynlink =
      Dynlink_supported.get lib.dynlink ctx.supports_shared_libraries
    in
    let js_of_ocaml = lib.buildable.js_of_ocaml in

    let wrapped_compat = Lib_modules.wrapped_compat lib_modules in
    build_wrapped_compat_modules lib cctx ~dynlink ~js_of_ocaml
      ~modules ~wrapped_compat;

    let (vlib_dep_graphs, dep_graphs) =
      let dep_graphs = Ocamldep.rules cctx in
      match impl with
      | None ->
        (None, dep_graphs)
      | Some impl ->
        let vlib = Virtual_rules.Implementation.vlib_dep_graph impl in
        ( Some vlib
        , Ocamldep.Dep_graphs.merge_for_impl ~vlib ~impl:dep_graphs
        )
    in

    Module_compilation.build_modules cctx ~js_of_ocaml ~dynlink ~dep_graphs;

    let vlib_modules =
      Option.map ~f:Virtual_rules.Implementation.vlib_modules impl in

    if Option.is_none lib.stdlib then
      Option.iter (Lib_modules.alias lib_modules)
        ~f:(build_alias_module ~dir ~modules:source_modules ~cctx ~dynlink
              ~js_of_ocaml
              ~modules_of_vlib:(Option.map vlib_modules ~f:Lib_modules.modules));

    let vlib_stubs_o_files =
      match impl with
      | None -> []
      | Some impl -> Virtual.vlib_stubs_o_files impl
    in
    if Library.has_stubs lib || not (List.is_empty vlib_stubs_o_files) then
      build_stubs lib ~dir ~scope ~requires ~dir_contents ~vlib_stubs_o_files;

    setup_file_deps lib ~dir ~obj_dir
      ~modules:(Lib_modules.have_artifacts lib_modules)
      ~modules_of_vlib:(
        match vlib_modules with
        | None -> Module.Name.Map.empty
        | Some modules -> Lib_modules.for_compilation modules);

    if not (Library.is_virtual lib) then
      setup_build_archives lib ~wrapped_compat ~cctx ~dep_graphs
        ~vlib_dep_graphs;

    Odoc.setup_library_odoc_rules lib ~requires ~modules ~dep_graphs ~scope;

    let flags =
      match alias_module with
      | None -> Ocaml_flags.common flags
      | Some m ->
        Ocaml_flags.prepend_common
          ["-open"; Module.Name.to_string (Module.name m)] flags
        |> Ocaml_flags.common
    in

    Sub_system.gen_rules
      { super_context = sctx
      ; dir
      ; stanza = lib
      ; scope
      ; source_modules
      ; compile_info
      };

    (cctx,
     Merlin.make ()
       ~requires:(Lib.Compile.requires compile_info)
       ~flags
       ~preprocess:(Buildable.single_preprocess lib.buildable)
       ~libname:(snd lib.name)
       ~objs_dirs:(Path.Set.singleton obj_dir))

  let rules (lib : Library.t) ~dir_contents ~dir ~scope
        ~dir_kind : Compilation_context.t * Merlin.t =
    let compile_info =
      Lib.DB.get_compile_info (Scope.libs scope) (Library.best_name lib)
        ~allow_overlaps:lib.buildable.allow_overlapping_dependencies
    in
    SC.Libs.gen_select_rules sctx compile_info ~dir;
    SC.Libs.with_lib_deps sctx compile_info ~dir
      ~f:(fun () ->
        library_rules lib ~dir_contents ~dir ~scope ~compile_info
          ~dir_kind)

end
