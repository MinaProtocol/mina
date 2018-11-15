open Stdune
open Dune

type t =
  { debug_dep_path        : bool
  ; debug_findlib         : bool
  ; debug_backtraces      : bool
  ; profile               : string option
  ; workspace_file        : Arg.Path.t option
  ; root                  : string
  ; target_prefix         : string
  ; only_packages         : Package.Name.Set.t option
  ; capture_outputs       : bool
  ; x                     : string option
  ; diff_command          : string option
  ; auto_promote          : bool
  ; force                 : bool
  ; ignore_promoted_rules : bool
  ; build_dir             : string
  ; (* Original arguments for the external-lib-deps hint *)
    orig_args             : string list
  ; config                : Config.t
  ; default_target        : string
  (* For build & runtest only *)
  ; watch : bool
  }

let prefix_target common s = common.target_prefix ^ s

let set_dirs c =
  if c.root <> Filename.current_dir_name then
    Sys.chdir c.root;
  Path.set_root (Path.External.cwd ());
  Path.set_build_dir (Path.Kind.of_string c.build_dir)

let set_common_other c ~targets =
  Clflags.debug_dep_path := c.debug_dep_path;
  Clflags.debug_findlib := c.debug_findlib;
  Clflags.debug_backtraces := c.debug_backtraces;
  Clflags.capture_outputs := c.capture_outputs;
  Clflags.diff_command := c.diff_command;
  Clflags.auto_promote := c.auto_promote;
  Clflags.force := c.force;
  Clflags.watch := c.watch;
  Clflags.external_lib_deps_hint :=
    List.concat
      [ ["dune"; "external-lib-deps"; "--missing"]
      ; c.orig_args
      ; targets
      ]

let set_common c ~targets =
  set_dirs c;
  set_common_other c ~targets

let footer =
  `Blocks
    [ `S "BUGS"
    ; `P "Check bug reports at https://github.com/ocaml/dune/issues"
    ]

let copts_sect = "COMMON OPTIONS"
let help_secs =
  [ `S copts_sect
  ; `P "These options are common to all commands."
  ; `S "MORE HELP"
  ; `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command."
  ; footer
  ]

type config_file =
  | No_config
  | Default
  | This of Path.t

let term =
  let incompatible a b =
    `Error (true,
            sprintf
              "Cannot use %s and %s simultaneously"
              a b)
  in
  let module Let_syntax = Cmdliner.Term in
  let module Term = Cmdliner.Term in
  let module Manpage = Cmdliner.Manpage in
  let dump_opt name value =
    match value with
    | None -> []
    | Some s -> [name; s]
  in
  let docs = copts_sect in
  let%map concurrency =
    let arg =
      Arg.conv
        ((fun s ->
           Result.map_error (Config.Concurrency.of_string s)
             ~f:(fun s -> `Msg s)),
         fun pp x ->
           Format.pp_print_string pp (Config.Concurrency.to_string x))
    in
    Arg.(value
         & opt (some arg) None
         & info ["j"] ~docs ~docv:"JOBS"
             ~doc:{|Run no more than $(i,JOBS) commands simultaneously.|}
        )
  and debug_dep_path =
    Arg.(value
         & flag
         & info ["debug-dependency-path"] ~docs
             ~doc:{|In case of error, print the dependency path from
                    the targets on the command line to the rule that failed.
                  |})
  and debug_findlib =
    Arg.(value
         & flag
         & info ["debug-findlib"] ~docs
             ~doc:{|Debug the findlib sub-system.|})
  and debug_backtraces =
    Arg.(value
         & flag
         & info ["debug-backtraces"] ~docs
             ~doc:{|Always print exception backtraces.|})
  and display =
    Term.ret @@
    let%map verbose =
      Arg.(value
           & flag
           & info ["verbose"] ~docs
               ~doc:"Same as $(b,--display verbose)")
    and display =
      Arg.(value
           & opt (some (enum Config.Display.all)) None
           & info ["display"] ~docs ~docv:"MODE"
               ~doc:{|Control the display mode of Dune.
                      See $(b,dune-config\(5\)) for more details.|})
    in
    match verbose, display with
    | false , None   -> `Ok None
    | false , Some x -> `Ok (Some x)
    | true  , None   -> `Ok (Some Config.Display.Verbose)
    | true  , Some _ -> incompatible "--display" "--verbose"
  and no_buffer =
    Arg.(value
         & flag
         & info ["no-buffer"] ~docs ~docv:"DIR"
             ~doc:{|Do not buffer the output of commands executed by dune.
                    By default dune buffers the output of subcommands, in order
                    to prevent interleaving when multiple commands are executed
                    in parallel. However, this can be an issue when debugging
                    long running tests. With $(b,--no-buffer), commands have direct
                    access to the terminal. Note that as a result their output won't
                    be captured in the log file.

                    You should use this option in conjunction with $(b,-j 1),
                    to avoid interleaving. Additionally you should use
                    $(b,--verbose) as well, to make sure that commands are printed
                    before they are being executed.|})
  and workspace_file =
    Arg.(value
         & opt (some path) None
         & info ["workspace"] ~docs ~docv:"FILE"
             ~doc:"Use this specific workspace file instead of looking it up.")
  and auto_promote =
    Arg.(value
         & flag
         & info ["auto-promote"] ~docs
             ~doc:"Automatically promote files. This is similar to running
                   $(b,dune promote) after the build.")
  and force =
    Arg.(value
         & flag
         & info ["force"; "f"]
             ~doc:"Force actions associated to aliases to be re-executed even
                   if their dependencies haven't changed.")
  and watch =
    Arg.(value
         & flag
         & info ["watch"; "w"]
             ~doc:"Instead of terminating build after completion, wait continuously
              for file changes.")
  and root,
      only_packages,
      ignore_promoted_rules,
      config_file,
      profile,
      default_target,
      orig =
    let default_target_default =
      match Which_program.t with
      | Dune     -> "@@default"
      | Jbuilder -> "@install"
    in
    let for_release = "for-release-of-packages" in
    Term.ret @@
    let%map root =
      Arg.(value
           & opt (some dir) None
           & info ["root"] ~docs ~docv:"DIR"
               ~doc:{|Use this directory as workspace root instead of
                      guessing it. Note that this option doesn't change
                      the interpretation of targets given on the command
                      line. It is only intended for scripts.|})
    and only_packages =
      Arg.(value
           & opt (some string) None
           & info ["only-packages"] ~docs ~docv:"PACKAGES"
               ~doc:{|Ignore stanzas referring to a package that is not in
                      $(b,PACKAGES). $(b,PACKAGES) is a comma-separated list
                      of package names. Note that this has the same effect
                      as deleting the relevant stanzas from jbuild files.
                      It is mostly meant for releases. During development,
                      it is likely that what you want instead is to
                      build a particular $(b,<package>.install) target.|}
          )
    and ignore_promoted_rules =
      Arg.(value
           & flag
           & info ["ignore-promoted-rules"] ~docs
               ~doc:"Ignore rules with (mode promote)")
    and (config_file_opt, config_file) =
      Term.ret @@
      let%map config_file =
        Arg.(value
             & opt (some path) None
             & info ["config-file"] ~docs ~docv:"FILE"
                 ~doc:"Load this configuration file instead of \
                       the default one.")
      and no_config =
        Arg.(value
             & flag
             & info ["no-config"] ~docs
                 ~doc:"Do not load the configuration file")
      in
      match config_file, no_config with
      | None   , false -> `Ok (None, Default)
      | Some fn, false -> `Ok (Some "--config-file",
                               This (Arg.Path.path fn))
      | None   , true  -> `Ok (Some "--no-config"  , No_config)
      | Some _ , true  -> incompatible "--no-config" "--config-file"
    and profile =
      Term.ret @@
      let%map dev =
        Term.ret @@
        let%map dev =
          Arg.(value
               & flag
               & info ["dev"] ~docs
                   ~doc:{|Same as $(b,--profile dev)|})
        in
        match dev, Which_program.t with
        | false, (Dune | Jbuilder) -> `Ok false
        | true, Jbuilder -> `Ok true
        | true, Dune ->
          `Error
            (true, "--dev is no longer accepted as it is now the default.")
      and profile =
        Arg.(value
             & opt (some string) None
             & info ["profile"] ~docs
                 ~doc:
                   (sprintf
                      {|Select the build profile, for instance $(b,dev) or
                        $(b,release). The default is $(b,%s).|}
                      Config.default_build_profile))
      in
      match dev, profile with
      | false, x    -> `Ok x
      | true , None -> `Ok (Some "dev")
      | true , Some _ ->
        `Error (true,
                "Cannot use --dev and --profile simultaneously")
    and default_target =
      Arg.(value
           & opt (some string) None
           & info ["default-target"] ~docs ~docv:"TARGET"
               ~doc:(sprintf
                       {|Set the default target that when none is specified to
                         $(b,dune build). It defaults to %s.|}
                       default_target_default))
    and frop =
      Arg.(value
           & opt (some string) None
           & info ["p"; for_release] ~docs ~docv:"PACKAGES"
               ~doc:{|Shorthand for $(b,--root . --only-packages PACKAGE
                      --ignore-promoted-rules --no-config --profile release).
                      You must use this option in your $(i,<package>.opam)
                      files, in order to build only what's necessary when
                      your project contains multiple packages as well as
                      getting reproducible builds.|})
    in
    let fail opt = incompatible ("-p/--" ^ for_release) opt in
    match frop, root, only_packages, ignore_promoted_rules,
          profile, default_target, config_file_opt with
    | Some _, Some _, _, _, _, _, _ -> fail "--root"
    | Some _, _, Some _, _, _, _, _ -> fail "--only-packages"
    | Some _, _, _, true  , _, _, _ -> fail "--ignore-promoted-rules"
    | Some _, _, _, _, Some _, _, _ -> fail "--profile"
    | Some _, _, _, _, _, Some s, _ -> fail s
    | Some _, _, _, _, _, _, Some _ -> fail "--default-target"
    | Some pkgs, None, None, false, None, None, None ->
      `Ok (Some ".",
           Some pkgs,
           true,
           No_config,
           Some "release",
           "@install",
           ["-p"; pkgs]
          )
    | None, _, _, _, _, _, _ ->
      `Ok (root,
           only_packages,
           ignore_promoted_rules,
           config_file,
           profile,
           Option.value default_target ~default:default_target_default,
           List.concat
             [ dump_opt "--root" root
             ; dump_opt "--only-packages" only_packages
             ; dump_opt "--profile" profile
             ; dump_opt "--default-target" default_target
             ; if ignore_promoted_rules then
                 ["--ignore-promoted-rules"]
               else
                 []
             ; (match config_file with
                | This fn   -> ["--config-file"; Path.to_string fn]
                | No_config -> ["--no-config"]
                | Default   -> [])
             ]
          )
  and x =
    Arg.(value
         & opt (some string) None
         & info ["x"] ~docs
             ~doc:{|Cross-compile using this toolchain.|})
  and build_dir =
    let doc = "Specified build directory. _build if unspecified" in
    Arg.(value
         & opt (some string) None
         & info ["build-dir"] ~docs ~docv:"FILE"
             ~env:(Arg.env_var ~doc "DUNE_BUILD_DIR")
             ~doc)
  and diff_command =
    Arg.(value
         & opt (some string) None
         & info ["diff-command"] ~docs
             ~doc:"Shell command to use to diff files.
                   Use - to disable printing the diff.")
  in
  let build_dir = Option.value ~default:"_build" build_dir in
  let root, to_cwd =
    match root with
    | Some dn -> (dn, [])
    | None ->
      if Config.inside_dune then
        (".", [])
      else
        Util.find_root ()
  in
  let orig_args =
    List.concat
      [ dump_opt "--workspace" (Option.map ~f:Arg.Path.arg workspace_file)
      ; orig
      ]
  in
  let config =
    match config_file with
    | No_config  -> Config.default
    | This fname -> Config.load_config_file fname
    | Default    ->
      if Config.inside_dune then
        Config.default
      else
        Config.load_user_config_file ()
  in
  let config =
    Config.merge config
      { display
      ; concurrency
      }
  in
  let config =
    Config.adapt_display config
      ~output_is_a_tty:(Lazy.force Colors.stderr_supports_colors)
  in
  { debug_dep_path
  ; debug_findlib
  ; debug_backtraces
  ; profile
  ; capture_outputs = not no_buffer
  ; workspace_file
  ; root
  ; orig_args
  ; target_prefix = String.concat ~sep:"" (List.map to_cwd ~f:(sprintf "%s/"))
  ; diff_command
  ; auto_promote
  ; force
  ; ignore_promoted_rules
  ; only_packages =
      Option.map only_packages
        ~f:(fun s -> Package.Name.Set.of_list (
          List.map ~f:Package.Name.of_string (String.split s ~on:',')))
  ; x
  ; config
  ; build_dir
  ; default_target
  ; watch
  }
