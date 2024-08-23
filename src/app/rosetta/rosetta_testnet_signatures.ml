open Lib.Rosetta
open Async

let () =
  Command.run
    (Command.async ~summary:"Run Rosetta process on top of Mina"
       (command
          ~account_creation_fee:
            Genesis_constants_compiled.Constraint_constants.t
              .account_creation_fee
          ~minimum_user_command_fee:
            Genesis_constants_compiled.t.minimum_user_command_fee ) )
