module Configurator = Configurator.V1

let () =
  Configurator.main ~name:"test_configurator" (fun _ -> ())
