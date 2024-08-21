open Lib.Rosetta
open Async

let () =
  let genesis_config = Genesis_constants_compiled.compiled_config in
  Command.run
    (Command.async ~summary:"Run Rosetta process on top of Mina"
       (command
          ~account_creation_fee:
            genesis_config.constraint_constants.account_creation_fee
          ~minimum_user_command_fee:
            genesis_config.genesis_constants.minimum_user_command_fee 
        ) 
    )
