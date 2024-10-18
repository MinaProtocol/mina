open Async
open Integration_test_lib

let constants : Test_config.constants =
  let protocol =
    { Genesis_constants.Compiled.genesis_constants.protocol with
      k = 20
    ; delta = 0
    ; slots_per_epoch = 3 * 8 * 20
    ; slots_per_sub_window = 2
    ; grace_period_slots = 140
    }
  in
  { genesis_constants =
      { Genesis_constants.Compiled.genesis_constants with
        protocol
      ; txpool_max_size = 3000
      }
  ; constraint_constants = Genesis_constants.Compiled.constraint_constants
  ; compile_config = Mina_compile_config.Compiled.t
  }

let default_test_config =
  let open Test_config in
  { (default ~constants) with
    genesis_ledger =
      (let open Test_account in
      [ Test_account.create ~account_name:"alice" ~balance:"1000000" ()
      ; create ~account_name:"bob" ~balance:"1000000" ()
      ; create ~account_name:"clarice" ~balance:"100000" ()
      ])
  ; block_producers =
      [ { node_name = "node-a"; account_name = "alice" }
      ; { node_name = "node-b"; account_name = "bob" }
      ; { node_name = "node-c"; account_name = "clarice" }
      ]
  }

let main ~config ~output ~no_num_accounts () =
  let test_config : Test_config.t =
    match config with
    | Some config ->
        Yojson.Safe.from_file config
        |> Test_config.of_yojson |> Core.Result.ok_or_failwith
    | None ->
        default_test_config
  in
  let%bind () = Unix.mkdir ~p:() output in
  let ledger = Genesis_ledger.create test_config.genesis_ledger in
  let%bind () = Genesis_ledger.write_keys_to ledger output in
  Genesis_ledger.write_ledger ~no_num_accounts ledger output ;
  Deferred.return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async ~summary:"Generate random ledger"
        (let%map output =
           Param.flag "--output" ~aliases:[ "output" ]
             ~doc:
               "PATH output path where keys and genesis ledger will be dumped"
             Param.(optional_with_default "." string)
         and config =
           Param.(flag "--config" ~aliases:[ "config" ])
             ~doc:
               "File input config. If not specified default configuration will \
                be applied"
             Param.(optional string)
         and no_num_accounts =
           Param.(flag "--no-num-accounts" no_arg)
             ~doc:"Do not include num_account in output ledger"
         in
         main ~config ~output ~no_num_accounts )))
