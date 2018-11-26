open! Stdune
open Import
open Dune_file

module A = Action
module Alias = Build_system.Alias

module Dir_with_dune = struct
  type t =
    { src_dir : Path.t
    ; ctx_dir : Path.t
    ; stanzas : Stanzas.t
    ; scope   : Scope.t
    ; kind    : Dune_lang.Syntax.t
    }
end

module Installable = struct
  type t =
    { dir    : Path.t
    ; scope  : Scope.t
    ; stanza : Stanza.t
    ; kind   : Dune_lang.Syntax.t
    }
end

type t =
  { context                          : Context.t
  ; build_system                     : Build_system.t
  ; scopes                           : Scope.DB.t
  ; public_libs                      : Lib.DB.t
  ; installed_libs                   : Lib.DB.t
  ; stanzas                          : Dir_with_dune.t list
  ; stanzas_per_dir                  : Dir_with_dune.t Path.Map.t
  ; packages                         : Package.t Package.Name.Map.t
  ; file_tree                        : File_tree.t
  ; artifacts                        : Artifacts.t
  ; stanzas_to_consider_for_install  : Installable.t list
  ; cxx_flags                        : string list
  ; expander                         : Expander.t
  ; chdir                            : (Action.t, Action.t) Build.t
  ; host                             : t option
  ; libs_by_package : (Package.t * Lib.Set.t) Package.Name.Map.t
  ; env                              : (Path.t, Env_node.t) Hashtbl.t
  ; (* Env node that represent the environment configured for the
       workspace. It is used as default at the root of every project
       in the workspace. *)
    default_env : Env_node.t Lazy.t
  }

let context t = t.context
let stanzas t = t.stanzas
let stanzas_in t ~dir = Path.Map.find t.stanzas_per_dir dir
let packages t = t.packages
let libs_by_package t = t.libs_by_package
let artifacts t = t.artifacts
let file_tree t = t.file_tree
let stanzas_to_consider_for_install t = t.stanzas_to_consider_for_install
let cxx_flags t = t.cxx_flags
let build_dir t = t.context.build_dir
let profile t = t.context.profile
let build_system t = t.build_system

let host t = Option.value t.host ~default:t

let internal_lib_names t =
  List.fold_left t.stanzas ~init:Lib_name.Set.empty
    ~f:(fun acc { Dir_with_dune. stanzas; _ } ->
      List.fold_left stanzas ~init:acc ~f:(fun acc -> function
        | Library lib ->
          Lib_name.Set.add
            (match lib.public with
             | None -> acc
             | Some { name = (_, name); _ } ->
               Lib_name.Set.add acc name)
            (Lib_name.of_local lib.name)
        | _ -> acc))

let public_libs    t = t.public_libs
let installed_libs t = t.installed_libs

let find_scope_by_dir  t dir  = Scope.DB.find_by_dir  t.scopes dir
let find_scope_by_name t name = Scope.DB.find_by_name t.scopes name

let prefix_rules t prefix ~f =
  Build_system.prefix_rules t.build_system prefix ~f

module External_env = Env

module Env : sig
  val ocaml_flags : t -> dir:Path.t -> Ocaml_flags.t
  val external_ : t -> dir:Path.t -> External_env.t
  val artifacts_host : t -> dir:Path.t -> Artifacts.t
  val expander : t -> dir:Path.t -> Expander.t
  val file_bindings : t -> dir:Path.t -> string File_bindings.t
end = struct
  let get_env_stanza t ~dir =
    let open Option.O in
    stanzas_in t ~dir >>= fun x ->
    List.find_map x.stanzas ~f:(function
      | Dune_env.T config -> Some config
      | _ -> None)

  let rec get t ~dir ~scope =
    match Hashtbl.find t.env dir with
    | Some node -> node
    | None ->
      let node =
        let inherit_from =
          if Path.equal dir (Scope.root scope) then
            t.default_env
          else
            match Path.parent dir with
            | None -> raise_notrace Exit
            | Some parent -> lazy (get t ~dir:parent ~scope)
        in
        match get_env_stanza t ~dir with
        | None -> Lazy.force inherit_from
        | Some config ->
          Env_node.make ~dir ~scope ~config ~inherit_from:(Some inherit_from)
            ~env:None
      in
      Hashtbl.add t.env dir node;
      node

  let get t ~dir =
    match Hashtbl.find t.env dir with
    | Some node -> node
    | None ->
      let scope = find_scope_by_dir t dir in
      try
        get t ~dir ~scope
      with Exit ->
        Exn.code_error "Super_context.Env.get called on invalid directory"
          [ "dir", Path.to_sexp dir ]

  let external_ t  ~dir =
    Env_node.external_ (get t ~dir) ~profile:(profile t) ~default:t.context.env

  let expander_for_artifacts t ~dir =
    let node = get t ~dir in
    let external_ = external_ t ~dir in
    Expander.extend_env t.expander ~env:external_
    |> Expander.set_scope ~scope:(Env_node.scope node)
    |> Expander.set_dir ~dir

  let file_bindings t ~dir =
    let node = get t ~dir in
    let expander = expander_for_artifacts t ~dir in
    Env_node.file_bindings node ~profile:(profile t) ~expander

  let artifacts t ~dir =
    let expander = expander_for_artifacts t ~dir in
    Env_node.artifacts (get t ~dir) ~profile:(profile t) ~default:t.artifacts
      ~expander

  let artifacts_host t ~dir =
    match t.host with
    | None -> artifacts t ~dir
    | Some host ->
      let dir =
        Path.append host.context.build_dir (Path.drop_build_context_exn dir) in
      artifacts host ~dir

  let expander t ~dir =
    let expander = expander_for_artifacts t ~dir in
    let artifacts = artifacts t ~dir in
    let artifacts_host = artifacts_host t ~dir in
    Expander.set_artifacts expander ~artifacts ~artifacts_host

  let ocaml_flags t ~dir =
    Env_node.ocaml_flags (get t ~dir)
      ~profile:(profile t) ~expander:(expander t ~dir)
end


let add_rule t ?sandbox ?mode ?locks ?loc ~dir build =
  let build = Build.O.(>>>) build t.chdir in
  let env = Env.external_ t ~dir in
  Build_system.add_rule t.build_system
    (Build_interpret.Rule.make ?sandbox ?mode ?locks ?loc
       ~context:(Some t.context) ~env:(Some env) build)

let add_rule_get_targets t ?sandbox ?mode ?locks ?loc ~dir build =
  let build = Build.O.(>>>) build t.chdir in
  let env = Env.external_ t ~dir in
  let rule =
    Build_interpret.Rule.make ?sandbox ?mode ?locks ?loc
      ~context:(Some t.context) ~env:(Some env) build
  in
  Build_system.add_rule t.build_system rule;
  List.map rule.targets ~f:Build_interpret.Target.path

let add_rules t ?sandbox ~dir builds =
  List.iter builds ~f:(add_rule t ?sandbox ~dir)

let add_alias_deps t alias ?dyn_deps deps =
  Alias.add_deps t.build_system alias ?dyn_deps deps

let add_alias_action t alias ~dir ~loc ?locks ~stamp action =
  let env = Some (Env.external_ t ~dir) in
  Alias.add_action t.build_system ~context:t.context ~env alias ~loc ?locks
    ~stamp action

let eval_glob t ~dir re = Build_system.eval_glob t.build_system ~dir re
let load_dir t ~dir = Build_system.load_dir t.build_system ~dir
let on_load_dir t ~dir ~f = Build_system.on_load_dir t.build_system ~dir ~f

let source_files t ~src_path =
  match File_tree.find_dir t.file_tree src_path with
  | None -> String.Set.empty
  | Some dir -> File_tree.Dir.files dir

module Pkg_version = struct
  open Build.O

  module V = Vfile_kind.Make(struct
      type t = string option
      let encode = Dune_lang.Encoder.(option string)
      let name = "Pkg_version"
    end)

  let spec sctx (p : Package.t) =
    let fn =
      Path.relative (Path.append sctx.context.build_dir p.path)
        (sprintf "%s.version.sexp" (Package.Name.to_string p.name))
    in
    Build.Vspec.T (fn, (module V))

  let read sctx p = Build.vpath (spec sctx p)

  let set sctx p get =
    let spec = spec sctx p in
    add_rule sctx ~dir:(build_dir sctx)
      (get >>> Build.store_vfile spec);
    Build.vpath spec
end

let partial_expand sctx ~dep_kind ~targets_written_by_user ~map_exe
      ~expander t =
  let acc = Expander.Resolved_forms.empty () in
  let read_package = Pkg_version.read sctx in
  let expander =
    Expander.with_record_deps expander  acc ~dep_kind ~targets_written_by_user
      ~map_exe ~read_package in
  let partial = Action_unexpanded.partial_expand t ~expander ~map_exe in
  (partial, acc)


let ocaml_flags t ~dir (x : Buildable.t) =
  let expander = Env.expander t ~dir in
  Ocaml_flags.make
    ~flags:x.flags
    ~ocamlc_flags:x.ocamlc_flags
    ~ocamlopt_flags:x.ocamlopt_flags
    ~default:(Env.ocaml_flags t ~dir)
    ~eval:(Expander.expand_and_eval_set expander)

let file_bindings t ~dir = Env.file_bindings t ~dir

let dump_env t ~dir =
  Ocaml_flags.dump (Env.ocaml_flags t ~dir)

let resolve_program t ~dir ?hint ~loc bin =
  let artifacts = Env.artifacts_host t ~dir in
  Artifacts.binary ?hint ~loc artifacts bin

let create
      ~(context:Context.t)
      ?host
      ~projects
      ~file_tree
      ~packages
      ~stanzas
      ~external_lib_deps_mode
      ~build_system
  =
  let installed_libs =
    Lib.DB.create_from_findlib context.findlib ~external_lib_deps_mode
  in
  let internal_libs =
    List.concat_map stanzas
      ~f:(fun { Dune_load.Dune_file. dir; stanzas; project = _ ; kind = _ } ->
        let ctx_dir = Path.append context.build_dir dir in
        List.filter_map stanzas ~f:(fun stanza ->
          match (stanza : Stanza.t) with
          | Library lib -> Some (ctx_dir, lib)
          | _ -> None))
  in
  let scopes, public_libs =
    Scope.DB.create
      ~projects
      ~context:context.name
      ~installed_libs
      ~ext_lib:context.ext_lib
      ~ext_obj:context.ext_obj
      internal_libs
  in
  let stanzas =
    List.map stanzas
      ~f:(fun { Dune_load.Dune_file. dir; project; stanzas; kind } ->
        let ctx_dir = Path.append context.build_dir dir in
        { Dir_with_dune.
          src_dir = dir
        ; ctx_dir
        ; stanzas
        ; scope = Scope.DB.find_by_name scopes (Dune_project.name project)
        ; kind
        })
  in
  let stanzas_per_dir =
    List.map stanzas ~f:(fun stanzas ->
      (stanzas.Dir_with_dune.ctx_dir, stanzas))
    |> Path.Map.of_list_exn
  in
  let stanzas_to_consider_for_install =
    if not external_lib_deps_mode then
      List.concat_map stanzas
        ~f:(fun { ctx_dir; stanzas; scope; kind ; src_dir = _ } ->
          List.filter_map stanzas ~f:(fun stanza ->
            let keep =
              match (stanza : Stanza.t) with
              | Library lib ->
                Lib.DB.available (Scope.libs scope) (Library.best_name lib)
              | Documentation _
              | Install _   -> true
              | _           -> false
            in
            Option.some_if keep { Installable.
                                  dir = ctx_dir
                                ; scope
                                ; stanza
                                ; kind
                                }))
    else
      List.concat_map stanzas
        ~f:(fun { ctx_dir; stanzas; scope; kind ; src_dir = _ } ->
          List.map stanzas ~f:(fun stanza ->
            { Installable.
              dir = ctx_dir
            ; scope
            ; stanza
            ; kind
            }))
  in
  let artifacts =
    Artifacts.create context ~public_libs ~build_system
  in
  let cxx_flags =
    List.filter context.ocamlc_cflags
      ~f:(fun s -> not (String.is_prefix s ~prefix:"-std="))
  in
  let default_env = lazy (
    let make ~inherit_from ~config =
      Env_node.make
        ~dir:context.build_dir
        ~env:None
        ~scope:(Scope.DB.find_by_dir scopes context.build_dir)
        ~inherit_from
        ~config
    in
    match context.env_nodes with
    | { context = None; workspace = None } ->
      make ~config:{ loc = Loc.none; rules = [] } ~inherit_from:None
    | { context = Some config; workspace = None }
    | { context = None; workspace = Some config } ->
      make ~config ~inherit_from:None
    | { context = Some context ; workspace = Some workspace } ->
      make ~config:context
        ~inherit_from:(Some (lazy (make ~inherit_from:None ~config:workspace)))
  ) in
  let expander =
    let artifacts_host =
      match host with
      | None -> artifacts
      | Some host -> host.artifacts
    in
    Expander.make
      ~scope:(Scope.DB.find_by_dir scopes context.build_dir)
      ~context
      ~artifacts
      ~artifacts_host
      ~cxx_flags
  in
  { context
  ; expander
  ; host
  ; build_system
  ; scopes
  ; public_libs
  ; installed_libs
  ; stanzas
  ; stanzas_per_dir
  ; packages
  ; file_tree
  ; stanzas_to_consider_for_install
  ; artifacts
  ; cxx_flags
  ; chdir = Build.arr (fun (action : Action.t) ->
      match action with
      | Chdir _ -> action
      | _ -> Chdir (context.build_dir, action))
  ; libs_by_package =
      Lib.DB.all public_libs
      |> Lib.Set.to_list
      |> List.map ~f:(fun lib ->
        (Option.value_exn (Lib.package lib), lib))
      |> Package.Name.Map.of_list_multi
      |> Package.Name.Map.merge packages ~f:(fun _name pkg libs ->
        let pkg  = Option.value_exn pkg          in
        let libs = Option.value libs ~default:[] in
        Some (pkg, Lib.Set.of_list libs))
  ; env = Hashtbl.create 128
  ; default_env
  }

module Libs = struct
  open Build.O

  let gen_select_rules t ~dir compile_info =
    List.iter (Lib.Compile.resolved_selects compile_info) ~f:(fun rs ->
      let { Lib.Compile.Resolved_select.dst_fn; src_fn } = rs in
      let dst = Path.relative dir dst_fn in
      add_rule t
        ~dir
        (match src_fn with
         | Ok src_fn ->
           let src = Path.relative dir src_fn in
           Build.copy_and_add_line_directive ~src ~dst
         | Error e ->
           Build.fail ~targets:[dst]
             { fail = fun () ->
                 raise (Lib.Error (No_solution_found_for_select e))
             }))

  let with_lib_deps t compile_info ~dir ~f =
    let prefix =
      Lib.Compile.user_written_deps compile_info
      |> Dune_file.Lib_deps.info ~kind:(Lib.Compile.optional compile_info)
      |> Build.record_lib_deps
    in
    let prefix =
      if t.context.merlin then
        Build.path (Path.relative dir ".merlin-exists")
        >>>
        prefix
      else
        prefix
    in
    prefix_rules t prefix ~f
end

let expand_vars t ~mode ~scope ~dir ?(bindings=Pform.Map.empty) template =
  Env.expander t ~dir
  |> Expander.add_bindings ~bindings
  |> Expander.set_scope ~scope
  |> Expander.expand ~mode ~template

let expand_vars_string t ~scope ~dir ?bindings s =
  expand_vars t ~mode:Single ~scope ~dir ?bindings s
  |> Value.to_string ~dir

let expand_vars_path t ~scope ~dir ?bindings s =
  expand_vars t ~mode:Single ~scope ~dir ?bindings s
  |> Value.to_path ~error_loc:(String_with_vars.loc s) ~dir

let eval_blang t blang ~scope ~dir =
  match blang with
  | Blang.Const x -> x (* common case *)
  | _ ->
    let expander = Expander.set_scope (Env.expander t ~dir) ~scope in
    Blang.eval blang ~dir ~f:(Expander.expand_var_exn expander)

module Deps = struct
  open Build.O
  open Dep_conf

  let make_alias expander s =
    let loc = String_with_vars.loc s in
    Expander.expand_path expander s
    |> Alias.of_user_written_path ~loc

  let dep t expander = function
    | File s ->
      let path = Expander.expand_path expander s in
      Build.path path
      >>^ fun () -> [path]
    | Alias s ->
      Alias.dep (make_alias expander s)
      >>^ fun () -> []
    | Alias_rec s ->
      Alias.dep_rec ~loc:(String_with_vars.loc s) ~file_tree:t.file_tree
        (make_alias expander s)
      >>^ fun () -> []
    | Glob_files s -> begin
        let loc = String_with_vars.loc s in
        let path = Expander.expand_path expander s in
        match Glob_lexer.parse_string (Path.basename path) with
        | Ok re ->
          let dir = Path.parent_exn path in
          Build.paths_glob ~loc ~dir (Re.compile re)
          >>^ Path.Set.to_list
        | Error (_pos, msg) ->
          Errors.fail (String_with_vars.loc s) "invalid glob: %s" msg
      end
    | Source_tree s ->
      let path = Expander.expand_path expander s in
      Build.source_tree ~dir:path ~file_tree:t.file_tree
      >>^ Path.Set.to_list
    | Package p ->
      let pkg = Package.Name.of_string (Expander.expand_str expander p) in
      Alias.dep (Alias.package_install ~context:t.context ~pkg)
      >>^ fun () -> []
    | Universe ->
      Build.path Build_system.universe_file
      >>^ fun () -> []
    | Env_var var_sw ->
      let var = Expander.expand_str expander var_sw in
      Build.env_var var
      >>^ fun () -> []

  let make_interpreter ~f t ~scope ~dir l =
    let forms = Expander.Resolved_forms.empty () in
    let expander =
      Env.expander t ~dir
      |> Expander.set_scope ~scope
      |> Expander.set_dir ~dir
    in
    let expander =
      Expander.with_record_no_ddeps expander forms
        ~dep_kind:Optional ~map_exe:(fun x -> x)
    in
    let deps =
      List.map l ~f:(f t expander)
      |> Build.all
      >>^ List.concat in
    Build.fanout4
      deps
      (Build.record_lib_deps (Expander.Resolved_forms.lib_deps forms))
      (let ddeps = String.Map.to_list (Expander.Resolved_forms.ddeps forms) in
       Build.all (List.map ddeps ~f:snd))
      (Build.path_set (Expander.Resolved_forms.sdeps forms))
    >>^ (fun (deps, _, _, _) -> deps)

  let interpret = make_interpreter ~f:dep

  let interpret_named =
    make_interpreter ~f:(fun t expander -> function
      | Bindings.Unnamed p ->
        dep t expander p >>^ fun l ->
        List.map l ~f:(fun x -> Bindings.Unnamed x)
      | Named (s, ps) ->
        Build.all (List.map ps ~f:(dep t expander)) >>^ fun l ->
        [Bindings.Named (s, List.concat l)])
end

module Scope_key = struct
  let of_string sctx key =
    match String.rsplit2 key ~on:'@' with
    | None ->
      (key, public_libs sctx)
    | Some (key, scope) ->
      ( key
      , Scope.libs (find_scope_by_name sctx
                      (Dune_project.Name.of_encoded_string scope)))

  let to_string key scope =
    sprintf "%s@%s" key (Dune_project.Name.to_encoded_string scope)
end

module Action = struct
  open Build.O
  module U = Action_unexpanded

  let map_exe sctx =
    match sctx.host with
    | None -> (fun exe -> exe)
    | Some host ->
      fun exe ->
        match Path.extract_build_context_dir exe with
        | Some (dir, exe) when Path.equal dir sctx.context.build_dir ->
          Path.append host.context.build_dir exe
        | _ -> exe

  let run sctx ~loc ~bindings ~dir ~dep_kind
        ~targets:targets_written_by_user ~targets_dir ~scope t
    : (Path.t Bindings.t, Action.t) Build.t =
    let expander =
      Env.expander sctx ~dir
      |> Expander.add_bindings ~bindings
      |> Expander.set_scope ~scope
    in
    let map_exe = map_exe sctx in
    if targets_written_by_user = Expander.Alias then begin
      match U.Infer.unexpanded_targets t with
      | [] -> ()
      | x :: _ ->
        let loc = String_with_vars.loc x in
        Errors.warn loc
          "Aliases must not have targets, this target will be ignored.\n\
           This will become an error in the future.";
    end;
    let t, forms =
      partial_expand sctx ~expander ~dep_kind
        ~targets_written_by_user ~map_exe t
    in
    let { U.Infer.Outcome. deps; targets } =
      match targets_written_by_user with
      | Infer -> U.Infer.partial t ~all_targets:true
      | Static targets_written_by_user ->
        let targets_written_by_user = Path.Set.of_list targets_written_by_user in
        let { U.Infer.Outcome. deps; targets } =
          U.Infer.partial t ~all_targets:false
        in
        { deps; targets = Path.Set.union targets targets_written_by_user }
      | Alias ->
        let { U.Infer.Outcome. deps; targets = _ } =
          U.Infer.partial t ~all_targets:false
        in
        { deps; targets = Path.Set.empty }
    in
    let targets = Path.Set.to_list targets in
    List.iter targets ~f:(fun target ->
      if Path.parent_exn target <> targets_dir then
        Errors.fail loc
          "This action has targets in a different directory than the current \
           one, this is not allowed by dune at the moment:\n%s"
          (List.map targets ~f:(fun target ->
             sprintf "- %s" (Utils.describe_target target))
           |> String.concat ~sep:"\n"));
    let build =
      Build.record_lib_deps (Expander.Resolved_forms.lib_deps forms)
      >>>
      Build.path_set (Path.Set.union deps (Expander.Resolved_forms.sdeps forms))
      >>>
      Build.arr (fun paths -> ((), paths))
      >>>
      let ddeps = String.Map.to_list (Expander.Resolved_forms.ddeps forms) in
      Build.first (Build.all (List.map ddeps ~f:snd))
      >>^ (fun (vals, deps_written_by_user) ->
        let dynamic_expansions =
          List.fold_left2 ddeps vals ~init:String.Map.empty
            ~f:(fun acc (var, _) value -> String.Map.add acc var value)
        in
        let unresolved =
          let expander =
            Expander.add_ddeps_and_bindings expander ~dynamic_expansions
              ~deps_written_by_user in
          U.Partial.expand t ~expander ~map_exe
        in
        let artifacts = Env.artifacts_host sctx ~dir in
        Action.Unresolved.resolve unresolved ~f:(fun loc prog ->
          match Artifacts.binary ~loc artifacts prog with
          | Ok path    -> path
          | Error fail -> Action.Prog.Not_found.raise fail))
      >>>
      Build.dyn_path_set (Build.arr (fun action ->
        let { U.Infer.Outcome.deps; targets = _ } =
          U.Infer.infer action
        in
        deps))
      >>>
      Build.action_dyn () ~dir ~targets
    in
    match Expander.Resolved_forms.failures forms with
    | [] -> build
    | fail :: _ -> Build.fail fail >>> build
end

let opaque t =
  t.context.profile = "dev"
  && Ocaml_version.supports_opaque_for_mli t.context.version

let expand_and_eval_set sctx ~scope ~dir ?bindings set ~standard =
  let expander = Expander.set_scope ~scope (Env.expander sctx ~dir) in
  let expander =
    match bindings with
    | None -> expander
    | Some bindings -> Expander.add_bindings expander ~bindings
  in
  Expander.expand_and_eval_set expander ~standard set
