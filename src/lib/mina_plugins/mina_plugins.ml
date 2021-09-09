open Core_kernel

let mina_lib' : Mina_lib.t option ref = ref None

exception Not_initializing

let get_mina_lib () =
  match !mina_lib' with Some coda -> coda | None -> raise Not_initializing

let init_plugins ~logger coda plugin_paths =
  [%log info] "Initializing plugins" ;
  mina_lib' := Some coda ;
  List.iter plugin_paths ~f:(fun path ->
      [%log info] "Initializing plugin from $path"
        ~metadata:[("path", `String path)] ;
      try
        Dynlink.loadfile path ;
        [%log info] "Plugin successfully loaded from $path"
          ~metadata:[("path", `String path)]
      with Dynlink.Error err as exn ->
        [%log error] "Failed to load plugin from $path: $error"
          ~metadata:
            [ ("path", `String path)
            ; ("error", `String (Dynlink.error_message err)) ] ;
        raise exn ) ;
  mina_lib' := None
