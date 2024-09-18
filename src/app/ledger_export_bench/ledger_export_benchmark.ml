open Core
open Core_bench

let load_daemon_cfg filename () =
  let json = Yojson.Safe.from_file filename in
  match Runtime_config.Json_layout.of_yojson json with
  | Ok cfg ->
      cfg
  | Error err ->
      raise (Failure err)

let serialize cfg () =
  Runtime_config.Json_layout.to_yojson cfg |> Yojson.Safe.to_string

let map_results ~f =
  List.fold ~init:(Ok []) ~f:(fun acc x ->
      let open Result.Let_syntax in
      let%bind accum = acc in
      let%map y = f x in
      y :: accum )

let convert accounts () =
  map_results ~f:Runtime_config.Accounts.Single.of_account accounts

let () =
  let runtime_config = Sys.getenv_exn "RUNTIME_CONFIG" in
  let cfg = load_daemon_cfg runtime_config () in
  let accounts =
    match
      Runtime_config.Ledger.of_json_layout cfg.ledger |> Result.ok_or_failwith
    with
    | { base = Named _; _ } | { base = Hash; _ } ->
        []
    | { base = Accounts accs; _ } ->
        List.map ~f:Runtime_config.Accounts.Single.to_account accs
  in
  Command.run
    (Bench.make_command
       [ Bench.Test.create ~name:"parse_runtime_config"
           (load_daemon_cfg runtime_config)
       ; Bench.Test.create ~name:"serialize_runtime_config" (serialize cfg)
       ; Bench.Test.create ~name:"convert_accounts_for_config"
           (convert accounts)
       ] )
