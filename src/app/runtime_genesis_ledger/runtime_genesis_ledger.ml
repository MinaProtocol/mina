open Core
open Async
open Coda_base

type t = Ledger.t

let get_accounts accounts_json_file n =
  let open Deferred.Or_error.Let_syntax in
  let%map accounts =
    match accounts_json_file with
    | Some file ->
        Genesis_ledger_helper.Accounts.load file
    | None ->
        Deferred.return (Ok (Genesis_ledger_helper.Accounts.compiled ()))
  in
  let real_accounts =
    let genesis_winner_account : Account_config.account_data =
      let pk, _ = Coda_state.Consensus_state_hooks.genesis_winner in
      {pk; sk= None; balance= Currency.Balance.of_int 1000; delegate= None}
    in
    if
      List.exists accounts ~f:(fun acc ->
          Signature_lib.Public_key.Compressed.equal acc.pk
            genesis_winner_account.pk )
    then accounts
    else genesis_winner_account :: accounts
  in
  let num_real_accounts = List.length real_accounts in
  let num_fake_accounts = max 0 (n - num_real_accounts) in
  let num_accounts =
    Option.some_if (num_fake_accounts > 0)
      (num_real_accounts + num_fake_accounts)
  in
  let all_accounts =
    let fake_accounts =
      Account_config.Fake_accounts.generate num_fake_accounts
    in
    real_accounts @ fake_accounts
  in
  (*the accounts file that can be edited later*)
  Genesis_ledger_helper.Accounts.store ~filename:"accounts.json" all_accounts ;
  (all_accounts, num_accounts)

let create_tar ~genesis_dirname top_dir =
  let tar_file = top_dir ^/ genesis_dirname ^ ".tar.gz" in
  Genesis_ledger_helper.Tar.create ~root:top_dir ~file:tar_file
    ~directory:genesis_dirname ()

let read_write_constants ~f read_from_opt write_to =
  let open Result.Let_syntax in
  let%map constants =
    match read_from_opt with
    | Some file ->
        let%map t =
          Yojson.Safe.from_file file |> Genesis_constants.Config_file.of_yojson
        in
        Genesis_constants.Config_file.to_genesis_constants
          ~default:Genesis_constants.compiled t
    | None ->
        Ok Genesis_constants.compiled
  in
  let constants = f constants in
  Yojson.Safe.to_file write_to
    Genesis_constants.(
      Config_file.(of_genesis_constants constants |> to_yojson)) ;
  constants

let main accounts_json_file dir num_accounts proof_level constants_file =
  let open Deferred.Let_syntax in
  let top_dir = Option.value ~default:Cache_dir.autogen_path dir in
  let genesis_dirname =
    Cache_dir.genesis_dir_name ~genesis_constants:Genesis_constants.compiled
      ~proof_level:Genesis_constants.Proof_level.compiled
      ~ledger_depth:Genesis_constants.ledger_depth
  in
  let%bind genesis_dir =
    let dir = top_dir ^/ genesis_dirname in
    let%map () = File_system.create_dir dir ~clear_if_exists:true in
    dir
  in
  let ledger_path = Genesis_ledger_helper.Ledger.path ~root:genesis_dir in
  let proof_path =
    Genesis_ledger_helper.Genesis_proof.path ~root:genesis_dir
  in
  let constants_path = genesis_dir ^/ "genesis_constants.json" in
  let%bind accounts = get_accounts accounts_json_file num_accounts in
  let%bind () =
    match
      Or_error.try_with_join (fun () ->
          let open Or_error.Let_syntax in
          let%map accounts, num_accounts = accounts in
          let ledger =
            Genesis_ledger_helper.Ledger.generate ~directory_name:ledger_path
              accounts
          in
          (ledger, num_accounts) )
    with
    | Ok (ledger, num_accounts) ->
        let genesis_constants =
          read_write_constants constants_file constants_path
            ~f:(fun (genesis_constants : Genesis_constants.t) ->
              (* Store the true number of accounts in the configuration. *)
              {genesis_constants with num_accounts} )
          |> Result.ok_or_failwith
        in
        let%bind _base_hash, base_proof =
          Genesis_ledger_helper.Genesis_proof.generate ~proof_level ~ledger
            ~genesis_constants
        in
        Deferred.Or_error.ok_exn
        @@ Genesis_ledger_helper.Genesis_proof.store ~filename:proof_path
             base_proof
    | Error e ->
        failwithf "Failed to create genesis ledger\n%s" (Error.to_string_hum e)
          ()
  in
  let%bind () =
    Deferred.Or_error.ok_exn @@ create_tar ~genesis_dirname top_dir
  in
  File_system.remove_dir genesis_dir

let () =
  Command.run
    (Command.async
       ~summary:
         "Create the genesis ledger with configurable accounts, balances, and \
          delegates "
       Command.(
         let open Let_syntax in
         let open Command.Param in
         let%map accounts_json =
           flag "account-file"
             ~doc:
               "Filepath of the json file that has all the account data in \
                the format: [{\"pk\":public-key-string, \
                \"sk\":optional-secret-key-string, \"balance\":int, \
                \"delegate\":optional-public-key-string}] (default: \
                Compile-time generated accounts)"
             (optional string)
         and genesis_dir =
           flag "genesis-dir"
             ~doc:
               (sprintf
                  "Dir where the genesis ledger and genesis proof is to be \
                   saved (default: %s)"
                  Cache_dir.autogen_path)
             (optional string)
         and n =
           flag "n"
             ~doc:
               (sprintf
                  "Int Total number of accounts in the ledger (Maximum: %d). \
                   If the number of accounts in the account file, say x, is \
                   less than n then the tool will generate (n-x) fake \
                   accounts (default: x)."
                  (Int.pow 2 Genesis_constants.ledger_depth))
             (optional int)
         and constants =
           flag "constants"
             ~doc:
               (sprintf
                  "Filepath of the json file that has Coda constants. \
                   (default: %s)"
                  ( Genesis_constants.(
                      Config_file.(of_genesis_constants compiled |> to_yojson))
                  |> Yojson.Safe.to_string ))
             (optional string)
         and proof_level =
           flag "proof-level"
             (optional
                (Arg_type.create Genesis_constants.Proof_level.of_string))
             ~doc:"full|check|none"
         in
         fun () ->
           let max = Int.pow 2 Genesis_constants.ledger_depth in
           let n = Option.value ~default:0 n in
           let proof_level =
             Option.value ~default:Genesis_constants.Proof_level.compiled
               proof_level
           in
           if n >= max then
             failwith (sprintf "Invalid value for n (0 <= n <= %d)" max)
           else main accounts_json genesis_dir n proof_level constants))
