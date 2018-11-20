open! Stdune
open Import
open Dune_file
open Build.O
open! No_io

module SC = Super_context

let interpret_locks sctx ~dir ~scope locks =
  List.map locks ~f:(SC.expand_vars_path sctx ~dir ~scope)

let dep_bindings ~extra_bindings deps =
  let base = Pform.Map.of_bindings deps in
  match extra_bindings with
  | Some bindings -> Pform.Map.superpose base bindings
  | None -> base

let user_rule sctx ?extra_bindings ~dir ~scope (rule : Rule.t) =
  if SC.eval_blang sctx rule.enabled_if ~dir ~scope then begin
    let targets : Expander.targets =
      match rule.targets with
      | Infer -> Infer
      | Static fns ->
        let f fn =
          let not_in_dir ~error_loc s =
            Errors.fail
              error_loc
              "%s does not denote a file in the current directory" s;
          in
          let error_loc = String_with_vars.loc fn in
          List.map ~f:(function
            | Value.String ("." | "..") ->
              Errors.fail error_loc "'.' and '..' are not valid filenames"
            | String s ->
              if Filename.dirname s <> Filename.current_dir_name then
                not_in_dir ~error_loc s;
              Path.relative ~error_loc dir s
            | Path p ->
              if Path.parent p <> Some dir then
                not_in_dir ~error_loc (Path.to_string p);
              p
            | Dir p ->
              not_in_dir ~error_loc (Path.to_string p)
          ) (SC.expand_vars sctx ~mode:Many ~scope ~dir fn)
        in
        Static (List.concat_map ~f fns)
    in
    let bindings = dep_bindings ~extra_bindings rule.deps in
    SC.add_rule_get_targets sctx ~dir ~mode:rule.mode ~loc:rule.loc
      ~locks:(interpret_locks sctx ~dir ~scope rule.locks)
      (SC.Deps.interpret_named sctx ~scope ~dir rule.deps
       >>>
       SC.Action.run
         sctx
         (snd rule.action)
         ~loc:(fst rule.action)
         ~dir
         ~bindings
         ~dep_kind:Required
         ~targets
         ~targets_dir:dir
         ~scope)
  end else
    []

let copy_files sctx ~dir ~scope ~src_dir (def: Copy_files.t) =
  let loc = String_with_vars.loc def.glob in
  let glob_in_src =
    let src_glob = SC.expand_vars_string sctx ~dir def.glob ~scope in
    Path.relative src_dir src_glob ~error_loc:loc
  in
  let since = (1, 3) in
  if def.syntax_version < since
  && not (Path.is_descendant glob_in_src ~of_:src_dir) then
    Syntax.Error.since loc Stanza.syntax since
      ~what:(sprintf "%s is not a sub-directory of %s. This"
               (Path.to_string_maybe_quoted glob_in_src)
               (Path.to_string_maybe_quoted src_dir));
  let glob = Path.basename glob_in_src in
  let src_in_src = Path.parent_exn glob_in_src in
  let re =
    match Glob_lexer.parse_string glob with
    | Ok re ->
      Re.compile re
    | Error (_pos, msg) ->
      Errors.fail (String_with_vars.loc def.glob) "invalid glob: %s" msg
  in
  let file_tree = Super_context.file_tree sctx in
  if not (File_tree.dir_exists file_tree src_in_src) then
    Errors.fail
      loc
      "cannot find directory: %a"
      Path.pp src_in_src;
  (* add rules *)
  let src_in_build = Path.append (SC.context sctx).build_dir src_in_src in
  let files = SC.eval_glob sctx ~dir:src_in_build re in
  List.map files ~f:(fun basename ->
    let file_src = Path.relative src_in_build basename in
    let file_dst = Path.relative dir basename in
    SC.add_rule sctx ~loc ~dir
      ((if def.add_line_directive
        then Build.copy_and_add_line_directive
        else Build.copy)
         ~src:file_src
         ~dst:file_dst);
    file_dst)

let add_alias sctx ~dir ~name ~stamp ~loc ?(locks=[]) build =
  let alias = Build_system.Alias.make name ~dir in
  SC.add_alias_action sctx alias ~dir ~loc ~locks ~stamp build

let alias sctx ?extra_bindings ~dir ~scope (alias_conf : Alias_conf.t) =
  let stamp =
    ( "user-alias"
    , Bindings.map
        ~f:Dune_file.Dep_conf.remove_locs alias_conf.deps
    , Option.map ~f:(fun (_loc, a) -> Action_unexpanded.remove_locs a)
        alias_conf.action
    , Option.map extra_bindings ~f:Pform.Map.to_stamp
    )
  in
  let loc = Some alias_conf.loc in
  if SC.eval_blang sctx alias_conf.enabled_if ~dir ~scope then
    add_alias sctx
      ~dir
      ~loc
      ~name:alias_conf.name
      ~stamp
      ~locks:(interpret_locks sctx ~dir ~scope alias_conf.locks)
      (SC.Deps.interpret_named sctx ~scope ~dir alias_conf.deps
       >>>
       match alias_conf.action with
       | None -> Build.progn []
       | Some (loc, action) ->
         let bindings = dep_bindings ~extra_bindings alias_conf.deps in
         SC.Action.run
           sctx
           action
           ~loc
           ~dir
           ~dep_kind:Required
           ~bindings
           ~targets:Alias
           ~targets_dir:dir
           ~scope)
  else
    add_alias sctx
      ~loc
      ~dir
      ~name:alias_conf.name
      ~stamp
      (Build.return (Action.Progn []))
