open Import
open! No_io

let rules (t : Dune_file.Tests.t) ~sctx ~dir ~scope ~dir_contents ~dir_kind =
  let test_kind (loc, name) =
    let files = Dir_contents.text_files dir_contents in
    let expected_basename = name ^ ".expected" in
    if String.Set.mem files expected_basename then
      `Expect
        { Action_unexpanded.Diff.
          file1 = String_with_vars.make_text loc expected_basename
        ; file2 = String_with_vars.make_text loc (name ^ ".output")
        ; optional = false
        ; mode = Text
        }
    else
      `Regular
  in
  List.iter t.exes.names ~f:(fun (loc, s) ->
    let test_var_name = "test" in
    let run_action =
      match t.action with
      | Some a -> a
      | None -> Action_unexpanded.Run (
        String_with_vars.make_var loc test_var_name, [])
    in
    let extra_bindings =
      let test_exe = s ^ ".exe" in
      let test_exe_path =
        Super_context.Action.map_exe sctx (Path.relative dir test_exe) in
      Pform.Map.singleton test_var_name (Values [Path test_exe_path]) in
    let add_alias ~loc ~action ~locks =
      let alias =
        { Dune_file.Alias_conf.
          name = "runtest"
        ; locks
        ; package = t.package
        ; deps = t.deps
        ; action = Some (loc, action)
        ; enabled_if = t.enabled_if
        ; loc
        }
      in
      Simple_rules.alias sctx ~extra_bindings ~dir ~scope alias
    in
    match test_kind (loc, s) with
    | `Regular ->
      add_alias ~loc ~action:run_action ~locks:[]
    | `Expect diff ->
      let rule =
        { Dune_file.Rule.
          targets = Infer
        ; deps = Bindings.empty
        ; action =
            (loc, Action_unexpanded.Redirect (Stdout, diff.file2, run_action))
        ; mode = Standard
        ; locks = t.locks
        ; loc
        ; enabled_if = t.enabled_if
        } in
      add_alias ~loc ~action:(Diff diff) ~locks:t.locks;
      ignore (Simple_rules.user_rule sctx rule ~extra_bindings ~dir ~scope
              : Path.t list));
  Exe_rules.rules t.exes ~sctx ~dir ~scope ~dir_kind ~dir_contents
