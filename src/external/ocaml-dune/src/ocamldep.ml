open! Stdune
open Import
open Build.O

module CC = Compilation_context
module SC = Super_context

module Dep_graph = struct
  type t =
    { dir        : Path.t
    ; per_module : (Module.t * (unit, Module.t list) Build.t) Module.Name.Map.t
    }

  let deps_of t (m : Module.t) =
    let name = Module.name m in
    match Module.Name.Map.find t.per_module name with
    | Some (_, x) -> x
    | None ->
      Exn.code_error "Ocamldep.Dep_graph.deps_of"
        [ "dir", Path.to_sexp t.dir
        ; "modules", Sexp.Encoder.(list Module.Name.to_sexp)
                       (Module.Name.Map.keys t.per_module)
        ; "module", Module.Name.to_sexp name
        ]

  let pp_cycle fmt cycle =
    (Fmt.list ~pp_sep:Fmt.nl (Fmt.prefix (Fmt.string "-> ") Module.Name.pp))
      fmt (List.map cycle ~f:Module.name)

  let top_closed t modules =
    Module.Name.Map.to_list t.per_module
    |> List.map ~f:(fun (unit, (_module, deps)) ->
      deps >>^ fun deps -> (unit, deps))
    |> Build.all
    >>^ fun per_module ->
    let per_module = Module.Name.Map.of_list_exn per_module in
    match
      Module.Name.Top_closure.top_closure modules
        ~key:Module.name
        ~deps:(fun m ->
          Module.name m
          |> Module.Name.Map.find per_module
          |> Option.value_exn)
    with
    | Ok modules -> modules
    | Error cycle ->
      die "dependency cycle between modules in %s:\n   %a"
        (Path.to_string t.dir)
        pp_cycle cycle

  module Multi = struct
    let top_closed_multi (ts : t list) modules =
      List.concat_map ts ~f:(fun t ->
        Module.Name.Map.to_list t.per_module
        |> List.map ~f:(fun (_name, (unit, deps)) ->
          deps >>^ fun deps -> (unit, deps)))
      |> Build.all >>^ fun per_module ->
      let per_obj =
        Module.Obj_map.of_list_reduce per_module ~f:List.rev_append in
      match Module.Obj_map.top_closure per_obj modules with
      | Ok modules -> modules
      | Error cycle ->
        die "dependency cycle between modules\n   %a"
          pp_cycle cycle
  end

  let make_top_closed_implementations ~name ~f ts modules =
    Build.memoize name (
      let filter_out_intf_only = List.filter ~f:Module.has_impl in
      f ts (filter_out_intf_only modules)
      >>^ filter_out_intf_only)

  let top_closed_multi_implementations =
    make_top_closed_implementations
      ~name:"top sorted multi implementations" ~f:Multi.top_closed_multi

  let top_closed_implementations =
    make_top_closed_implementations
      ~name:"top sorted implementations" ~f:top_closed

  let dummy (m : Module.t) =
    { dir = Path.root
    ; per_module =
        Module.Name.Map.singleton (Module.name m) (m, (Build.return []))
    }

  let wrapped_compat ~modules ~wrapped_compat =
    { dir = Path.root
    ; per_module = Module.Name.Map.merge wrapped_compat modules ~f:(fun _ d m ->
        match d, m with
        | None, None -> assert false
        | Some wrapped_compat, None ->
          Exn.code_error "deprecated module needs counterpart"
            [ "deprecated", Module.to_sexp wrapped_compat
            ]
        | None, Some _ -> None
        | Some _, Some m -> Some (m, (Build.return [m]))
      )
    }
end

module Dep_graphs = struct
  type t = Dep_graph.t Ml_kind.Dict.t

  let dummy m =
    Ml_kind.Dict.make_both (Dep_graph.dummy m)

  let wrapped_compat ~modules ~wrapped_compat =
    Ml_kind.Dict.make_both (Dep_graph.wrapped_compat ~modules ~wrapped_compat)

  let merge_impl ~(ml_kind : Ml_kind.t) _ vlib impl =
    match vlib, impl with
    | None, None -> assert false
    | Some _, None -> None (* we don't care about internal vlib deps *)
    | None, Some d -> Some d
    | Some (mv, _), Some (mi, i) ->
      if Module.obj_name mv = Module.obj_name mi
      && Module.intf_only mv
      && Module.impl_only mi then
        match ml_kind with
        | Impl -> Some (mi, i)
        | Intf -> None
      else if Module.is_private mv || Module.is_private mi then
        Some (mi, i)
      else
        let open Sexp.Encoder in
        Exn.code_error "merge_impl: unexpected dep graph"
          [ "ml_kind", string (Ml_kind.to_string ml_kind)
          ; "mv", Module.to_sexp mv
          ; "mi", Module.to_sexp mi
          ]

  let merge_for_impl ~(vlib : t) ~(impl : t) =
    Ml_kind.Dict.of_func (fun ~ml_kind ->
      let impl = Ml_kind.Dict.get impl ml_kind in
      { impl with
        per_module =
          Module.Name.Map.merge ~f:(merge_impl ~ml_kind)
            (Ml_kind.Dict.get vlib ml_kind).per_module
            impl.per_module
      })
end

let is_alias_module cctx (m : Module.t) =
  let open Module.Name.Infix in
  match CC.alias_module cctx with
  | None -> false
  | Some alias -> Module.name alias = Module.name m

let parse_module_names ~(unit : Module.t) ~modules ~modules_of_vlib words =
  let open Module.Name.Infix in
  List.filter_map words ~f:(fun m ->
    let m = Module.Name.of_string m in
    if m = Module.name unit then
      None
    else
      match Module.Name.Map.find modules m with
      | Some _ as m -> m
      | None -> Module.Name.Map.find modules_of_vlib m)

let parse_deps cctx ~file ~unit lines =
  let dir                  = CC.dir                  cctx in
  let alias_module         = CC.alias_module         cctx in
  let lib_interface_module = CC.lib_interface_module cctx in
  let modules              = CC.modules              cctx in
  let modules_of_vlib      = CC.modules_of_vlib      cctx in
  let invalid () =
    die "ocamldep returned unexpected output for %s:\n\
         %s"
      (Path.to_string_maybe_quoted file)
      (String.concat ~sep:"\n"
         (List.map lines ~f:(sprintf "> %s")))
  in
  match lines with
  | [] | _ :: _ :: _ -> invalid ()
  | [line] ->
    match String.lsplit2 line ~on:':' with
    | None -> invalid ()
    | Some (basename, deps) ->
      let basename = Filename.basename basename in
      if basename <> Path.basename file then invalid ();
      let deps =
        String.extract_blank_separated_words deps
        |> parse_module_names ~unit ~modules ~modules_of_vlib
      in
      let stdlib = CC.stdlib cctx in
      let deps =
        match stdlib, CC.lib_interface_module cctx with
        | Some { modules_before_stdlib; _ }, Some m
          when Module.name unit = Module.name m ->
          (* See comment in [Dune_file.Stdlib]. *)
          List.filter deps ~f:(fun m ->
            Module.Name.Set.mem modules_before_stdlib (Module.name m))
        | _ -> deps
      in
      if Option.is_none stdlib then
        Option.iter lib_interface_module ~f:(fun (m : Module.t) ->
          let m = Module.name m in
          let open Module.Name.Infix in
          if Module.name unit <> m
          && not (is_alias_module cctx unit)
          && List.exists deps ~f:(fun x -> Module.name x = m) then
            die "Module %a in directory %s depends on %a.\n\
                 This doesn't make sense to me.\n\
                 \n\
                 %a is the main module of the library and is \
                 the only module exposed \n\
                 outside of the library. Consequently, it should \
                 be the one depending \n\
                 on all the other modules in the library."
              Module.Name.pp (Module.name unit) (Path.to_string dir)
              Module.Name.pp m
              Module.Name.pp m);
      match stdlib with
      | None -> begin
          match alias_module with
          | None -> deps
          | Some m -> m :: deps
        end
      | Some { modules_before_stdlib; _ } ->
        if Module.Name.Set.mem modules_before_stdlib (Module.name unit) then
          deps
        else
          match CC.lib_interface_module cctx with
          | None -> deps
          | Some m ->
            if Module.name unit = Module.name m then
              deps
            else
              m :: deps

let deps_of cctx ~ml_kind unit =
  let sctx = CC.super_context cctx in
  if is_alias_module cctx unit then
    Build.return []
  else
    match Module.file unit ml_kind with
    | None -> Build.return []
    | Some file ->
      let file_in_obj_dir ~suffix file =
        let base = Path.basename file in
        Path.relative (Compilation_context.obj_dir cctx) (base ^ suffix)
      in
      let all_deps_path file = file_in_obj_dir file ~suffix:".all-deps" in
      let context = SC.context sctx in
      let modules_of_vlib = Compilation_context.modules_of_vlib cctx in
      let all_deps_file = all_deps_path file in
      let ocamldep_output = file_in_obj_dir file ~suffix:".d" in
      SC.add_rule sctx ~dir:(Compilation_context.dir cctx)
        (let flags =
           Option.value (Module.pp_flags unit) ~default:(Build.return []) in
         flags >>>
         Build.run (Ok context.ocamldep) ~dir:context.build_dir
           [ A "-modules"
           ; Dyn (fun flags -> As flags)
           ; Ml_kind.flag ml_kind
           ; Dep file
           ]
           ~stdout_to:ocamldep_output
        );
      let build_paths dependencies =
        let dependency_file_path m =
          let file_path m =
            if is_alias_module cctx m then
              None
            else
              match Module.file m Ml_kind.Intf with
              | Some _ as x -> x
              | None ->
                Module.file m Ml_kind.Impl
          in
          let module_file_ =
            match file_path m with
            | Some v -> Some v
            | None ->
              Module.name m
              |> Module.Name.Map.find modules_of_vlib
              |> Option.bind ~f:file_path
          in
          Option.map ~f:all_deps_path module_file_
        in
        List.filter_map dependencies ~f:dependency_file_path
      in
      SC.add_rule sctx ~dir:(Compilation_context.dir cctx)
        ( Build.lines_of ocamldep_output
          >>^ parse_deps cctx ~file ~unit
          >>^ (fun modules ->
            (build_paths modules,
             List.map modules ~f:(fun m ->
               Module.Name.to_string (Module.name m))
            ))
          >>> Build.merge_files_dyn ~target:all_deps_file);
      Build.memoize (Path.to_string all_deps_file)
        ( Build.lines_of all_deps_file
          >>^ parse_module_names
                ~modules_of_vlib ~unit ~modules:(CC.modules cctx))

let rules_generic cctx ~modules =
  Ml_kind.Dict.of_func
    (fun ~ml_kind ->
       let per_module =
         Module.Name.Map.map modules ~f:(fun m -> (m, deps_of cctx ~ml_kind m))
       in
       { Dep_graph.
         dir = CC.dir cctx
       ; per_module
       })

let rules cctx = rules_generic cctx ~modules:(CC.modules cctx)

let rules_for_auxiliary_module cctx (m : Module.t) =
  rules_generic cctx ~modules:(Module.Name.Map.singleton (Module.name m) m)

let graph_of_remote_lib ~obj_dir ~modules =
  let deps_of unit ~ml_kind =
    match Module.file unit ml_kind with
    | None -> Build.return []
    | Some file ->
      let file_in_obj_dir ~suffix file =
        let base = Path.basename file in
        Path.relative obj_dir (base ^ suffix)
      in
      let all_deps_path file = file_in_obj_dir file ~suffix:".all-deps" in
      let all_deps_file = all_deps_path file in
      Build.memoize (Path.to_string all_deps_file)
        (Build.lines_of all_deps_file
         >>^ parse_module_names ~unit ~modules
               ~modules_of_vlib:Module.Name.Map.empty)
  in
  Ml_kind.Dict.of_func (fun ~ml_kind ->
    let per_module =
      Module.Name.Map.map modules ~f:(fun m -> (m, deps_of ~ml_kind m)) in
    { Dep_graph.
      dir = obj_dir
    ; per_module
    })
