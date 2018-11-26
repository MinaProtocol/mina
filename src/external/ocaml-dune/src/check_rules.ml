open Stdune

let dev_files p =
  match Path.extension p with
  | ".cmt"
  | ".cmti"
  | ".cmi" -> true
  | _ -> false

let add_obj_dir sctx ~dir ~obj_dir =
  if (Super_context.context sctx).merlin then
    Super_context.add_alias_deps
      sctx
      (Build_system.Alias.check ~dir)
      ~dyn_deps:(Build.paths_matching ~loc:Loc.none ~dir:obj_dir dev_files)
      Path.Set.empty
