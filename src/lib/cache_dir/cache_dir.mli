val autogen_path : string

val s3_install_path : string

val s3_keys_bucket_prefix : string

val manual_install_path : string

val brew_install_path : string

val cache : Key_cache.Spec.t list

val env_path : string

val possible_paths : string -> string list

val load_from_s3 :
     string list
  -> string list
  -> logger:Logger.t
  -> unit Async_kernel.Deferred.Or_error.t
