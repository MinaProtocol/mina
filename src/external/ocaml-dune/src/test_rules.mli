val rules :
  Dune_file.Tests.t ->
  sctx:Super_context.t ->
  dir:Stdune.Path.t ->
  scope:Scope.t ->
  dir_contents:Dir_contents.t ->
  dir_kind:Dune_lang.syntax -> Compilation_context.t * Merlin.t
