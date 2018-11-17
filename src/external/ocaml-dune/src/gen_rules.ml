open! Stdune
open Import
module Menhir_rules = Menhir
open Dune_file
open! No_io

(* Utils *)

let stanza_package = function
  | Library { public = Some { package; _ }; _ }
  | Alias { package = Some package ;  _ }
  | Install { package; _ }
  | Documentation { package; _ }
  | Tests { package = Some package; _} ->
    Some package
  | _ -> None

module For_stanza = struct
  type ('merlin, 'cctx, 'js) t =
    { merlin : 'merlin
    ; cctx   : 'cctx
    ; js     : 'js
    }

  let empty_none =
    { merlin = None
    ; cctx = None
    ; js = None
    }

  let empty_list =
    { merlin = []
    ; cctx = []
    ; js = []
    }

  let cons_maybe hd_o tl =
    match hd_o with
    | Some hd -> hd::tl
    | None -> tl

  let cons acc x =
    { merlin = cons_maybe x.merlin acc.merlin
    ; cctx = cons_maybe x.cctx acc.cctx
    ; js =
        match x.js with
        | None -> acc.js
        | Some js -> List.rev_append acc.js js
    }

  let rev t =
    { t with
      merlin = List.rev t.merlin
    ; cctx = List.rev t.cctx
    }
end

module Gen(P : Install_rules.Params) = struct
  module Alias = Build_system.Alias
  module CC = Compilation_context
  module SC = Super_context
  (* We need to instantiate Install_rules earlier to avoid issues whenever
   * Super_context is used too soon.
   * See: https://github.com/ocaml/dune/pull/1354#issuecomment-427922592 *)
  module Install_rules = Install_rules.Gen(P)
  module Lib_rules = Lib_rules.Gen(P)

  let sctx = P.sctx

  let gen_format_rules sctx ~dir =
    let scope = SC.find_scope_by_dir sctx dir in
    let project = Scope.project scope in
    match Dune_project.find_extension_args project Auto_format.key with
    | None -> ()
    | Some config ->
      Format_rules.gen_rules sctx config ~dir

  (* Stanza *)

  let gen_rules dir_contents cctxs
        { SC.Dir_with_dune. src_dir; ctx_dir; stanzas; scope; kind = dir_kind } =
    let for_stanza ~dir = function
      | Library lib ->
        let cctx, merlin =
          Lib_rules.rules lib ~dir ~scope ~dir_contents ~dir_kind in
        { For_stanza.
          merlin = Some merlin
        ; cctx = Some (lib.buildable.loc, cctx)
        ; js = None
        }
      | Executables exes ->
        let cctx, merlin =
          Exe_rules.rules exes
            ~sctx ~dir ~scope
            ~dir_contents ~dir_kind
        in
        { For_stanza.
          merlin = Some merlin
        ; cctx = Some (exes.buildable.loc, cctx)
        ; js =
            Some (List.concat_map exes.names ~f:(fun (_, exe) ->
              List.map
                [exe ^ ".bc.js" ; exe ^ ".bc.runtime.js"]
                ~f:(Path.relative ctx_dir)))
        }
      | Alias alias ->
        Simple_rules.alias sctx alias ~dir ~scope;
        For_stanza.empty_none
      | Tests tests ->
        let cctx, merlin =
          Test_rules.rules tests ~sctx ~dir ~scope ~dir_contents ~dir_kind
        in
        { For_stanza.
          merlin = Some merlin
        ; cctx = Some (tests.exes.buildable.loc, cctx)
        ; js = None
        }
      | Copy_files { glob; _ } ->
        let source_dirs =
          let loc = String_with_vars.loc glob in
          let src_glob = SC.expand_vars_string sctx ~dir glob ~scope in
          Path.relative src_dir src_glob ~error_loc:loc
          |> Path.parent_exn
          |> Path.Set.singleton
        in
        { For_stanza.
          merlin = Some (Merlin.make ~source_dirs ())
        ; cctx = None
        ; js = None
        }
      | Install { Install_conf. section = _; files; package = _ } ->
        List.map files ~f:(fun { File_bindings. src; dst = _ } ->
          let src_expanded = SC.expand_vars_string sctx ~dir src ~scope in
          Path.relative ctx_dir src_expanded)
        |> Path.Set.of_list
        |> Super_context.add_alias_deps sctx
             (Build_system.Alias.all ~dir:ctx_dir);
        For_stanza.empty_none
      | _ ->
        For_stanza.empty_none
    in
    let { For_stanza.
          merlin = merlins
        ; cctx = cctxs
        ; js = js_targets
        } = List.fold_left stanzas
              ~init:{ For_stanza.empty_list with cctx = cctxs }
              ~f:(fun acc a -> For_stanza.cons acc (for_stanza ~dir:ctx_dir a))
            |> For_stanza.rev
    in
    Option.iter (Merlin.merge_all merlins) ~f:(fun m ->
      let more_src_dirs =
        List.map (Dir_contents.dirs dir_contents) ~f:(fun dc ->
          Path.drop_optional_build_context (Dir_contents.dir dc))
      in
      Merlin.add_rules sctx ~dir:ctx_dir ~more_src_dirs ~scope ~dir_kind
        (Merlin.add_source_dir m src_dir));
    List.iter stanzas ~f:(fun stanza ->
      match (stanza : Stanza.t) with
      | Menhir.T m when SC.eval_blang sctx m.enabled_if ~dir:ctx_dir ~scope ->
        begin match
          List.find_map (Menhir_rules.module_names m)
            ~f:(fun name ->
              Option.bind (Dir_contents.lookup_module dir_contents name)
                ~f:(fun buildable ->
                  List.find_map cctxs ~f:(fun (loc, cctx) ->
                    Option.some_if (Loc.equal loc buildable.loc) cctx)))
        with
        | None ->
          (* This happens often when passing a [-p ...] option that
             hides a library *)
          let targets =
            List.map (Menhir_rules.targets m) ~f:(Path.relative ctx_dir)
          in
          SC.add_rule sctx ~dir:ctx_dir
            (Build.fail ~targets
               { fail = fun () ->
                   Errors.fail m.loc
                     "I can't determine what library/executable the files \
                      produced by this stanza are part of."
               })
        | Some cctx ->
          Menhir_rules.gen_rules cctx m ~dir:ctx_dir
        end
      | _ -> ());
    Super_context.add_alias_deps sctx
      ~dyn_deps:(Build.paths_matching ~dir:ctx_dir ~loc:Loc.none (fun p ->
        not (List.exists js_targets ~f:(Path.equal p))))
      (Build_system.Alias.all ~dir:ctx_dir) Path.Set.empty;
    cctxs

  let gen_rules dir_contents cctxs ~dir : (Loc.t * Compilation_context.t) list =
    gen_format_rules sctx ~dir;
    match SC.stanzas_in sctx ~dir with
    | None -> []
    | Some d -> gen_rules dir_contents cctxs d

  let gen_rules ~dir components : Build_system.extra_sub_directories_to_keep =
    (match components with
     | ".js"  :: rest -> Js_of_ocaml_rules.setup_separate_compilation_rules
                           sctx rest
     | "_doc" :: rest -> Lib_rules.Odoc.gen_rules rest ~dir
     | ".ppx"  :: rest -> Preprocessing.gen_rules sctx rest
     | comps ->
       begin match List.last comps with
       | Some ".bin" ->
         let src_dir = Path.parent_exn dir in
         Super_context.file_bindings sctx ~dir
         |> List.iter ~f:(fun t ->
           let src = File_bindings.src_path t ~dir:src_dir in
           let dst = File_bindings.dst_path t ~dir in
           Super_context.add_rule sctx ~dir (Build.symlink ~src ~dst))
       | _ ->
         match
           File_tree.find_dir (SC.file_tree sctx)
             (Path.drop_build_context_exn dir)
         with
         | None ->
           (* We get here when [dir] is a generated directory, such as
              [.utop] or [.foo.objs]. *)
           if Utop.is_utop_dir dir then
             Utop.setup sctx ~dir:(Path.parent_exn dir)
           else if components <> [] then
             SC.load_dir sctx ~dir:(Path.parent_exn dir)
         | Some _ ->
           (* This interprets "rule" and "copy_files" stanzas. *)
           let dir_contents = Dir_contents.get sctx ~dir in
           match Dir_contents.kind dir_contents with
           | Standalone ->
             ignore (gen_rules dir_contents [] ~dir : _ list)
           | Group_part root ->
             SC.load_dir sctx ~dir:(Dir_contents.dir root)
           | Group_root (lazy subs) ->
             let cctxs = gen_rules dir_contents [] ~dir in
             List.iter subs ~f:(fun dc ->
               ignore (gen_rules dir_contents cctxs ~dir:(Dir_contents.dir dc)
                       : _ list))
       end);
    match components with
    | [] -> These (String.Set.of_list [".js"; "_doc"; ".ppx"])
    | [(".js"|"_doc"|".ppx")] -> All
    | _  -> These String.Set.empty

  let init () =
    Install_rules.init ();
    Lib_rules.Odoc.init ()
end

module type Gen = sig
  val gen_rules
    :  dir:Path.t
    -> string list
    -> Build_system.extra_sub_directories_to_keep
  val init : unit -> unit
  val sctx : Super_context.t
end

let relevant_stanzas pkgs stanzas =
  List.filter stanzas ~f:(fun stanza ->
    match stanza_package stanza with
    | Some package -> Package.Name.Set.mem pkgs package.name
    | None -> true)

let gen ~contexts ~build_system
      ?(external_lib_deps_mode=false)
      ?only_packages conf =
  let open Fiber.O in
  let { Dune_load. file_tree; dune_files; packages; projects } = conf in
  let packages =
    match only_packages with
    | None -> packages
    | Some pkgs ->
      Package.Name.Map.filter packages ~f:(fun { Package.name; _ } ->
        Package.Name.Set.mem pkgs name)
  in
  let sctxs = Hashtbl.create 4 in
  List.iter contexts ~f:(fun c ->
    Hashtbl.add sctxs c.Context.name (Fiber.Ivar.create ()));
  let make_sctx (context : Context.t) : _ Fiber.t =
    let host () =
      match context.for_host with
      | None -> Fiber.return None
      | Some h ->
        Fiber.Ivar.read (Option.value_exn (Hashtbl.find sctxs h.name))
        >>| fun x -> Some x
    in
    let stanzas () =
      Dune_load.Dune_files.eval ~context dune_files >>| fun stanzas ->
      match only_packages with
      | None -> stanzas
      | Some pkgs ->
        List.map stanzas ~f:(fun (dir_conf : Dune_load.Dune_file.t) ->
          { dir_conf with
            stanzas = relevant_stanzas pkgs dir_conf.stanzas
          })
    in
    Fiber.fork_and_join host stanzas >>= fun (host, stanzas) ->
    let sctx =
      Super_context.create
        ?host
        ~build_system
        ~context
        ~projects
        ~file_tree
        ~packages
        ~external_lib_deps_mode
        ~stanzas
    in
    let module P = struct let sctx = sctx end in
    let module M = Gen(P) in
    Fiber.Ivar.fill (Option.value_exn (Hashtbl.find sctxs context.name)) sctx
    >>| fun () ->
    (context.name, (module M : Gen))
  in
  Fiber.parallel_map contexts ~f:make_sctx >>| fun l ->
  let map = String.Map.of_list_exn l in
  Build_system.set_rule_generators build_system
    (String.Map.map map ~f:(fun (module M : Gen) -> M.gen_rules));
  String.Map.iter map ~f:(fun (module M : Gen) -> M.init ());
  String.Map.map map ~f:(fun (module M : Gen) -> M.sctx)
