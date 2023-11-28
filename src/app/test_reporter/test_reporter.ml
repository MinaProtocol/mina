open Core

let test_result_commands = [ ("generate", Test_result.generate_test_result) ]

let commands =
  [ ( "test-result"
    , Command.group ~summary:"Test artifacts related commands"
        test_result_commands )
  ]

let () =
  Command.run
    (Command.group ~summary:"Test reporter main commands"
       ~preserve_subcommand_order:() commands )
