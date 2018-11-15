open! Stdune
open Dune
open Import
module Term = Cmdliner.Term
module Manpage = Cmdliner.Manpage
open Fiber.O

(* Things in src/ don't depend on cmdliner to speed up the
   bootstrap, so we set this reference here *)
let () = suggest_function := Cmdliner_suggest.value

module Let_syntax = Cmdliner.Term

let restore_cwd_and_execve (common : Common.t) prog argv env =
  let prog =
    if Filename.is_relative prog then
      Filename.concat common.root prog
    else
      prog
  in
  Proc.restore_cwd_and_execve prog argv ~env

module Main = struct
  include Dune.Main

  let setup ~log ?external_lib_deps_mode (common : Common.t) =
    setup
      ~log
      ?workspace_file:(Option.map ~f:Arg.Path.path common.workspace_file)
      ?only_packages:common.only_packages
      ?external_lib_deps_mode
      ?x:common.x
      ?profile:common.profile
      ~ignore_promoted_rules:common.ignore_promoted_rules
      ~capture_outputs:common.capture_outputs
      ()
end

module Log = struct
  include Dune.Log

  let create (common : Common.t) =
    Log.create ~display:common.config.display ()
end

module Scheduler = struct
  include Dune.Scheduler

  let go ?log ~(common : Common.t) fiber =
    let fiber =
      Main.set_concurrency ?log common.config
      >>= fun () ->
      fiber
    in
    Scheduler.go ?log ~config:common.config fiber

  let poll ?log ~(common : Common.t) ~once ~finally () =
    let once () =
      Main.set_concurrency ?log common.config
      >>= fun () ->
      once ()
    in
    Scheduler.poll ?log ~config:common.config ~once ~finally ()
end

let do_build (setup : Main.setup) targets =
  Build_system.do_build setup.build_system
    ~request:(Target.request setup targets)

let installed_libraries =
  let doc = "Print out libraries installed on the system." in
  let term =
    let%map common = Common.term
    and na =
      Arg.(value
           & flag
           & info ["na"; "not-available"]
               ~doc:"List libraries that are not available and explain why")
    in
    Common.set_common common ~targets:[];
    let env = Main.setup_env ~capture_outputs:common.capture_outputs in
    Scheduler.go ~log:(Log.create common) ~common
      (Context.create ~env
         { merlin_context = Some "default"
         ; contexts = [Default { loc = Loc.of_pos __POS__
                               ; targets   = [Native]
                               ; profile   = Config.default_build_profile
                               ; env       = None
                               ; toolchain = None
                               }]
         ; env = None
         }
       >>= fun ctxs ->
       let ctx = List.hd ctxs in
       let findlib = ctx.findlib in
       if na then begin
         let pkgs = Findlib.all_unavailable_packages findlib in
         let longest =
           String.longest_map pkgs ~f:(fun (n, _) -> Lib_name.to_string n) in
         let ppf = Format.std_formatter in
         List.iter pkgs ~f:(fun (n, r) ->
           Format.fprintf ppf "%-*s -> %a@\n" longest (Lib_name.to_string n)
             Findlib.Unavailable_reason.pp r);
         Format.pp_print_flush ppf ();
         Fiber.return ()
       end else begin
         let pkgs = Findlib.all_packages findlib in
         let max_len = String.longest_map pkgs ~f:(fun n ->
           Findlib.Package.name n
           |> Lib_name.to_string) in
         List.iter pkgs ~f:(fun pkg ->
           let ver =
             Option.value (Findlib.Package.version pkg) ~default:"n/a"
           in
           Printf.printf "%-*s (version: %s)\n" max_len
             (Lib_name.to_string (Findlib.Package.name pkg)) ver);
         Fiber.return ()
       end)
  in
  (term, Term.info "installed-libraries" ~doc)

let resolve_package_install setup pkg =
  match Main.package_install_file setup pkg with
  | Ok path -> path
  | Error () ->
    let pkg = Package.Name.to_string pkg in
    die "Unknown package %s!%s" pkg
      (hint pkg
         (Package.Name.Map.keys setup.packages
          |> List.map ~f:Package.Name.to_string))

let run_build_command ~log ~common ~targets =
  let once () =
    Main.setup ~log common
    >>= fun setup ->
    do_build setup (targets setup)
  in
  let finally () =
    Hooks.End_of_build.run ();
    Hooks.End_of_build_not_canceled.run ()
  in
  let canceled () =
    Hooks.End_of_build.run ();
    Hooks.End_of_build_not_canceled.clear ()
  in
  if common.watch then begin
    Scheduler.poll ~log ~common ~once ~finally ~canceled ()
  end
  else Scheduler.go ~log ~common (once ())

let build_targets =
  let doc = "Build the given targets, or all installable targets if none are given." in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|Targets starting with a $(b,@) are interpreted as aliases.|}
    ; `Blocks Common.help_secs
    ]
  in
  let name_ = Arg.info [] ~docv:"TARGET" in
  let default_target =
    match Which_program.t with
    | Dune     -> "@@default"
    | Jbuilder -> "@install"
  in
  let term =
    let%map common = Common.term
    and targets = Arg.(value & pos_all string [default_target] name_)
    in
    Common.set_common common ~targets;
    let log = Log.create common in
    let targets setup = Target.resolve_targets_exn ~log common setup targets in
    run_build_command ~log ~common ~targets
  in
  (term, Term.info "build" ~doc ~man)

let runtest =
  let doc = "Run tests." in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|This is a short-hand for calling:|}
    ; `Pre {|  dune build @runtest|}
    ; `Blocks Common.help_secs
    ]
  in
  let name_ = Arg.info [] ~docv:"DIR" in
  let term =
    let%map common = Common.term
    and dirs = Arg.(value & pos_all string ["."] name_)
    in
    Common.set_common common
      ~targets:(List.map dirs ~f:(function
        | "" | "." -> "@runtest"
        | dir when dir.[String.length dir - 1] = '/' -> sprintf "@%sruntest" dir
        | dir -> sprintf "@%s/runtest" dir));
    let log = Log.create common in
    let targets (setup : Main.setup) =
      List.map dirs ~f:(fun dir ->
        let dir = Path.(relative root) (Common.prefix_target common dir) in
        Target.Alias (Alias.in_dir ~name:"runtest" ~recursive:true
                        ~contexts:setup.contexts dir))
    in
    run_build_command ~log ~common ~targets
  in
  (term, Term.info "runtest" ~doc ~man)

let clean =
  let doc = "Clean the project." in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|Removes files added by dune such as _build, <package>.install, and .merlin|}
    ; `Blocks Common.help_secs
    ]
  in
  let term =
    let%map common = Common.term
    in
    Common.set_common common ~targets:[];
    Build_system.files_in_source_tree_to_delete ()
    |> Path.Set.iter ~f:Path.unlink_no_err;
    Path.rm_rf Path.build_dir
  in
  (term, Term.info "clean" ~doc ~man)

let format_external_libs libs =
  Lib_name.Map.to_list libs
  |> List.map ~f:(fun (name, kind) ->
    match (kind : Lib_deps_info.Kind.t) with
    | Optional -> sprintf "- %s (optional)" (Lib_name.to_string name)
    | Required -> sprintf "- %s" (Lib_name.to_string name))
  |> String.concat ~sep:"\n"

let external_lib_deps =
  let doc = "Print out external libraries needed to build the given targets." in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|Print out the external libraries needed to build the given targets.|}
    ; `P {|The output of $(b,jbuild external-lib-deps @install) should be included
           in what is written in your $(i,<package>.opam) file.|}
    ; `Blocks Common.help_secs
    ]
  in
  let term =
    let%map common = Common.term
    and only_missing =
      Arg.(value
           & flag
           & info ["missing"]
               ~doc:{|Only print out missing dependencies|})
    and targets =
      Arg.(non_empty
           & pos_all string []
           & Arg.info [] ~docv:"TARGET")
    in
    Common.set_common common ~targets:[];
    let log = Log.create common in
    Scheduler.go ~log ~common
      (Main.setup ~log common ~external_lib_deps_mode:true
       >>= fun setup ->
       let targets = Target.resolve_targets_exn ~log common setup targets in
       let request = Target.request setup targets in
       let failure =
         String.Map.foldi ~init:false
           (Build_system.all_lib_deps_by_context setup.build_system ~request)
           ~f:(fun context_name lib_deps acc ->
             let internals =
               Super_context.internal_lib_names
                 (match String.Map.find setup.Main.scontexts context_name with
                  | None -> assert false
                  | Some x -> x)
             in
             let externals =
               Lib_name.Map.filteri lib_deps ~f:(fun name _ ->
                 not (Lib_name.Set.mem internals name))
             in
             if only_missing then begin
               let context =
                 List.find_exn setup.contexts ~f:(fun c -> c.name = context_name)
               in
               let missing =
                 Lib_name.Map.filteri externals ~f:(fun name _ ->
                   not (Findlib.available context.findlib name))
               in
               if Lib_name.Map.is_empty missing then
                 acc
               else if Lib_name.Map.for_alli missing
                         ~f:(fun _ kind -> kind = Lib_deps_info.Kind.Optional)
               then begin
                 Format.eprintf
                   "@{<error>Error@}: The following libraries are missing \
                    in the %s context:\n\
                    %s@."
                   context_name
                   (format_external_libs missing);
                 false
               end else begin
                 Format.eprintf
                   "@{<error>Error@}: The following libraries are missing \
                    in the %s context:\n\
                    %s\n\
                    Hint: try: opam install %s@."
                   context_name
                   (format_external_libs missing)
                   (Lib_name.Map.to_list missing
                    |> List.filter_map ~f:(fun (name, kind) ->
                      match (kind : Lib_deps_info.Kind.t) with
                      | Optional -> None
                      | Required -> Some (Lib_name.package_name name))
                    |> Package.Name.Set.of_list
                    |> Package.Name.Set.to_list
                    |> List.map ~f:Package.Name.to_string
                    |> String.concat ~sep:" ");
                 true
               end
             end else begin
               Printf.printf
                 "These are the external library dependencies in the %s context:\n\
                  %s\n%!"
                 context_name
                 (format_external_libs externals);
               acc
             end)
       in
       if failure then raise Already_reported;
       Fiber.return ())
  in
  (term, Term.info "external-lib-deps" ~doc ~man)

let rules =
  let doc = "Dump internal rules." in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|Dump Dune internal rules for the given targets.
           If no targets are given, dump all the internal rules.|}
    ; `P {|By default the output is a list of S-expressions,
           one S-expression per rule. Each S-expression is of the form:|}
    ; `Pre "  ((deps    (<dependencies>))\n\
           \   (targets (<targets>))\n\
           \   (context <context-name>)\n\
           \   (action  <action>))"
    ; `P {|$(b,<context-name>) is the context is which the action is executed.
           It is omitted if the action is independent from the context.|}
    ; `P {|$(b,<action>) is the action following the same syntax as user actions,
           as described in the manual.|}
    ; `Blocks Common.help_secs
    ]
  in
  let term =
    let%map common = Common.term
    and out =
      Arg.(value
           & opt (some string) None
           & info ["o"] ~docv:"FILE"
               ~doc:"Output to a file instead of stdout.")
    and recursive =
      Arg.(value
           & flag
           & info ["r"; "recursive"]
               ~doc:"Print all rules needed to build the transitive \
                     dependencies of the given targets.")
    and makefile_syntax =
      Arg.(value
           & flag
           & info ["m"; "makefile"]
               ~doc:"Output the rules in Makefile syntax.")
    and targets =
      Arg.(value
           & pos_all string []
           & Arg.info [] ~docv:"TARGET")
    in
    let out = Option.map ~f:Path.of_string out in
    Common.set_common common ~targets;
    let log = Log.create common in
    Scheduler.go ~log ~common
      (Main.setup ~log common ~external_lib_deps_mode:true
       >>= fun setup ->
       let request =
         match targets with
         | [] -> Build.paths (Build_system.all_targets setup.build_system)
         | _  ->
           Target.resolve_targets_exn ~log common setup targets
           |> Target.request setup
       in
       Build_system.build_rules setup.build_system ~request ~recursive >>= fun rules ->
       let sexp_of_action action =
         Action.for_shell action |> Action.For_shell.encode
       in
       let print oc =
         let ppf = Format.formatter_of_out_channel oc in
         Dune_lang.prepare_formatter ppf;
         Format.pp_open_vbox ppf 0;
         if makefile_syntax then begin
           List.iter rules ~f:(fun (rule : Build_system.Rule.t) ->
             let action =
               Action.For_shell.Progn
                 [ Mkdir (Path.to_string rule.dir)
                 ; Action.for_shell rule.action
                 ]
             in
             Format.fprintf ppf
               "@[<hov 2>@{<makefile-stuff>%a:%t@}@]@,\
                @<0>\t@{<makefile-action>%a@}@,@,"
               (Format.pp_print_list ~pp_sep:Format.pp_print_space (fun ppf p ->
                  Format.pp_print_string ppf (Path.to_string p)))
               (Path.Set.to_list rule.targets)
               (fun ppf ->
                  Path.Set.iter (Deps.paths rule.deps) ~f:(fun dep ->
                    Format.fprintf ppf "@ %s" (Path.to_string dep)))
               Pp.pp
               (Action_to_sh.pp action))
         end else begin
           List.iter rules ~f:(fun (rule : Build_system.Rule.t) ->
             let sexp =
               let paths ps =
                 Dune_lang.Encoder.list Path_dune_lang.encode (Path.Set.to_list ps)
               in
               Dune_lang.Encoder.record (
                 List.concat
                   [ [ "deps"   , Deps.to_sexp rule.deps
                     ; "targets", paths rule.targets ]
                   ; (match rule.context with
                      | None -> []
                      | Some c -> ["context",
                                   Dune_lang.atom_or_quoted_string c.name])
                   ; [ "action" , sexp_of_action rule.action ]
                   ])
             in
             Format.fprintf ppf "%a@," Dune_lang.pp_split_strings sexp)
         end;
         Format.pp_print_flush ppf ();
         Fiber.return ()
       in
       match out with
       | None -> print stdout
       | Some fn -> Io.with_file_out fn ~f:print)
  in
  (term, Term.info "rules" ~doc ~man)

let interpret_destdir ~destdir path =
  match destdir with
  | None ->
    path
  | Some prefix ->
    Path.append_local
      (Path.of_string prefix)
      (Path.local_part path)

let get_dirs context ~prefix_from_command_line ~libdir_from_command_line =
  match prefix_from_command_line with
  | Some p ->
    let prefix = Path.of_string p in
    let dir = Option.value ~default:"lib" libdir_from_command_line in
    Fiber.return (prefix, Some (Path.relative prefix dir))
  | None ->
    Context.install_prefix context >>= fun prefix ->
    let libdir =
      match libdir_from_command_line with
      | None -> Context.install_ocaml_libdir context
      | Some l -> Fiber.return (Some (Path.relative prefix l))
    in
    libdir >>| fun libdir ->
    (prefix, libdir)

let print_unix_error f =
  try
    f ()
  with Unix.Unix_error (e, _, _) ->
    Format.eprintf "@{<error>Error@}: %s@."
      (Unix.error_message e)

let set_executable_bits   x = x lor  0o111
let clear_executable_bits x = x land (lnot 0o111)

(** Operations that act on real files or just pretend to (for --dry-run) *)
module type FILE_OPERATIONS = sig
  val copy_file : src:Path.t -> dst:Path.t -> executable:bool -> unit
  val mkdir_p : Path.t -> unit
  val remove_if_exists : Path.t -> unit
  val remove_dir_if_empty : Path.t -> unit
end

module File_ops_dry_run : FILE_OPERATIONS = struct
  let copy_file ~src ~dst ~executable =
    Format.printf
      "Copying %a to %a (executable: %b)\n"
      Path.pp src
      Path.pp dst
      executable

  let mkdir_p path =
    Format.printf
      "Creating directory %a\n"
      Path.pp
      path

  let remove_if_exists path =
    Format.printf
      "Removing (if it exists) %a\n"
      Path.pp
      path

  let remove_dir_if_empty path =
    Format.printf
      "Removing directory (if empty) %a\n"
      Path.pp
      path
end

module File_ops_real : FILE_OPERATIONS = struct
  let copy_file ~src ~dst ~executable =
    let chmod =
      if executable then
        set_executable_bits
     else
       clear_executable_bits
    in
    Io.copy_file ~src ~dst ~chmod ()

  let remove_if_exists dst =
    if Path.exists dst then begin
      Printf.eprintf
        "Deleting %s\n%!"
        (Path.to_string_maybe_quoted dst);
      print_unix_error (fun () -> Path.unlink dst)
    end

  let remove_dir_if_empty dir =
    if Path.exists dir then
      match Path.readdir_unsorted dir with
      | [] ->
          Printf.eprintf "Deleting empty directory %s\n%!"
          (Path.to_string_maybe_quoted dir);
        print_unix_error (fun () -> Path.rmdir dir)
      | _  -> ()

  let mkdir_p = Path.mkdir_p
end

let file_operations ~dry_run : (module FILE_OPERATIONS) =
  if dry_run then
    (module File_ops_dry_run)
  else
    (module File_ops_real)

let install_uninstall ~what =
  let doc =
    sprintf "%s packages." (String.capitalize what)
  in
  let name_ = Arg.info [] ~docv:"PACKAGE" in
  let term =
    let%map common = Common.term
    and prefix_from_command_line =
      Arg.(value
           & opt (some string) None
           & info ["prefix"]
               ~docv:"PREFIX"
               ~doc:"Directory where files are copied. For instance binaries \
                     are copied into $(i,\\$prefix/bin), library files into \
                     $(i,\\$prefix/lib), etc... It defaults to the current opam \
                     prefix if opam is available and configured, otherwise it uses \
                     the same prefix as the ocaml compiler.")
    and libdir_from_command_line =
      Arg.(value
           & opt (some string) None
           & info ["libdir"]
               ~docv:"PATH"
               ~doc:"Directory where library files are copied, relative to \
                     $(b,prefix) or absolute. If $(b,--prefix) \
                     is specified the default is $(i,\\$prefix/lib), otherwise \
                     it is the output of $(b,ocamlfind printconf destdir)"
          )
    and destdir =
      Arg.(value
           & opt (some string) None
           & info ["destdir"]
               ~env:(env_var "DESTDIR")
               ~docv:"PATH"
               ~doc:"When passed, this directory is prepended to all \
                     installed paths."
          )
    and dry_run =
      Arg.(value
           & flag
           & info ["dry-run"]
          ~doc:"Only display the file operations that would be performed."
          )
    and pkgs =
      Arg.(value & pos_all package_name [] name_)
    in
    Common.set_common common ~targets:[];
    let log = Log.create common in
    Scheduler.go ~log ~common
      (Main.setup ~log common >>= fun setup ->
       let pkgs =
         match pkgs with
         | [] -> Package.Name.Map.keys setup.packages
         | l  -> l
       in
       let install_files, missing_install_files =
         List.concat_map pkgs ~f:(fun pkg ->
           let fn = resolve_package_install setup pkg in
           List.map setup.contexts ~f:(fun ctx ->
             let fn = Path.append ctx.Context.build_dir fn in
             if Path.exists fn then
               Left (ctx, (pkg, fn))
             else
               Right fn))
         |> List.partition_map ~f:(fun x -> x)
       in
       if missing_install_files <> [] then begin
         die "The following <package>.install are missing:\n\
              %s\n\
              You need to run: dune build @install"
           (String.concat ~sep:"\n"
              (List.map missing_install_files
                 ~f:(fun p -> sprintf "- %s" (Path.to_string p))))
       end;
       (match
          setup.contexts, prefix_from_command_line, libdir_from_command_line
        with
        | _ :: _ :: _, Some _, _ | _ :: _ :: _, _, Some _ ->
          die "Cannot specify --prefix or --libdir when installing \
               into multiple contexts!"
        | _ -> ());
       let module CMap = Map.Make(Context) in
       let install_files_by_context =
         CMap.of_list_multi install_files |> CMap.to_list
       in
       let (module Ops) = file_operations ~dry_run in
       Fiber.parallel_iter install_files_by_context
         ~f:(fun (context, install_files) ->
           get_dirs context ~prefix_from_command_line ~libdir_from_command_line
           >>| fun (prefix, libdir) ->
           List.iter install_files ~f:(fun (package, path) ->
             let entries = Install.load_install_file path in
             let paths =
               Install.Section.Paths.make
                 ~package
                 ~destdir:prefix
                 ?libdir
                 ()
             in
             let files_deleted_in = ref Path.Set.empty in
             List.iter entries ~f:(fun { Install.Entry. src; dst; section } ->
               let dst =
                 dst
                 |> Option.value ~default:(Path.basename src)
                 |> Install.Section.Paths.install_path paths section
                 |> interpret_destdir ~destdir
               in
               let dir = Path.parent_exn dst in
               if what = "install" then begin
                 Printf.eprintf "Installing %s\n%!"
                   (Path.to_string_maybe_quoted dst);
                 Ops.mkdir_p dir;
                 let executable =
                   Install.Section.should_set_executable_bit section
                 in
                 Ops.copy_file ~src ~dst ~executable
               end else begin
                 Ops.remove_if_exists dst;
                 files_deleted_in := Path.Set.add !files_deleted_in dir;
               end;
               Path.Set.to_list !files_deleted_in
               (* This [List.rev] is to ensure we process children
                  directories before their parents *)
               |> List.rev
               |> List.iter ~f:Ops.remove_dir_if_empty))))
  in
  (term, Term.info what ~doc ~man:Common.help_secs)

let install   = install_uninstall ~what:"install"
let uninstall = install_uninstall ~what:"uninstall"

let context_arg ~doc =
  Arg.(value
       & opt string "default"
       & info ["context"] ~docv:"CONTEXT" ~doc)

let exec =
  let doc =
    "Execute a command in a similar environment as if installation was performed."
  in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|$(b,dune exec -- COMMAND) should behave in the same way as if you
           do:|}
    ; `Pre "  \\$ dune install\n\
           \  \\$ COMMAND"
    ; `P {|In particular if you run $(b,dune exec ocaml), you will have
           access to the libraries defined in the workspace using your usual
           directives ($(b,#require) for instance)|}
    ; `P {|When a leading / is present in the command (absolute path), then the
           path is interpreted as an absolute path|}
    ; `P {|When a / is present at any other position (relative path), then the
           path is interpreted as relative to the build context + current
           working directory (or the value of $(b,--root) when ran outside of
           the project root)|}
    ; `Blocks Common.help_secs
    ]
  in
  let term =
    let%map common = Common.term
    and context = context_arg ~doc:{|Run the command in this build context.|}
    and prog =
      Arg.(required
           & pos 0 (some string) None (Arg.info [] ~docv:"PROG"))
    and no_rebuild =
      Arg.(value & flag
           & info ["no-build"]
               ~doc:"don't rebuild target before executing")
    and args =
      Arg.(value
           & pos_right 0 string [] (Arg.info [] ~docv:"ARGS"))
    in
    Common.set_common common ~targets:[prog];
    let log = Log.create common in
    let setup = Scheduler.go ~log ~common (Main.setup ~log common) in
    let context = Main.find_context_exn setup ~name:context in
    let prog_where =
      match Filename.analyze_program_name prog with
      | Absolute ->
        `This_abs (Path.of_string prog)
      | In_path ->
        `Search prog
      | Relative_to_current_dir ->
        let prog = Common.prefix_target common prog in
        `This_rel (Path.relative context.build_dir prog) in
    let targets = lazy (
      (match prog_where with
       | `Search p ->
         [Path.relative (Config.local_install_bin_dir ~context:context.name) p]
       | `This_rel p when Sys.win32 ->
         [p; Path.extend_basename p ~suffix:Bin.exe]
       | `This_rel p ->
         [p]
       | `This_abs p when Path.is_in_build_dir p ->
         [p]
       | `This_abs _ ->
         [])
      |> List.map ~f:(fun p -> Target.Path p)
      |> Target.resolve_targets_mixed ~log common setup
      |> List.concat_map ~f:(function
        | Ok targets -> targets
        | Error _ -> [])
    ) in
    let real_prog =
      if not no_rebuild then begin
        match Lazy.force targets with
        | [] -> ()
        | targets ->
          Scheduler.go ~log ~common (do_build setup targets);
          Build_system.finalize setup.build_system
      end;
      match prog_where with
      | `Search prog ->
        let path = Config.local_install_bin_dir ~context:context.name :: context.path in
        Bin.which prog ~path
      | `This_rel prog
      | `This_abs prog ->
        if Path.exists prog then
          Some prog
        else if not Sys.win32 then
          None
        else
          let prog = Path.extend_basename prog ~suffix:Bin.exe in
          Option.some_if (Path.exists prog) prog
    in
    match real_prog, no_rebuild with
    | None, true ->
      begin match Lazy.force targets with
      | [] ->
        Format.eprintf "@{<Error>Error@}: Program %S not found!@." prog;
        raise Already_reported
      | _::_ ->
        Format.eprintf "@{<Error>Error@}: Program %S isn't built yet \
                        you need to build it first or remove the \
                        --no-build option.@." prog;
        raise Already_reported
      end
    | None, false ->
      Format.eprintf "@{<Error>Error@}: Program %S not found!@." prog;
      raise Already_reported
    | Some real_prog, _ ->
      let real_prog = Path.to_string real_prog     in
      let argv      = prog :: args in
      restore_cwd_and_execve common real_prog argv context.env
  in
  (term, Term.info "exec" ~doc ~man)

(** A string that is "%%VERSION%%" but not expanded by [dune subst] *)
let literal_version =
  "%%" ^ "VERSION%%"

let subst =
  let doc =
    "Substitute watermarks in source files."
  in
  let man =
    let var name desc =
      `Blocks [`Noblank; `P ("- $(b,%%" ^ name ^ "%%), " ^ desc) ]
    in
    let opam field =
      var ("PKG_" ^ String.uppercase field)
        ("contents of the $(b," ^ field ^ ":) field from the opam file")
    in
    [ `S "DESCRIPTION"
    ; `P {|Substitute $(b,%%ID%%) strings in source files, in a similar fashion to
           what topkg does in the default configuration.|}
    ; `P ({|This command is only meant to be called when a user pins a package to
            its development version. Especially it replaces $(b,|} ^ literal_version
          ^{|) strings by the version obtained from the vcs. Currently only git is
             supported and the version is obtained from the output of:|})
    ; `Pre {|  \$ git describe --always --dirty|}
    ; `P {|$(b,dune subst) substitutes the variables that topkg substitutes with
           the defatult configuration:|}
    ; var "NAME" "the name of the project (from the dune-project file)"
    ; var "VERSION" "output of $(b,git describe --always --dirty)"
    ; var "VERSION_NUM" ("same as $(b," ^ literal_version ^
                         ") but with a potential leading 'v' or 'V' dropped")
    ; var "VCS_COMMIT_ID" "commit hash from the vcs"
    ; opam "maintainer"
    ; opam "authors"
    ; opam "homepage"
    ; opam "issues"
    ; opam "doc"
    ; opam "license"
    ; opam "repo"
    ; `P {|In order to call $(b,dune subst) when your package is pinned, add this line
           to the $(b,build:) field of your opam file:|}
    ; `Pre {|  [dune "subst"] {pinned}|}
    ; `P {|Note that this command is meant to be called only from opam files and
           behaves a bit differently from other dune commands. In particular it
           doesn't try to detect the root and must be called from the root of
           the project.|}
    ; `Blocks Common.help_secs
    ]
  in
  let term =
    match Which_program.t with
    | Jbuilder ->
      let%map common = Common.term
      and name =
        Arg.(value
             & opt (some string) None
             & info ["n"; "name"] ~docv:"NAME"
                 ~doc:"Use this project name instead of detecting it.")
      in
      Common.set_common common ~targets:[];
      Scheduler.go ~common (Watermarks.subst ?name ())
    | Dune ->
      let%map () = Term.const () in
      let config : Config.t =
        { display     = Quiet
        ; concurrency = Fixed 1
        }
      in
      Path.set_root (Path.External.cwd ());
      Dune.Scheduler.go ~config (Watermarks.subst ())
  in
  (term, Term.info "subst" ~doc ~man)

let utop =
  let doc = "Load library in utop" in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|$(b,dune utop DIR) build and run utop toplevel with libraries defined in DIR|}
    ; `Blocks Common.help_secs
    ] in
  let term =
    let%map common = Common.term
    and dir = Arg.(value & pos 0 string "" & Arg.info [] ~docv:"DIR")
    and ctx_name = context_arg ~doc:{|Select context where to build/run utop.|}
    and args = Arg.(value & pos_right 0 string [] (Arg.info [] ~docv:"ARGS"))
    in
    Common.set_dirs common;
    if not (Path.is_directory
              (Path.of_string (Common.prefix_target common dir))) then
      die "cannot find directory: %s" (String.maybe_quoted dir);
    let utop_target = Filename.concat dir Utop.utop_exe in
    Common.set_common_other common ~targets:[utop_target];
    let log = Log.create common in
    let (build_system, context, utop_path) =
      (Main.setup ~log common >>= fun setup ->
       let context = Main.find_context_exn setup ~name:ctx_name in
       let setup = { setup with contexts = [context] } in
       let target =
         match Target.resolve_target common ~setup utop_target with
         | Error _ ->
           die "no library is defined in %s" (String.maybe_quoted dir)
         | Ok [File target] -> target
         | Ok _ -> assert false
       in
       do_build setup [File target] >>| fun () ->
       (setup.build_system, context, Path.to_string target)
      ) |> Scheduler.go ~log ~common in
    Build_system.finalize build_system;
    restore_cwd_and_execve common utop_path (utop_path :: args)
      context.env
  in
  (term, Term.info "utop" ~doc ~man )

let promote =
  let doc = "Promote files from the last run" in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|Considering all actions of the form $(b,(diff a b)) that failed
           in the last run of dune, $(b,dune promote) does the following:

           If $(b,a) is present in the source tree but $(b,b) isn't, $(b,b) is
           copied over to $(b,a) in the source tree. The idea behind this is that
           you might use $(b,(diff file.expected file.generated)) and then call
           $(b,dune promote) to promote the generated file.
         |}
    ; `Blocks Common.help_secs
    ] in
  let term =
    let%map common = Common.term
    and files =
      Arg.(value & pos_all Cmdliner.Arg.file [] & info [] ~docv:"FILE")
    in
    Common.set_common common ~targets:[];
    (* We load and restore the digest cache as we need to clear the
       cache for promoted files, due to issues on OSX. *)
    Utils.Cached_digest.load ();
    Promotion.promote_files_registered_in_last_run
      (match files with
       | [] -> All
       | _ ->
         let files =
           List.map files
             ~f:(fun fn -> Path.of_string (Common.prefix_target common fn))
         in
         let on_missing fn =
           Format.eprintf "@{<warning>Warning@}: Nothing to promote for %a.@."
             Path.pp fn
         in
         These (files, on_missing));
    Utils.Cached_digest.dump ()
  in
  (term, Term.info "promote" ~doc ~man )

let printenv =
  let doc = "Print the environment of a directory" in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|$(b,dune printenv DIR) prints the environment of a directory|}
    ; `Blocks Common.help_secs
    ] in
  let term =
    let%map common = Common.term
    and dir = Arg.(value & pos 0 dir "" & info [] ~docv:"PATH")
    in
    Common.set_common common ~targets:[];
    let log = Log.create common in
    Scheduler.go ~log ~common (
      Main.setup ~log common >>= fun setup ->
      let dir = Path.of_string dir in
      Util.check_path setup.contexts dir;
      let request =
        let dump sctx ~dir =
          let open Build.O in
          Super_context.dump_env sctx ~dir
          >>^ fun env ->
          ((Super_context.context sctx).name, env)
        in
        Build.all (
          match Path.extract_build_context dir with
          | Some (ctx, _) ->
            let sctx =
              String.Map.find setup.scontexts ctx |> Option.value_exn
            in
            [dump sctx ~dir]
          | None ->
            String.Map.values setup.scontexts
            |> List.map ~f:(fun sctx ->
              let dir =
                Path.append (Super_context.context sctx).build_dir dir
              in
              dump sctx ~dir)
        )
      in
      Build_system.do_build setup.build_system ~request
      >>| fun l ->
      let pp ppf = Format.fprintf ppf "@[<v1>(@,@[<v>%a@]@]@,)"
                     (Format.pp_print_list (Dune_lang.pp Dune)) in
      match l with
      | [(_, env)] ->
        Format.printf "%a@." pp env
      | l ->
        List.iter l ~f:(fun (name, env) ->
          Format.printf "@[<v2>Environment for context %s:@,%a@]@." name pp env)
    )
  in
  (term, Term.info "printenv" ~doc ~man )

let fmt =
  let doc = "Format dune files" in
  let man =
    [ `S "DESCRIPTION"
    ; `P {|$(b,dune unstable-fmt) reads a dune file and outputs a formatted
           version. This feature is unstable, and its interface or behaviour
           might change.
         |}
    ] in
  let term =
    let%map path_opt =
      let docv = "FILE" in
      let doc = "Path to the dune file to parse." in
      Arg.(value & pos 0 (some path) None & info [] ~docv ~doc)
    and inplace =
      let doc = "Modify the file in place" in
      Arg.(value & flag & info ["inplace"] ~doc)
    in
    if true then
      let (input, output) =
        match path_opt, inplace with
        | None, false ->
          (None, None)
        | Some path, true ->
          let path = Arg.Path.path path in
          (Some path, Some path)
        | Some path, false ->
          (Some (Arg.Path.path path), None)
        | None, true ->
          die "--inplace requires a file name"
      in
      Dune_fmt.format_file ~input ~output
    else
      die "This command is unstable. Please pass --unstable to use it nonetheless."
  in
  (term, Term.info "unstable-fmt" ~doc ~man )

module Help = struct
  let config =
    ("dune-config", 5, "", "Dune", "Dune manual"),
    [ `S Manpage.s_synopsis
    ; `Pre "~/.config/dune/config"
    ; `S Manpage.s_description
    ; `P {|Unless $(b,--no-config) or $(b,-p) is passed, Dune will read a
           configuration file from the user home directory. This file is used
           to control various aspects of the behavior of Dune.|}
    ; `P {|The configuration file is normally $(b,~/.config/dune/config) on
           Unix systems and $(b,Local Settings/dune/config) in the User home
           directory on Windows. However, it is possible to specify an
           alternative configuration file with the $(b,--config-file) option.|}
    ; `P {|The first line of the file must be of the form (lang dune X.Y)
           where X.Y is the version of the dune language used in the file.|}
    ; `P {|The rest of the file must be written in S-expression syntax and be
           composed of a list of stanzas. The following sections describe
           the stanzas available.|}
    ; `S "DISPLAY MODES"
    ; `P {|Syntax: $(b,\(display MODE\))|}
    ; `P {|This stanza controls how Dune reports what it is doing to the user.
           This parameter can also be set from the command line via $(b,--display MODE).
           The following display modes are available:|}
    ; `Blocks
        (List.map ~f:(fun (x, desc) -> `I (sprintf "$(b,%s)" x, desc))
           [ "progress",
             {|This is the default, Dune shows and update a
               status line as build goals are being completed.|}
           ; "quiet",
             {|Only display errors.|}
           ; "short",
             {|Print one line per command being executed, with the
               binary name on the left and the reason it is being executed for
               on the right.|}
           ; "verbose",
             {|Print the full command lines of programs being
               executed by Dune, with some colors to help differentiate
               programs.|}
           ])
    ; `P {|Note that when the selected display mode is $(b,progress) and the
           output is not a terminal then the $(b,quiet) mode is selected
           instead. This rule doesn't apply when running Dune inside Emacs.
           Dune detects whether it is executed from inside Emacs or not by
           looking at the environment variable $(b,INSIDE_EMACS) that is set by
           Emacs. If you want the same behavior with another editor, you can set
           this variable. If your editor already sets another variable,
           please open a ticket on the ocaml/dune github project so that we can
           add support for it.|}
    ; `S "JOBS"
    ; `P {|Syntax: $(b,\(jobs NUMBER\))|}
    ; `P {|Set the maximum number of jobs Dune might run in parallel.
           This can also be set from the command line via $(b,-j NUMBER).|}
    ; `P {|The default for this value is 4.|}
    ; Common.footer
    ]

  type what =
    | Man of Manpage.t
    | List_topics

  let commands =
    [ "config", Man config
    ; "topics", List_topics
    ]

  let help =
    let doc = "Additional Dune help" in
    let man =
      [ `S "DESCRIPTION"
      ; `P {|$(b,dune help TOPIC) provides additional help on the given topic.
             The following topics are available:|}
      ; `Blocks (List.concat_map commands ~f:(fun (s, what) ->
          match what with
          | List_topics -> []
          | Man ((title, _, _, _, _), _) -> [`I (sprintf "$(b,%s)" s, title)]))
      ; Common.footer
      ]
    in
    let term =
      Term.ret @@
      let%map man_format = Arg.man_format
      and what =
        Arg.(value
             & pos 0 (some (enum commands)) None
             & info [] ~docv:"TOPIC")
      in
      match what with
      | None ->
        `Help (man_format, Some "help")
      | Some (Man man_page) ->
        Format.printf "%a@?" (Manpage.print man_format) man_page;
        `Ok ()
      | Some List_topics ->
        List.filter_map commands ~f:(fun (s, what) ->
          match what with
          | List_topics -> None
          | _ -> Some s)
        |> List.sort ~compare:String.compare
        |> String.concat ~sep:"\n"
        |> print_endline;
        `Ok ()
    in
    (term, Term.info "help" ~doc ~man)
end

let all =
  [ installed_libraries
  ; external_lib_deps
  ; build_targets
  ; runtest
  ; clean
  ; install
  ; uninstall
  ; exec
  ; subst
  ; rules
  ; utop
  ; promote
  ; printenv
  ; Help.help
  ; fmt
  ]

let default =
  let doc = "composable build system for OCaml" in
  let term =
    Term.ret @@
    let%map _ = Common.term in
    `Help (`Pager, None)
  in
  (term,
   Term.info "dune" ~doc ~version:"%%VERSION%%"
     ~man:
       [ `S "DESCRIPTION"
       ; `P {|Dune is a build system designed for OCaml projects only. It
              focuses on providing the user with a consistent experience and takes
              care of most of the low-level details of OCaml compilation. All you
              have to do is provide a description of your project and Dune will
              do the rest.
            |}
       ; `P {|The scheme it implements is inspired from the one used inside Jane
              Street and adapted to the open source world. It has matured over a
              long time and is used daily by hundreds of developers, which means
              that it is highly tested and productive.
            |}
       ; `Blocks Common.help_secs
       ])

let main () =
  Colors.setup_err_formatter_colors ();
  try
    match Term.eval_choice default all ~catch:false with
    | `Error _ -> exit 1
    | _ -> exit 0
  with
  | Fiber.Never -> exit 1
  | exn ->
    Report_error.report exn;
    exit 1
