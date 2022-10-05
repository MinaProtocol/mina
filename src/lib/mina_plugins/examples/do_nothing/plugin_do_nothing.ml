let coda = Mina_plugins.get_mina_lib ()

let () =
  let config = Mina_lib.config coda in
  [%log' info config.logger] "Hi from do-nothing plugin!" ;
  if true then assert false
