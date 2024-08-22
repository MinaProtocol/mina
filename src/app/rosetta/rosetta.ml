open Lib.Rosetta
open Async

let () =
  let genesis_constants =
    Genesis_constants_compiled.compiled_config.genesis_constants
  in
  let constraint_constants =
    Genesis_constants_compiled.compiled_config.constraint_constants
  in
  Command.run
    (Command.async ~summary:"Run Rosetta process on top of Mina"
       (command ~account_creation_fee:constraint_constants.account_creation_fee
          ~minimum_user_command_fee:genesis_constants.minimum_user_command_fee ) )
