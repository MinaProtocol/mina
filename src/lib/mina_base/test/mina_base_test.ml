open Alcotest
open Mina_base


let () =
  run "Test mina_base."
    [ Zkapp_account_test.( "zkapp-accounts"
      , [ test_case "Events pop after push is idempotent." `Quick
            (checked_pop_reverses_push (module Zkapp_account.Events))
        ; test_case "Actions pop after push is idempotent." `Quick
            (checked_pop_reverses_push (module Zkapp_account.Actions))
        ] )
    ]
