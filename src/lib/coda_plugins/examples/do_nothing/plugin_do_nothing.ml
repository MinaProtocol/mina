let coda = Coda_plugins.get_coda_lib ()

let () =
  let config = Coda_lib.config coda in
  [%log' info config.logger] "Hi from do-nothing plugin!" ;
  if true then assert false
