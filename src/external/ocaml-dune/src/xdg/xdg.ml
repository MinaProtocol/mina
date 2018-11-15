let home =
  try
    Sys.getenv "HOME"
  with Not_found ->
    try
      (Unix.getpwuid (Unix.getuid ())).Unix.pw_dir
    with Unix.Unix_error _ | Not_found ->
      if Sys.win32 then
        try
          Sys.getenv "AppData"
        with Not_found ->
          ""
      else
        ""

let ( / ) = Filename.concat

let get env_var unix_default win32_default =
  try
    Sys.getenv env_var
  with Not_found ->
    if Sys.win32 then win32_default else unix_default

let cache_dir =
  get "XDG_CACHE_HOME"
    (home / ".cache")
    (home / "Local Settings" / "Cache")

let config_dir =
  get "XDG_CONFIG_HOME"
    (home / ".config")
    (home / "Local Settings")

let data_dir =
  get "XDG_DATA_HOME"
    (home / ".local" / "share")
    (try Sys.getenv "AppData" with Not_found -> "")
