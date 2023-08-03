open Core_kernel
open Integration_test_lib
open Ci_interaction

module Test_values = struct
  let config_file =
    (* cwd = ./_build/default/src/lib/integration_test_abstract_engine/ *)
    let cwd_list = String.split ~on:'/' @@ Sys.getcwd () in
    let dir_path =
      List.take cwd_list (List.length cwd_list - 5)
      @ [ "src/lib/integration_test_abstract_engine/config.json" ]
    in
    String.concat ~sep:"/" dir_path

  let deploy_network_raw_cmd =
    "minimina network deploy --network-id {{network_id}}"

  let start_node_raw_cmd =
    "minimina start-node --node-id {{node_id}} --fresh-state {{fresh_state}} \
     --git-commit {{git_commit}}"

  let deploy_network_action =
    sprintf
      {|
      {
        "name": "deploy_network",
        "args": {
          "network_id": "string"
        },
        "command": "%s"
      }
    |}
      deploy_network_raw_cmd
    |> String.strip

  let start_node_action =
    sprintf
      {|
      {
        "name": "start_node",
        "args": {
          "node_id": "string",
          "fresh_state": "bool",
          "git_commit": "string"
        },
        "command": "%s"
      }
    |}
      start_node_raw_cmd
    |> String.strip

  let config =
    sprintf
      {|
        {
          "version": 1,
          "actions": [%s,%s]
        }
      |}
      deploy_network_action start_node_action
    |> Yojson.Safe.from_string
end

open Test_values

module Config_tests = struct
  open Config_file

  let%test_unit "version" =
    let res = version config in
    let expect = 1 in
    assert (res = expect)

  let ( = ) = String.equal

  let%test_unit "raw command" =
    let res = raw_cmd @@ Yojson.Safe.from_string deploy_network_action in
    assert (res = deploy_network_raw_cmd)

  let%test_unit "validate arg types" =
    let bool_value = `Bool true in
    let int_value = `Int 42 in
    let string_value = `String "hello" in
    assert (validate_arg_type Arg_type.bool bool_value) ;
    assert (validate_arg_type Arg_type.int int_value) ;
    assert (validate_arg_type Arg_type.string string_value)

  let%test_unit "validate args" =
    let action = action "start_node" config in
    let args =
      [ ("node_id", `String "node0")
      ; ("fresh_state", `Bool true)
      ; ("git_commit", `String "0123456abcdef")
      ]
    in
    assert (validate_args ~args ~action)

  let%test_unit "interpolate string args" =
    let res =
      interpolate_args
        ~args:[ ("network_id", `String "network0") ]
        deploy_network_raw_cmd
    in
    let expect = {|minimina network deploy --network-id network0|} in
    assert (res = expect)

  let%test_unit "prog and args" =
    let action = Yojson.Safe.from_string start_node_action in
    let args =
      [ ("node_id", `String "node0")
      ; ("fresh_state", `Bool true)
      ; ("commit_sha", `String "0123456abcdef")
      ]
    in
    let prog, res_args = prog_and_args ~args action in
    let expect =
      String.split ~on:' ' @@ interpolate_args ~args start_node_raw_cmd
    in
    assert (prog = List.hd_exn expect) ;
    assert (List.equal ( = ) res_args @@ List.tl_exn expect)
end

module Run_command_tests = struct
  open Config_file

  module Arg_failures = struct
    let ( = ) = String.equal

    let%test_unit "run command arg type validation failure" =
      let arg, value = ("msg", `Int 42) in
      try
        ignore @@ run_command ~config:config_file ~args:[ (arg, value) ] "echo"
      with Invalid_arg_type (arg_name, arg_value, arg_type) ->
        assert (
          arg_name = "msg" && arg_type = Arg_type.string
          && Yojson.Safe.equal arg_value value )

    let%test_unit "run command arg number failure" =
      try
        ignore
        @@ run_command ~config:config_file
             ~args:[ ("msg", `String "hello"); ("num", `Int 42) ]
             "echo"
      with Invalid_args_num -> ()

    let%test_unit "run command missing arg failure" =
      try
        ignore
        @@ run_command ~config:config_file
             ~args:[ ("msg0", `String "hello") ]
             "echo"
      with Missing_arg (arg_name, arg_type) ->
        assert (arg_name = "msg" && arg_type = Arg_type.string)
  end

  module Successful = struct
    open Async.Deferred.Let_syntax

    let echo_command =
      let arg, value = ("msg", `String "hello") in
      let%map output =
        run_command ~suppress_logs:true ~config:config_file
          ~args:[ (arg, value) ]
          "echo"
      in
      if Result.is_error output then assert false

    let cat_command =
      let arg, value = ("path", `String config_file) in
      match%map
        run_command ~suppress_logs:true ~config:config_file
          ~args:[ (arg, value) ]
          "cat"
      with
      | Ok output ->
          ignore
            ( output |> Yojson.Safe.from_string |> Config_file.of_yojson
            |> Result.ok_or_failwith )
      | Error _ ->
          assert false

    let%test_unit "run command tests" =
      ignore
        (let%bind _ = Async.Deferred.all [ cat_command; echo_command ] in
         exit 0 )
  end
end

module Request_tests = struct
  let%test_unit "Create network request" =
    let constants : Test_config.constants =
      { constraints = Genesis_constants.Constraint_constants.compiled
      ; genesis = Genesis_constants.compiled
      }
    in
    let network_config : Network_config.t' =
      { debug_arg = true; genesis_keypairs = Core.String.Map.empty; constants }
    in
    let expect =
      {|
        { "debug_arg":true,
          "genesis_keypairs":{},
          "constants":{
            "constraints":{
              "sub_windows_per_window":11,
              "ledger_depth":35,
              "work_delay":2,
              "block_window_duration_ms":180000,
              "transaction_capacity_log_2":7,
              "pending_coinbase_depth":5,
              "coinbase_amount":"720000000000",
              "supercharged_coinbase_factor":1,
              "account_creation_fee":"1",
              "fork":null
            },
            "genesis":{
              "protocol":{
                "k":290,
                "slots_per_epoch":7140,
                "slots_per_sub_window":7,
                "delta":0,
                "genesis_state_timestamp":"2020-09-16 10:15:00.000000Z"
              },
              "txpool_max_size":3000,
              "num_accounts":null,
              "zkapp_proof_update_cost":10.26,
              "zkapp_signed_single_update_cost":9.140000000000001,
              "zkapp_signed_pair_update_cost":10.08,
              "zkapp_transaction_cost_limit":69.45,
              "max_event_elements":100,
              "max_action_elements":100
            }
          }
        }
      |}
      |> Yojson.Safe.from_string
    in
    assert (
      Yojson.Safe.equal expect @@ Network_config.t'_to_yojson network_config )
end

module Parse_output_tests = struct
  let%test_unit "parse network created" =
    let open Network_created in
    let result =
      {|{"network_id":"network0"}|} |> Yojson.Safe.from_string |> of_yojson
      |> Result.ok_or_failwith
    in
    assert (equal result { network_id = "network0" })

  let%test_unit "parse network deployed response" =
    let open Node_type in
    let open Network_deployed in
    let result =
      {|
        { "network_id":"network0",
          "nodes": [
            { "node0": {
                "node_type":"Archive_node",
                "private_key":null,
                "graphql_uri":"gql_archive"
              }
            },
            { "node1": {
                "node_type":"Block_producer_node",
                "private_key":null,
                "graphql_uri":"gql_bp"
              }
            },
            { "node2": {
                "node_type":"Seed_node",
                "private_key":"EKEQpDAjj7dP3j7fQy4qBU7Kxns85wwq5xMn4zxdyQm83pEWzQ62",
                "graphql_uri":"gql_seed"
              }
            },
            { "node3": {
                "node_type":"Snark_worker",
                "private_key":null,
                "graphql_uri":"gql_snark"
              }
            },
            { "node4": {
                "node_type":"Snark_coordinator",
                "private_key":null,
                "graphql_uri":null
              }
            }
          ]
        }
      |}
      |> Yojson.Safe.from_string |> of_yojson |> Result.ok_or_failwith
    in
    let seed_keypair =
      let open Signature_lib in
      let keypair =
        let private_key =
          Private_key.of_base58_check_exn
            "EKEQpDAjj7dP3j7fQy4qBU7Kxns85wwq5xMn4zxdyQm83pEWzQ62"
        in
        let public_key = Public_key.of_private_key_exn private_key in
        Keypair.{ public_key; private_key }
      in
      Network_keypair.create_network_keypair ~keypair_name:"node2_key" ~keypair
    in
    let archive =
      { node_id = "node0"
      ; network_id = "network0"
      ; node_type = Archive_node
      ; network_keypair = None
      ; graphql_uri = Some "gql_archive"
      }
    in
    let bp =
      { node_id = "node1"
      ; node_type = Block_producer_node
      ; network_id = "network0"
      ; network_keypair = None
      ; graphql_uri = Some "gql_bp"
      }
    in
    let seed =
      { node_id = "node2"
      ; node_type = Seed_node
      ; network_id = "network0"
      ; network_keypair = Some seed_keypair
      ; graphql_uri = Some "gql_seed"
      }
    in
    let worker =
      { node_id = "node3"
      ; node_type = Snark_worker
      ; network_id = "network0"
      ; network_keypair = None
      ; graphql_uri = Some "gql_snark"
      }
    in
    let coordinator =
      { node_id = "node4"
      ; node_type = Snark_coordinator
      ; network_id = "network0"
      ; network_keypair = None
      ; graphql_uri = None
      }
    in
    let expect =
      Core.String.Map.of_alist_exn
        [ ("node0", archive)
        ; ("node1", bp)
        ; ("node2", seed)
        ; ("node3", worker)
        ; ("node4", coordinator)
        ]
    in
    assert (equal result expect)

  let%test_unit "parse node started" =
    let open Node_started in
    let result =
      {|{"node_id":"node0"}|} |> Yojson.Safe.from_string |> of_yojson
      |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0" })

  let%test_unit "parse node stopped" =
    let open Node_stopped in
    let result =
      {|{"node_id":"node0"}|} |> Yojson.Safe.from_string |> of_yojson
      |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0" })

  let%test_unit "parse archive data dump" =
    let open Archive_data_dump in
    let result =
      {|{"node_id":"node0","data":"data0"}|} |> Yojson.Safe.from_string
      |> of_yojson |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0"; data = "data0" })

  let%test_unit "parse mina logs dump" =
    let open Mina_logs_dump in
    let logs = "{\"log0\":\"msg0\"}\n{\"log1\":\"msg1\"}" in
    let result =
      `Assoc [ ("node_id", `String "node0"); ("logs", `String logs) ]
      |> of_yojson |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0"; logs })

  let%test_unit "parse precomputed block dump response" =
    let open Precomputed_block_dump in
    let result =
      {|{"node_id":"node0","blocks":"blocks"}|} |> Yojson.Safe.from_string
      |> of_yojson |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0"; blocks = "blocks" })

  let%test_unit "Replayer run response" =
    let open Replayer_run in
    let logs = "{\"log0\":\"msg0\"}\n{\"log1\":\"msg1\"}" in
    let result =
      `Assoc [ ("node_id", `String "node0"); ("logs", `String logs) ]
      |> of_yojson |> Result.ok_or_failwith
    in
    assert (equal result { node_id = "node0"; logs })
end

let () = ignore @@ Async.Scheduler.go ()
