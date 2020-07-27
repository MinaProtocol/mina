open Core_kernel

let coda_lib' : Coda_lib.t option ref = ref None

exception Not_initializing

let get_coda_lib () =
  match !coda_lib' with Some coda -> coda | None -> raise Not_initializing

let init_plugins ~logger coda plugin_paths =
  Logger.info logger "Initializing plugins" ~module_:__MODULE__
    ~location:__LOC__ ;
  coda_lib' := Some coda ;
  List.iter plugin_paths ~f:(fun path ->
      Logger.info logger "Initializing plugin from $path" ~module_:__MODULE__
        ~location:__LOC__
        ~metadata:[("path", `String path)] ;
      try
        Dynlink.loadfile path ;
        Logger.info logger "Plugin successfully loaded from $path"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("path", `String path)]
      with Dynlink.Error err ->
        Logger.error logger "Failed to load plugin from $path: $error"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("path", `String path)
            ; ("error", `String (Dynlink.error_message err)) ] ) ;
  coda_lib' := None
