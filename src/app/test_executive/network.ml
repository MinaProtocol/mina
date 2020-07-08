open Core
open Async

type t =
  { cluster: string
  ; namespace: string
  ; keypair_secrets: string list
  ; testnet_dir: string
  ; mutable deployed: bool }

let run_cmd' testnet_dir prog args =
  Process.create_exn ~working_dir:testnet_dir ~prog ~args ()
  >>= Process.collect_output_and_wait

let run_cmd_exn' testnet_dir prog args =
  let open Process.Output in
  let%bind output = run_cmd' testnet_dir prog args in
  let print_output () =
    let indent str =
      String.split str ~on:'\n'
      |> List.map ~f:(fun s -> "    " ^ s)
      |> String.concat ~sep:"\n"
    in
    print_endline "=== COMMAND ===" ;
    print_endline
      (indent
         ( prog ^ " "
         ^ String.concat ~sep:" "
             (List.map args ~f:(fun arg -> "\"" ^ arg ^ "\"")) )) ;
    print_endline "=== STDOUT ===" ;
    print_endline (indent output.stdout) ;
    print_endline "=== STDERR ===" ;
    print_endline (indent output.stderr) ;
    Writer.(flushed (Lazy.force stdout))
  in
  match output.exit_status with
  | Ok () ->
      return ()
  | Error (`Exit_non_zero status) ->
      let%map () = print_output () in
      failwithf "command exited with status code %d" status ()
  | Error (`Signal signal) ->
      let%map () = print_output () in
      failwithf "command exited prematurely due to signal %d"
        (Signal.to_system_int signal)
        ()

let run_cmd t prog args = run_cmd' t.testnet_dir prog args

let run_cmd_exn t prog args = run_cmd_exn' t.testnet_dir prog args

let create ~coda_automation_location ~testnet_name ~network_config =
  let keypairs, direct_network_config =
    Network_config.Abstract.render testnet_name network_config
  in
  let testnet_dir =
    coda_automation_location ^/ "terraform/testnets" ^/ testnet_name
  in
  (* cleanup old deployment, if it exists; we will need to take good care of this logic when we put this in CI *)
  let%bind () =
    if%bind File_system.dir_exists testnet_dir then
      let%bind () = run_cmd_exn' testnet_dir "terraform" ["refresh"] in
      let%bind () =
        let open Process.Output in
        let%bind state_output =
          run_cmd' testnet_dir "terraform" ["state"; "list"]
        in
        if not (String.is_empty state_output.stdout) then
          run_cmd_exn' testnet_dir "terraform" ["destroy"; "-auto-approve"]
        else return ()
      in
      File_system.remove_dir testnet_dir
    else return ()
  in
  let%bind () = Unix.mkdir testnet_dir in
  (* TODO: prebuild genesis proof and ledger *)
  (*
  let%bind inputs =
    Genesis_ledger_helper.Genesis_proof.generate_inputs ~proof_level ~ledger
      ~constraint_constants ~genesis_constants
  in
  let%bind (_, genesis_proof_filename) =
    Genesis_ledger_helper.Genesis_proof.load_or_generate ~logger ~genesis_dir ~may_generate:true
      inputs
  in
  *)
  Out_channel.with_file ~fail_if_exists:true (testnet_dir ^/ "main.tf.json")
    ~f:(fun ch ->
      Network_config.render direct_network_config
      |> Out_channel.output_string ch ) ;
  (*
  Out_channel.with_file ~fail_if_exists:true (testnet_dir ^/ "daemon.json") ~f:(fun ch ->
    Runtime_config.to_yojson runtime_config
    |> Yojson.Safe.to_string
    |> Out_channel.output_string ch);
  *)
  let%bind () =
    Deferred.List.iter keypairs ~f:(fun (secret_name, keypair) ->
        Secrets.Keypair.write_exn keypair
          ~privkey_path:(testnet_dir ^/ secret_name)
          ~password:(lazy (return (Bytes.of_string "naughty blue worm"))) )
  in
  let t =
    { cluster= network_config.cloud.cluster_id
    ; namespace= testnet_name
    ; testnet_dir
    ; keypair_secrets= List.map keypairs ~f:fst
    ; deployed= false }
  in
  let%bind () = run_cmd_exn t "terraform" ["init"] in
  let%map () = run_cmd_exn t "terraform" ["validate"] in
  t

let deploy t =
  if t.deployed then failwith "network already deployed" ;
  let%bind () = run_cmd_exn t "terraform" ["apply"; "-auto-approve"] in
  let%map () =
    Deferred.List.iter t.keypair_secrets ~f:(fun secret ->
        run_cmd_exn t "kubectl"
          [ "create"
          ; "secret"
          ; "generic"
          ; secret
          ; "--cluster=" ^ t.cluster
          ; "--namespace=" ^ t.namespace
          ; "--from-file=key=" ^ secret
          ; "--from-file=pub=" ^ secret ^ ".pub" ] )
  in
  t.deployed <- true

let teardown t =
  print_endline "destroying network" ;
  if not t.deployed then failwith "network not deployed" ;
  let%map () = run_cmd_exn t "terraform" ["destroy"; "-auto-approve"] in
  print_endline "network has been successfully destroyed" ;
  t.deployed <- false

let cleanup t =
  let%bind () = if t.deployed then teardown t else return () in
  File_system.remove_dir t.testnet_dir
