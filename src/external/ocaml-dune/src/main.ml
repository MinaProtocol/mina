open! Stdune
open Import
open Fiber.O

let () = Inline_tests.linkme

type setup =
  { build_system : Build_system.t
  ; contexts     : Context.t list
  ; scontexts    : Super_context.t String.Map.t
  ; packages     : Package.t Package.Name.Map.t
  ; file_tree    : File_tree.t
  ; env          : Env.t
  }

let package_install_file { packages; _ } pkg =
  match Package.Name.Map.find packages pkg with
  | None -> Error ()
  | Some p ->
    Ok (Path.relative p.path
          (Utils.install_file ~package:p.name ~findlib_toolchain:None))

let setup_env ~capture_outputs =
  let env =
    if capture_outputs || not (Lazy.force Colors.stderr_supports_colors) then
      Env.initial
    else
      Colors.setup_env_for_colors Env.initial
  in
  Env.add env ~var:"INSIDE_DUNE" ~value:"1"

let setup ?(log=Log.no_log)
      ?external_lib_deps_mode
      ?workspace ?workspace_file
      ?only_packages
      ?extra_ignored_subtrees
      ?x
      ?ignore_promoted_rules
      ?(capture_outputs=true)
      ?profile
      () =
  let env = setup_env ~capture_outputs in
  let conf =
    Dune_load.load ?extra_ignored_subtrees ?ignore_promoted_rules ()
  in
  Option.iter only_packages ~f:(fun set ->
    Package.Name.Set.iter set ~f:(fun pkg ->
      if not (Package.Name.Map.mem conf.packages pkg) then
        let pkg_name = Package.Name.to_string pkg in
        die "@{<error>Error@}: I don't know about package %s \
             (passed through --only-packages/--release)%s"
          pkg_name
          (hint pkg_name
             (Package.Name.Map.keys conf.packages
             |> List.map ~f:Package.Name.to_string))));
  let workspace =
    match workspace with
    | Some w -> w
    | None ->
      match workspace_file with
      | Some p ->
        if not (Path.exists p) then
          die "@{<error>Error@}: workspace file %s does not exist"
            (Path.to_string_maybe_quoted p);
        Workspace.load ?x ?profile p
      | None ->
        match
          let p = Path.of_string Workspace.filename in
          Option.some_if (Path.exists p) p
        with
        | Some p -> Workspace.load ?x ?profile p
        | None -> Workspace.default ?x ?profile ()
  in

  Context.create ~env workspace
  >>= fun contexts ->
  List.iter contexts ~f:(fun (ctx : Context.t) ->
    Log.infof log "@[<1>Dune context:@,%a@]@." Sexp.pp
      (Context.to_sexp ctx));
  let rule_done  = ref 0 in
  let rule_total = ref 0 in
  let gen_status_line () =
    { Scheduler.
      message = Some (sprintf "Done: %u/%u" !rule_done !rule_total)
    ; show_jobs = true
    }
  in
  let hook (hook : Build_system.hook) =
    match hook with
    | Rule_started   -> incr rule_total
    | Rule_completed -> incr rule_done
  in
  let build_system =
    Build_system.create ~contexts ~file_tree:conf.file_tree ~hook
  in
  Gen_rules.gen conf
    ~build_system
    ~contexts
    ?only_packages
    ?external_lib_deps_mode
  >>= fun scontexts ->
  Scheduler.set_status_line_generator gen_status_line
  >>>
  Fiber.return
    { build_system
    ; scontexts
    ; contexts
    ; packages = conf.packages
    ; file_tree = conf.file_tree
    ; env
    }

let find_context_exn t ~name =
  match List.find t.contexts ~f:(fun c -> c.name = name) with
  | Some ctx -> ctx
  | None ->
    die "@{<Error>Error@}: Context %S not found!@." name

let external_lib_deps ?log ~packages () =
  Scheduler.go ?log
    (setup () ~external_lib_deps_mode:true
     >>| fun setup ->
     let context = find_context_exn setup ~name:"default" in
     let install_files =
       List.map packages ~f:(fun pkg ->
         match package_install_file setup pkg with
         | Ok path -> Path.append context.build_dir path
         | Error () -> die "Unknown package %S" (Package.Name.to_string pkg))
     in
     let sctx = Option.value_exn (String.Map.find setup.scontexts "default") in
     let internals = Super_context.internal_lib_names sctx in
     Path.Map.map
       (Build_system.all_lib_deps setup.build_system
          ~request:(Build.paths install_files))
       ~f:(Lib_name.Map.filteri ~f:(fun name _ ->
         not (Lib_name.Set.mem internals name))))

let ignored_during_bootstrap =
  Path.Set.of_list
    (List.map ~f:Path.in_source
       [ "test"
       ; "example"
       ])

let auto_concurrency =
  let v = ref None in
  fun ?(log=Log.no_log) () ->
    match !v with
    | Some n -> Fiber.return n
    | None ->
      (if Sys.win32 then
         match Env.get Env.initial "NUMBER_OF_PROCESSORS" with
         | None -> Fiber.return 1
         | Some s ->
           match int_of_string s with
           | exception _ -> Fiber.return 1
           | n -> Fiber.return n
       else
         let commands =
           [ "nproc", []
           ; "getconf", ["_NPROCESSORS_ONLN"]
           ; "getconf", ["NPROCESSORS_ONLN"]
           ]
         in
         let rec loop = function
           | [] -> Fiber.return 1
           | (prog, args) :: rest ->
             match Bin.which ~path:(Env.path Env.initial) prog with
             | None -> loop rest
             | Some prog ->
               Process.run_capture (Accept All) prog args ~env:Env.initial
                 ~stderr_to:(File Config.dev_null)
               >>= function
               | Error _ -> loop rest
               | Ok s ->
                 match int_of_string (String.trim s) with
                 | n -> Fiber.return n
                 | exception _ -> loop rest
         in
         loop commands)
      >>| fun n ->
      Log.infof log "Auto-detected concurrency: %d" n;
      v := Some n;
      n

let set_concurrency ?log (config : Config.t) =
  (match config.concurrency with
   | Fixed n -> Fiber.return n
   | Auto    -> auto_concurrency ?log ())
  >>= fun n ->
  if n >= 1 then
    Scheduler.set_concurrency n
  else
    Fiber.return ()

(* Called by the script generated by ../build.ml *)
let bootstrap () =
  Colors.setup_err_formatter_colors ();
  Path.set_root Path.External.initial_cwd;
  Path.set_build_dir (Path.Kind.of_string "_build");
  let main () =
    let anon s = raise (Arg.Bad (Printf.sprintf "don't know what to do with %s\n" s)) in
    let subst () =
      let config : Config.t =
        { display     = Quiet
        ; concurrency = Fixed 1
        }
      in
      Scheduler.go ~config (Watermarks.subst ());
      exit 0
    in
    let display = ref None in
    let display_mode =
      Arg.Symbol
        (List.map Config.Display.all ~f:fst,
         fun s ->
           display := List.assoc Config.Display.all s)
    in
    let concurrency = ref None in
    let concurrency_arg x =
      match Config.Concurrency.of_string x with
      | Error msg -> raise (Arg.Bad msg)
      | Ok c -> concurrency := Some c
    in
    let profile = ref None in
    Arg.parse
      [ "-j"           , String concurrency_arg, "JOBS concurrency"
      ; "--release"        , Unit (fun () -> profile := Some "release"),
        " set release mode"
      ; "--display"    , display_mode          , " set the display mode"
      ; "--subst"      , Unit subst            ,
        " substitute watermarks in source files"
      ; "--debug-backtraces",
        Set Clflags.debug_backtraces,
        " always print exception backtraces"
      ]
      anon "Usage: boot.exe [-j JOBS] [--dev]\nOptions are:";
    Clflags.debug_dep_path := true;
    let config =
      (* Only load the configuration with --dev *)
      if !profile <> Some "release" then
        Config.load_user_config_file ()
      else
        Config.default
    in
    let config =
      Config.merge config
        { display     = !display
        ; concurrency = !concurrency
        }
    in
    let config =
      Config.adapt_display config
        ~output_is_a_tty:(Lazy.force Colors.stderr_supports_colors)
    in
    let log = Log.create ~display:config.display () in
    Scheduler.go ~log ~config
      (set_concurrency config
       >>= fun () ->
       setup ~log ~workspace:(Workspace.default ?profile:!profile ())
         ?profile:!profile
         ~extra_ignored_subtrees:ignored_during_bootstrap
         ()
       >>= fun { build_system = bs; _ } ->
       Build_system.do_build bs
         ~request:(Build.path (
           Path.relative Path.build_dir "default/dune.install")))
  in
  try
    main ()
  with
  | Fiber.Never -> exit 1
  | exn ->
    Report_error.report exn;
    exit 1

let setup = setup ~extra_ignored_subtrees:Path.Set.empty

let find_context_exn t ~name =
  match List.find t.contexts ~f:(fun c -> c.name = name) with
  | Some ctx -> ctx
  | None ->
    die "@{<Error>Error@}: Context %S not found!@." name
