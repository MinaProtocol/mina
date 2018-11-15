open! Stdune
open Import
open Build.O

module CC = Compilation_context
module SC = Super_context

module Program = struct
  type t =
    { name             : string
    ; main_module_name : Module.Name.t
    ; loc              : Loc.t
    }
end

module Linkage = struct
  type t =
    { mode  : Mode.t
    ; ext   : string
    ; flags : string list
    }

  let byte =
    { mode  = Byte
    ; ext   = ".bc"
    ; flags = []
    }

  let native =
    { mode  = Native
    ; ext   = ".exe"
    ; flags = []
    }

  let custom =
    { mode  = Byte
    ; ext   = ".exe"
    ; flags = ["-custom"]
    }

  let native_or_custom (context : Context.t) =
    match context.ocamlopt with
    | None   -> custom
    | Some _ -> native

  let make ~mode ~ext ?(flags=[]) () =
    { mode
    ; ext
    ; flags
    }

  let  c_flags = ["-output-obj"]
  let  o_flags = ["-output-complete-obj"]
  let so_flags_windows = o_flags
  let so_flags_unix    = ["-output-complete-obj"; "-runtime-variant"; "_pic"]

  let of_user_config (ctx : Context.t) (m : Dune_file.Executables.Link_mode.t) =
    let wanted_mode : Mode.t =
      match m.mode with
      | Byte   -> Byte
      | Native -> Native
      | Best   -> Native
    in
    let real_mode : Mode.t =
      match m.mode with
      | Byte   -> Byte
      | Native -> Native
      | Best   -> if Option.is_some ctx.ocamlopt then Native else Byte
    in
    let ext =
      match wanted_mode, m.kind with
      | Byte   , C             -> ".bc.c"
      | Native , C             -> Errors.fail m.loc "C file generation only supports bytecode!"
      | Byte   , Exe           -> ".bc"
      | Native , Exe           -> ".exe"
      | Byte   , Object        -> ".bc"  ^ ctx.ext_obj
      | Native , Object        -> ".exe" ^ ctx.ext_obj
      | Byte   , Shared_object -> ".bc"  ^ ctx.ext_dll
      | Native , Shared_object ->          ctx.ext_dll
    in
    let flags =
      match m.kind with
      | C -> c_flags
      | Exe ->
        begin
          match wanted_mode, real_mode with
          | Native, Byte -> ["-custom"]
          | _ -> []
        end
      | Object -> o_flags
      | Shared_object ->
        let so_flags =
          if String.equal ctx.os_type "Win32" then
            so_flags_windows
          else
            so_flags_unix
        in
        match real_mode with
        | Native ->
          (* The compiler doesn't pass these flags in native mode. This
             looks like a bug in the compiler. *)
          List.concat_map ctx.native_c_libraries ~f:(fun flag ->
            ["-cclib"; flag])
          @ so_flags
        | Byte ->
          so_flags
    in
    { ext
    ; mode = real_mode
    ; flags
    }
end

let link_exe
      ~loc
      ~name
      ~(linkage:Linkage.t)
      ~top_sorted_modules
      ~arg_spec_for_requires
      ?(link_flags=Build.arr (fun _ -> []))
      ?(js_of_ocaml=Dune_file.Js_of_ocaml.default)
      cctx
  =
  let sctx     = CC.super_context cctx in
  let ctx      = SC.context       sctx in
  let dir      = CC.dir           cctx in
  let obj_dir  = CC.obj_dir       cctx in
  let requires = CC.requires      cctx in
  let mode = linkage.mode in
  let exe = Path.relative dir (name ^ linkage.ext) in
  let compiler = Option.value_exn (Context.compiler ctx mode) in
  let artifacts ~ext modules =
    List.map modules ~f:(Module.obj_file ~obj_dir ~ext)
  in
  let modules_and_cm_files =
    Build.memoize "cm files"
      (top_sorted_modules >>^ fun modules ->
       (modules,
        artifacts modules ~ext:(Cm_kind.ext (Mode.cm_kind mode))))
  in
  let register_native_objs_deps build =
    match mode with
    | Byte -> build
    | Native ->
      build >>>
      Build.dyn_paths (Build.arr (fun (modules, _) ->
        artifacts modules ~ext:ctx.ext_obj))
  in
  let arg_spec_for_requires =
    Lazy.force (Mode.Dict.get arg_spec_for_requires mode)
  in
  (* The rule *)
  SC.add_rule sctx ~loc ~dir
    (Build.fanout3
       (register_native_objs_deps modules_and_cm_files >>^ snd)
       (Ocaml_flags.get (CC.flags cctx) mode)
       link_flags
     >>>
     Build.of_result_map requires ~f:(fun libs ->
       Build.paths (Lib.L.archive_files libs ~mode))
     >>>
     Build.run ~dir:ctx.build_dir
       (Ok compiler)
       [ Dyn (fun (_, flags,_) -> As flags)
       ; A "-o"; Target exe
       ; As linkage.flags
       ; Dyn (fun (_, _, link_flags) -> As link_flags)
       ; Arg_spec.of_result_map arg_spec_for_requires ~f:(fun x -> x)
       ; Dyn (fun (cm_files, _, _) -> Deps cm_files)
       ]);
  if linkage.ext = ".bc" then
    let rules =
      Js_of_ocaml_rules.build_exe cctx ~js_of_ocaml ~src:exe
    in
    let cm_and_flags =
      Build.fanout
        (modules_and_cm_files >>^ snd)
        (SC.expand_and_eval_set sctx ~scope:(CC.scope cctx) ~dir
           js_of_ocaml.flags
           ~standard:(Build.return (Js_of_ocaml_rules.standard sctx)))
    in
    SC.add_rules ~dir sctx (List.map rules ~f:(fun r -> cm_and_flags >>> r))

let build_and_link_many
      ~programs
      ~linkages
      ?link_flags
      ?(js_of_ocaml=Dune_file.Js_of_ocaml.default)
      cctx
  =
  let dep_graphs = Ocamldep.rules cctx in

  (* CR-someday jdimino: this should probably say [~dynlink:false] *)
  Module_compilation.build_modules cctx ~js_of_ocaml ~dep_graphs;

  List.iter programs ~f:(fun { Program.name; main_module_name ; loc } ->
    let top_sorted_modules =
      let main = Option.value_exn
                   (Module.Name.Map.find (CC.modules cctx) main_module_name) in
      Ocamldep.Dep_graph.top_closed_implementations dep_graphs.impl
        [main]
    in
    let arg_spec_for_requires =
      Mode.Dict.of_func (fun ~mode ->
        lazy (Result.map (CC.requires cctx)
                ~f:(Link_time_code_gen.libraries_link ~loc ~name ~mode cctx)))
    in
    List.iter linkages ~f:(fun linkage ->
      link_exe cctx
        ~loc
        ~name
        ~linkage
        ~top_sorted_modules
        ~js_of_ocaml
        ~arg_spec_for_requires
        ?link_flags))

let build_and_link ~program =
  build_and_link_many ~programs:[program]
