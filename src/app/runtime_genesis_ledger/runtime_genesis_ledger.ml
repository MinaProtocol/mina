open Core
open Async
open Coda_base

type t = Ledger.t

let generate_base_proof ~ledger ~(genesis_constants : Genesis_constants.t) =
  let%map ((module Keys) as keys) = Keys_lib.Keys.create () in
  let protocol_state_with_hash =
    Coda_state.Genesis_protocol_state.t
      ~genesis_ledger:(Genesis_ledger.Packed.t ledger)
      ~genesis_constants
  in
  let base_hash = Keys.Step.instance_hash protocol_state_with_hash.data in
  let computed_values =
    Genesis_proof.create_values ~keys ~proof_level:Full
      { genesis_ledger= ledger
      ; protocol_state_with_hash
      ; base_hash
      ; genesis_constants }
  in
  (base_hash, computed_values.genesis_proof)

let compiled_accounts_json () : Account_config.t =
  List.map (Lazy.force Test_genesis_ledger.accounts) ~f:(fun (sk_opt, acc) ->
      { Account_config.pk= acc.public_key
      ; sk= sk_opt
      ; balance= acc.balance
      ; delegate= Some acc.delegate } )

let generate_ledger :
    directory_name:string -> Account_config.t -> Genesis_ledger.Packed.t =
 fun ~directory_name accounts ->
  let ledger = Ledger.create ~directory_name () in
  let accounts =
    List.map accounts ~f:(fun {pk; sk; balance; delegate} ->
        let account =
          let account_id = Account_id.create pk Token_id.default in
          let base_acct = Account.create account_id balance in
          {base_acct with delegate= Option.value ~default:pk delegate}
        in
        Ledger.create_new_account_exn ledger
          (Account.identifier account)
          account ;
        (sk, account) )
  in
  Ledger.commit ledger ;
  ( module struct
    include Genesis_ledger.Make (struct
      let accounts = lazy accounts
    end)

    let t = lazy ledger
  end )

let get_accounts accounts_json_file n =
  let open Deferred.Or_error.Let_syntax in
  let%map accounts =
    match accounts_json_file with
    | Some file -> (
        let open Deferred.Let_syntax in
        match%map
          Deferred.Or_error.try_with_join (fun () ->
              let%map accounts_str = Reader.file_contents file in
              let res = Yojson.Safe.from_string accounts_str in
              match Account_config.of_yojson res with
              | Ok res ->
                  Ok res
              | Error s ->
                  Error
                    (Error.of_string
                       (sprintf "Account_config.of_yojson failed: %s" s)) )
        with
        | Ok res ->
            Ok res
        | Error e ->
            Or_error.errorf "Could not read accounts from file: %s\n%s" file
              (Error.to_string_hum e) )
    | None ->
        Deferred.return (Ok (compiled_accounts_json ()))
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
  let all_accounts =
    let fake_accounts =
      Account_config.Fake_accounts.generate
        (max (n - List.length real_accounts) 0)
    in
    real_accounts @ fake_accounts
  in
  (*the accounts file that can be edited later*)
  Out_channel.with_file "accounts.json" ~f:(fun json_file ->
      Yojson.Safe.pretty_to_channel json_file
        (Account_config.to_yojson all_accounts) ) ;
  all_accounts

let create_tar ~genesis_dirname top_dir =
  let tar_file = top_dir ^/ genesis_dirname ^ ".tar.gz" in
  let tar_command =
    sprintf "tar -C %s -czf %s %s" top_dir tar_file genesis_dirname
  in
  let exit = Core.Sys.command tar_command in
  if exit = 2 then
    failwith
      (sprintf "Error generating the tar for genesis ledger. Exit code: %d"
         exit)

let read_write_constants read_from_opt write_to =
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
  Yojson.Safe.to_file write_to
    Genesis_constants.(
      Config_file.(of_genesis_constants constants |> to_yojson)) ;
  constants

let main accounts_json_file dir n proof_level constants_file =
  let open Deferred.Let_syntax in
  let top_dir = Option.value ~default:Cache_dir.autogen_path dir in
  let genesis_dirname =
    Cache_dir.genesis_dir_name ~genesis_constants:Genesis_constants.compiled
      ~proof_level:Genesis_constants.Proof_level.compiled
  in
  let%bind genesis_dir =
    let dir = top_dir ^/ genesis_dirname in
    let%map () = File_system.create_dir dir ~clear_if_exists:true in
    dir
  in
  let ledger_path = genesis_dir ^/ "ledger" in
  let proof_path = genesis_dir ^/ "genesis_proof" in
  let constants_path = genesis_dir ^/ "genesis_constants.json" in
  let%bind accounts = get_accounts accounts_json_file n in
  let%bind () =
    match
      Or_error.try_with_join (fun () ->
          let open Or_error.Let_syntax in
          let%map accounts = accounts in
          let ledger = generate_ledger ~directory_name:ledger_path accounts in
          ledger )
    with
    | Ok ledger ->
        let genesis_constants =
          read_write_constants constants_file constants_path
          |> Result.ok_or_failwith
        in
        let%bind _base_hash, base_proof =
          match proof_level with
          | Genesis_constants.Proof_level.Full ->
              generate_base_proof ~ledger ~genesis_constants
          | Check | None ->
              return
                ( Snark_params.Tick.Field.zero
                , Dummy_values.Tock.Bowe_gabizon18.proof )
        in
        let%bind wr = Writer.open_file proof_path in
        Writer.write wr (Proof.Stable.V1.sexp_of_t base_proof |> Sexp.to_string) ;
        Writer.close wr
    | Error e ->
        failwithf "Failed to create genesis ledger\n%s" (Error.to_string_hum e)
          ()
  in
  create_tar ~genesis_dirname top_dir ;
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
                  (Int.pow 2 Coda_compile_config.ledger_depth))
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
           let max = Int.pow 2 Coda_compile_config.ledger_depth in
           if Option.value ~default:0 n >= max then
             failwith (sprintf "Invalid value for n (0 <= n <= %d)" max)
           else
             main accounts_json genesis_dir
               (Option.value ~default:0 n)
               (Option.value ~default:Genesis_constants.Proof_level.compiled
                  proof_level)
               constants))
