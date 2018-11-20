open Import

module CC = Compilation_context
module SC = Super_context

let of_libs = List.map ~f:(fun l -> Lib.Lib_and_module.Lib l)

let rec cut_after_libs ~pkg_name before = function
  | [] -> None
  | a::l when Lib_name.compare (Lib.name a) pkg_name = Eq -> Some (List.rev (a::before),l)
  | a::l -> cut_after_libs (a::before) ~pkg_name l

let findlib_dynload = Lib_name.of_string_exn ~loc:None "findlib.dynload"

let libraries_link ~name ~loc ~mode cctx libs =
  let sctx       = CC.super_context cctx in
  let ctx        = SC.context       sctx in
  let obj_dir    = CC.obj_dir       cctx in
  let dir        = CC.dir           cctx in
  let stdlib_dir = ctx.stdlib_dir in
  match cut_after_libs [] ~pkg_name:findlib_dynload libs with
  | Some (before, after) ->
    (* If findlib.dynload is linked, we stores in the binary the packages linked by linking just
       after findlib.dynload a module containing the info *)
    let libs =
      List.filter
        ~f:(fun lib -> not (Lib_info.Status.is_private (Lib.status lib)))
        libs
    in
    let preds = Variant.Set.add Findlib.Package.preds (Mode.variant mode) in
    let s =
      Format.asprintf "%a@\nFindlib.record_package_predicates %a;;@."
        (Fmt.list ~pp_sep:Fmt.nl (fun fmt lib ->
           Format.fprintf fmt "Findlib.record_package Findlib.Record_core %a;;"
             Lib_name.pp_quoted (Lib.name lib)))
        libs
        (Fmt.ocaml_list Variant.pp) (Variant.Set.to_list preds)
    in
    let basename = Format.asprintf "%s_findlib_initl_%a" name Mode.pp mode in
    let ml  = Path.relative obj_dir (basename ^ ".ml") in
    SC.add_rule ~dir sctx (Build.write_file ml s);
    let impl = Module.File.make OCaml ml in
    let name = Module.Name.of_string basename in
    let module_ = Module.make ~impl name ~visibility:Public in
    let cctx = Compilation_context.(
      create
        ~super_context:sctx
        ~scope:(scope cctx)
        ~dir:(dir cctx)
        ~dir_kind:(dir_kind cctx)
        ~obj_dir:(obj_dir cctx)
        ~modules:(Module.Name.Map.singleton name module_)
        ~requires:(Lib.DB.find_many ~loc (SC.public_libs sctx)
                     [Lib_name.of_string_exn ~loc:(Some loc) "findlib"])
        ~flags:Ocaml_flags.empty
        ~opaque:true
        ())
    in
    Module_compilation.build_module
      ~dep_graphs:(Ocamldep.Dep_graphs.dummy module_)
      cctx
      module_;
    let lm = (of_libs before)@[Lib.Lib_and_module.Module (module_,obj_dir)]@(of_libs after) in
    Arg_spec.S [A "-linkall"; Lib.Lib_and_module.link_flags lm ~mode ~stdlib_dir]
  | None ->
    Lib.L.link_flags libs ~mode ~stdlib_dir
