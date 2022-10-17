open Core
open Async
open Signature_lib
open Mina_base

type query =
  { zkapp_keypairs : Signature_lib.Keypair.t list
  ; transaction_count : int
  ; max_parties_count : int option
  ; fee_payer_keypair : Signature_lib.Keypair.t
  ; account_creator_keypair : Signature_lib.Keypair.t
  ; account_states : (Account_id.Stable.Latest.t * Account.t) list
  }

let get_ledger (constraint_constants : Genesis_constants.Constraint_constants.t)
    ~port =
  let open Deferred.Let_syntax in
  Core.printf !"Getting ledger from the daemon\n%!" ;
  let%map ledger_accounts =
    match%map
      Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_ledger.rpc None port
    with
    | Ok ledger ->
        Or_error.ok_exn ledger
    | Error e ->
        failwithf "Failed to get best tip ledger: %s" (Error.to_string_hum e) ()
  in
  let ledger =
    Mina_ledger.Ledger.create ~depth:constraint_constants.ledger_depth ()
  in
  List.iter ledger_accounts ~f:(fun acc ->
      Mina_ledger.Ledger.create_new_account_exn ledger
        (Mina_base.Account.identifier acc)
        acc ) ;
  ledger

let account_of_id id ledger =
  Mina_ledger.Ledger.location_of_account ledger id
  |> Option.value_exn
  |> Mina_ledger.Ledger.get ledger
  |> Option.value_exn

let account_of_kp (kp : Signature_lib.Keypair.t) ledger =
  let id =
    Account_id.create
      (Signature_lib.Public_key.compress kp.public_key)
      Token_id.default
  in
  account_of_id id ledger

let is_zkapp_deployed kp ledger =
  match
    Option.try_with (fun () ->
        let account = account_of_kp kp ledger in
        Option.is_some account.zkapp )
  with
  | Some true ->
      true
  | _ ->
      false

let all_zkapps_deployed ~ledger (keypairs : Signature_lib.Keypair.t list) =
  Core.printf
    !"Checking if test zkapps are deployed in all the accounts passed\n%!" ;
  List.map keypairs ~f:(fun kp -> is_zkapp_deployed kp ledger)
  |> List.for_all ~f:Fn.id

let send_zkapp_command ~port txn ~success =
  Core.printf !"Sending a zkapp transaction..\n%!" ;
  Daemon_rpcs.Client.dispatch_with_message Daemon_rpcs.Send_zkapp_command.rpc
    txn port ~success
    ~error:(fun e ->
      sprintf "Failed to send zkapp command %s\n%!" (Error.to_string_hum e) )
    ~join_error:Or_error.join

let deploy_test_zkapps ~ledger ~port
    ~(fee_payer_keypair : Signature_lib.Keypair.t)
    ~(account_creator_keypair : Signature_lib.Keypair.t) ~constraint_constants
    (keypairs : Signature_lib.Keypair.t list) =
  Core.printf !"Deploying zkapps..\n%!" ;
  let fee_payer_id =
    Account_id.create
      (Signature_lib.Public_key.compress fee_payer_keypair.public_key)
      Token_id.default
  in
  let account_creator_id =
    Account_id.create
      (Signature_lib.Public_key.compress account_creator_keypair.public_key)
      Token_id.default
  in
  let fee_payer_account = account_of_id fee_payer_id ledger in
  let account_creator = account_of_id account_creator_id ledger in
  Core.printf
    !"fee payer account %s\n%!"
    (Account.to_yojson fee_payer_account |> Yojson.Safe.to_string) ;
  let fee_payer_nonce = ref fee_payer_account.nonce in
  let account_creator_nonce = ref account_creator.nonce in
  Deferred.List.iter keypairs ~f:(fun kp ->
      if not (is_zkapp_deployed kp ledger) then (
        (*deploy zkapp*)
        let spec =
          { Transaction_snark.For_tests.Deploy_snapp_spec.sender =
              (account_creator_keypair, !account_creator_nonce)
          ; fee = Currency.Fee.of_formatted_string "1.0"
          ; fee_payer = Some (fee_payer_keypair, !fee_payer_nonce)
          ; amount = Currency.Amount.of_formatted_string "2000.0"
          ; zkapp_account_keypairs = [ kp ]
          ; memo = Signed_command_memo.empty
          ; new_zkapp_account = true
          ; snapp_update = Account_update.Update.dummy
          ; authorization_kind = Account_update.Authorization_kind.Signature
          ; preconditions = None
          }
        in
        let zkapp_command =
          Transaction_snark.For_tests.deploy_snapp ~constraint_constants spec
        in

        let%map () =
          send_zkapp_command ~port zkapp_command ~success:(fun _ ->
              sprintf
                !"Successfully deployed zkapp with pk: \
                  %{sexp:Signature_lib.Public_key.Compressed.t}"
                (Signature_lib.Public_key.compress kp.public_key) )
        in
        fee_payer_nonce := Account.Nonce.succ !fee_payer_nonce ;
        account_creator_nonce := Account.Nonce.succ !account_creator_nonce )
      else
        return
          (Core.printf
             !"Already deployed Zkapp with pk: \
               %{sexp:Signature_lib.Public_key.Compressed.t}. Skipping"
             (Signature_lib.Public_key.compress kp.public_key) ) )

let rec wait_until_zkapps_deployed ?(deployed = false) ~ledger ~port
    ~(fee_payer_keypair : Signature_lib.Keypair.t)
    ~(account_creator_keypair : Signature_lib.Keypair.t) ~constraint_constants
    (keypairs : Signature_lib.Keypair.t list) =
  if all_zkapps_deployed ~ledger keypairs then (
    Core.printf !"zkapp deployed\n%!" ;
    return () )
  else
    let%bind () =
      if not deployed then
        let%map () =
          deploy_test_zkapps ~ledger ~port ~fee_payer_keypair
            ~account_creator_keypair ~constraint_constants keypairs
        in
        Core.printf "sent transactions to deploy zkapps\n%!"
      else return ()
    in
    Core.printf !"waiting for them to be included..\n%!" ;
    let%bind () =
      Async.after
        (Time.Span.of_ms
           (Float.of_int constraint_constants.block_window_duration_ms) )
    in
    let%bind ledger = get_ledger constraint_constants ~port in
    wait_until_zkapps_deployed ~deployed:true ~ledger ~port ~fee_payer_keypair
      ~account_creator_keypair ~constraint_constants keypairs

let generate_random_zkapps ~ledger ~vk ~prover
    ({ zkapp_keypairs = kps
     ; transaction_count = num_of_parties
     ; max_parties_count = parties_size
     ; fee_payer_keypair
     ; account_creator_keypair = _
     ; account_states
     } :
      query ) =
  let open Deferred.Let_syntax in
  let keymap =
    List.map kps ~f:(fun { public_key; private_key } ->
        (Public_key.compress public_key, private_key) )
    |> Public_key.Compressed.Map.of_alist_exn
  in
  let account_state_tbl =
    let tbl = Account_id.Table.of_alist_exn account_states in
    let fee_payer_id =
      Account_id.create
        (Signature_lib.Public_key.compress fee_payer_keypair.public_key)
        Token_id.default
    in
    Account_id.Table.map tbl ~f:(fun a ->
        if Account_id.equal (Account.identifier a) fee_payer_id then
          (a, `Fee_payer)
        else (a, `Ordinary_participant) )
  in
  let rec go n acc : Zkapp_command.t list Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    if n > 0 then
      let%bind parties =
        Mina_generators.Zkapp_command_generators
        .gen_zkapp_commands_with_limited_keys ~ledger ~keymap ~account_state_tbl
          ?num_account_updates:parties_size ~vk ~fee_payer_keypair ()
      in
      go (n - 1) (parties :: acc)
    else return (List.rev acc)
  in
  let parties_dummy_auth_list =
    Quickcheck.Generator.generate (go num_of_parties []) ~size:num_of_parties
      ~random:(Splittable_random.State.create Random.State.default)
  in
  (*Add fee payer to the keymap to generate signature*)
  let fee_payer_pk =
    Signature_lib.Public_key.compress fee_payer_keypair.public_key
  in
  let keymap =
    Public_key.Compressed.Map.add_exn keymap ~key:fee_payer_pk
      ~data:fee_payer_keypair.private_key
  in
  let%map res =
    Deferred.List.map parties_dummy_auth_list ~f:(fun parties_dummy_auth ->
        Zkapp_command_builder.replace_authorizations ~prover ~keymap
          parties_dummy_auth )
  in
  ( res
  , List.map (Account_id.Table.to_alist account_state_tbl)
      ~f:(fun (k, (acc, _)) -> (k, acc)) )

let batch_test_zkapps =
  let params =
    let open Command.Let_syntax in
    let%map_open keypair_path = anon @@ ("keypair-path" %: string)
    and parties_size =
      flag "--num-account-updates" ~aliases:[ "num-account-updates" ]
        ~doc:"NUM maximum number of account updates in a zkapp command"
        (optional int)
    and fee_payer_privkey_path =
      flag "--fee-payer-privkey-path"
        ~aliases:[ "fee-payer-privkey-path" ]
        ~doc:"FILE File to read fee payer private key from" (required string)
    and account_creator_privkey_path =
      flag "--account-creator-privkey-path"
        ~aliases:[ "account-creator-privkey-path" ]
        ~doc:"FILE File to read zkapp account creator private key from"
        (required string)
    and rate_limit =
      flag "--apply-rate-limit" ~aliases:[ "apply-rate-limit" ]
        ~doc:
          "TRUE/FALSE Whether to emit sleep commands between commands to \
           enforce sleeps (default: true)"
        (optional_with_default true bool)
    and rate_limit_level =
      flag "--rate-limit-level" ~aliases:[ "rate-limit-level" ]
        ~doc:
          "NUM Number of transactions that can be sent in a time interval \
           before hitting the rate limit. Used for rate limiting (default: \
           200)"
        (optional_with_default 200 int)
    and num_txns =
      flag "--num-txns" ~aliases:[ "num-txns" ]
        ~doc:"NUM Number of transactions to run" (required int)
    and rate_limit_interval =
      flag "--rate-limit-interval" ~aliases:[ "rate-limit-interval" ]
        ~doc:
          "NUM_MILLISECONDS Interval that the rate-limiter is applied over. \
           Used for rate limiting (default: 300000)"
        (optional_with_default 300000 int)
    and batch_size =
      flag "--batch-size" ~aliases:[ "batch-size" ]
        ~doc:
          "NUM Number of transactions generated at once before sending \
           (default: 10). Note: generating large zkapp transactions is slow"
        (optional_with_default 10 int)
    in
    ( keypair_path
    , fee_payer_privkey_path
    , account_creator_privkey_path
    , parties_size
    , rate_limit
    , rate_limit_level
    , rate_limit_interval
    , num_txns
    , batch_size )
  in
  Command.async
    ~summary:
      "Generate multiple zkapps using the passed fee payer keypair and \
       broadcast it to the network "
    (Cli_lib.Background_daemon.rpc_init params
       ~f:(fun
            port
            ( keypair_path
            , fee_payer_privkey_path
            , account_creator_privkey_path
            , parties_size
            , rate_limit
            , rate_limit_level
            , rate_limit_interval
            , num_txns
            , batch_size )
          ->
         let open Deferred.Let_syntax in
         let constraint_constants =
           Genesis_constants.Constraint_constants.compiled
         in
         let%bind fee_payer_keypair =
           Secrets.Keypair.Terminal_stdin.read_exn ~which:"Fee payer"
             fee_payer_privkey_path
         in
         let%bind account_creator_keypair =
           Secrets.Keypair.Terminal_stdin.read_exn
             ~which:"zkApp account creator" account_creator_privkey_path
         in
         let%bind keypair_files = Sys.readdir keypair_path >>| Array.to_list in
         let%bind keypairs =
           Deferred.List.map keypair_files ~f:(fun keypair_file ->
               Filename.concat keypair_path keypair_file
               |> Secrets.Keypair.Terminal_stdin.read_exn
                    ~which:"Zkapp account keypair" )
         in
         let limit_level =
           let txns_per_block =
             Int.pow 2 constraint_constants.transaction_capacity_log_2
           in
           let slot_time = constraint_constants.block_window_duration_ms in
           let fill_rate = 0.75 (*based on current config*) in
           let limit_level =
             Float.(
               of_int txns_per_block /. of_int slot_time *. fill_rate
               *. of_int rate_limit_interval)
           in
           min (Float.to_int limit_level) rate_limit_level
         in
         let `VK vk, `Prover prover =
           Transaction_snark.For_tests.create_trivial_snapp
             ~constraint_constants ()
         in
         let%bind ledger = get_ledger constraint_constants ~port in
         let%bind () =
           wait_until_zkapps_deployed ~ledger ~port ~fee_payer_keypair
             ~account_creator_keypair ~constraint_constants keypairs
         in
         let%bind ledger = get_ledger constraint_constants ~port in
         let per_batch = batch_size in
         (*Takes as bit to generate these transactions*)
         let curr_count = ref 0 in
         let total_count = ref 0 in
         let limit =
           if rate_limit then ( fun () ->
             incr curr_count ;
             incr total_count ;
             if !curr_count >= limit_level then
               let%bind () =
                 Deferred.return
                   (Format.printf
                      "zkapp txn burst: rate limiting, pausing for %d \
                       milliseconds... @."
                      rate_limit_interval )
               in
               let%bind () =
                 Async.after (Time.Span.create ~ms:rate_limit_interval ())
               in
               Deferred.return (curr_count := 0)
             else Deferred.return () )
           else fun () -> Deferred.return ()
         in
         let rec go account_states =
           if !total_count >= num_txns then Deferred.unit
           else
             let batch = min per_batch (num_txns - !total_count + 1) in
             Core.printf "Generating %d zkapp transactions\n%!" batch ;
             let%bind parties_list, account_states' =
               generate_random_zkapps ~ledger ~vk ~prover
                 { zkapp_keypairs = keypairs
                 ; transaction_count = batch
                 ; max_parties_count = parties_size
                 ; fee_payer_keypair
                 ; account_creator_keypair
                 ; account_states
                 }
             in
             let%bind () =
               Deferred.List.iter parties_list ~f:(fun parties ->
                   printf !"Sending a zkapp command (count %d)\n%!" !total_count ;
                   let%bind () =
                     send_zkapp_command parties ~port ~success:(fun _ ->
                         sprintf
                           "%d. Successfully enqueued a zkapp command in pool\n\
                            %!"
                           !total_count )
                   in
                   limit () )
             in
             go account_states'
         in
         go [] ) )

let () =
  Command.run
    (Command.group ~summary:"Batch zkapp transactions"
       [ ("send-batch", batch_test_zkapps) ] )
