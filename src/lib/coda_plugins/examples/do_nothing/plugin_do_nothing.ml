let coda = Coda_plugins.get_coda_lib ()

let () =
  let config = Coda_lib.config coda in
  Logger.info config.logger "Hi from do-nothing plugin!" ~module_:__MODULE__
    ~location:__LOC__
