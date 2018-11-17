open Import

let flag_of_kind : Ml_kind.t -> _ =
  function
  | Impl -> "--impl"
  | Intf -> "--intf"

let config_includes (config : Dune_file.Auto_format.t) s =
  match config.enabled_for with
  | Default -> true
  | Only set -> List.mem s ~set

let add_diff sctx loc alias ~dir input output =
  let module SC = Super_context in
  let open Build.O in
  let action = Action.diff input output in
  SC.add_alias_action sctx alias ~dir ~loc:(Some loc) ~locks:[] ~stamp:input
    (Build.paths [input; output]
     >>>
     Build.action
       ~dir
       ~targets:[]
       action)

let rec subdirs_until_root dir =
  match Path.parent dir with
  | None -> [dir]
  | Some d -> dir :: subdirs_until_root d

let depend_on_existing_paths paths =
  let open Build.O in
  let build_id = Build.arr (fun x -> x) in
  List.fold_left
    ~f:(fun acc path ->
      Build.if_file_exists
        path
        ~then_:(Build.path path)
        ~else_:build_id
      >>>
      acc)
    ~init:build_id
    paths

let depend_on_files ~named dir =
  subdirs_until_root dir
  |> List.map ~f:(fun dir -> Path.relative dir named)
  |> depend_on_existing_paths

let gen_rules sctx (config : Dune_file.Auto_format.t) ~dir =
  let loc = config.loc in
  let source_dir = Path.drop_build_context_exn dir in
  let files = File_tree.files_of (Super_context.file_tree sctx) source_dir in
  let subdir = ".formatted" in
  let output_dir = Path.relative dir subdir in
  let alias = Build_system.Alias.fmt ~dir in
  let alias_formatted = Build_system.Alias.fmt ~dir:output_dir in
  let resolve_program =
    Super_context.resolve_program ~dir sctx ~loc:(Some loc) in
  let ocamlformat_deps =
    lazy (depend_on_files ~named:".ocamlformat" source_dir)
  in
  let setup_formatting file =
    let open Build.O in
    let input_basename = Path.basename file in
    let input = Path.relative dir input_basename in
    let output = Path.relative output_dir input_basename in

    let ocaml kind =
      if config_includes config Ocaml then
        let exe = resolve_program "ocamlformat" in
        let args =
          let open Arg_spec in
          [ A (flag_of_kind kind)
          ; Dep input
          ; A "--name"
          ; Path file
          ; A "-o"
          ; Target output
          ]
        in
        Some (Lazy.force ocamlformat_deps >>> Build.run ~dir exe args)
      else
        None
    in

    let formatter =
      match Path.extension file with
      | ".ml" -> ocaml Impl
      | ".mli" -> ocaml Intf
      | ".re"
      | ".rei" when config_includes config Reason ->
        let exe = resolve_program "refmt" in
        let args = [Arg_spec.Dep input] in
        Some (Build.run ~dir ~stdout_to:output exe args)
      | _ -> None
    in

    Option.iter
      formatter
      ~f:(fun arr ->
          Super_context.add_rule sctx ~mode:Standard ~loc ~dir arr;
          add_diff sctx loc alias_formatted ~dir input output)
  in
  Super_context.on_load_dir
    sctx
    ~dir:output_dir
    ~f:(fun () -> Path.Set.iter files ~f:setup_formatting);
  Super_context.add_alias_deps sctx alias
    (Path.Set.singleton (Build_system.Alias.stamp_file alias_formatted));
  Super_context.add_alias_deps sctx alias_formatted Path.Set.empty
