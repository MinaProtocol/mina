val autogen_path : string

val gs_install_path : string

val gs_ledger_bucket_prefix : string

val manual_install_path : string

val brew_install_path : string

val cache : Key_cache.Spec.t list

val env_path : string

val possible_paths : string -> string list

val load_from_gs :
     string
  -> gs_bucket_prefix:string
  -> gs_object_name:string
  -> logger:Logger.t
  -> unit Async_kernel.Deferred.Or_error.t
