open Core
open Async
open Signature_lib
open Mina_base

type query =
  { zkapp_keypairs : Signature_lib.Keypair.t list
  ; transaction_count : int
  ; max_parties_count : int option
  ; fee_payer_keypair : Signature_lib.Keypair.t
  ; account_states : (Account_id.Stable.Latest.t * Account.t) list
  }

(*let deploy_test_zkapps kps ~fee_payer_keypair ~ledger =
  let fee_payer_nonce =
  List.iter *)

let get_ledger (constraint_constants : Genesis_constants.Constraint_constants.t)
    ~port =
  let open Deferred.Let_syntax in
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

let all_zkapps_deployed ~ledger (keypairs : Signature_lib.Keypair.t list) =
  List.map keypairs ~f:(fun kp ->
      let account = account_of_kp kp ledger in
      Option.is_some account.zkapp )
  |> List.for_all ~f:Fn.id

let send_zkapp_command ~port txn ~success =
  Daemon_rpcs.Client.dispatch_with_message Daemon_rpcs.Send_zkapp_command.rpc
    txn port ~success
    ~error:(fun e ->
      sprintf "Failed to send zkapp command %s\n%!" (Error.to_string_hum e) )
    ~join_error:Or_error.join

let deploy_test_zkapps ~ledger ~port
    ~(fee_payer_keypair : Signature_lib.Keypair.t) ~constraint_constants
    (keypairs : Signature_lib.Keypair.t list) =
  let fee_payer_id =
    Account_id.create
      (Signature_lib.Public_key.compress fee_payer_keypair.public_key)
      Token_id.default
  in
  let fee_payer_account = account_of_id fee_payer_id ledger in
  let nonce = ref fee_payer_account.nonce in
  Deferred.List.iter keypairs ~f:(fun kp ->
      match
        Option.try_with (fun () ->
            let account = account_of_kp kp ledger in
            Option.is_some account.zkapp )
      with
      | Some true ->
          (*deploy zkapp*)
          let spec =
            { Transaction_snark.For_tests.Spec.sender =
                (fee_payer_keypair, !nonce)
            ; fee = Currency.Fee.of_formatted_string "1.0"
            ; fee_payer = None
            ; receivers = []
            ; amount = Currency.Amount.of_formatted_string "2.0"
            ; zkapp_account_keypairs = [ kp ]
            ; memo = Signed_command_memo.empty
            ; new_zkapp_account = true
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; preconditions = None
            }
          in
          let zkapp_command =
            Transaction_snark.For_tests.deploy_snapp ~constraint_constants spec
          in
          nonce := Account.Nonce.succ !nonce ;
          send_zkapp_command ~port zkapp_command ~success:(fun _ ->
              sprintf
                !"Successfully deployed zkapp with pk: \
                  %{sexp:Signature_lib.Public_key.Compressed.t}"
                (Signature_lib.Public_key.compress kp.public_key) )
      | _ ->
          return
            (Core.printf
               !"Already deployed Zkapp with pk: \
                 %{sexp:Signature_lib.Public_key.Compressed.t}. Skipping"
               (Signature_lib.Public_key.compress kp.public_key) ) )

let rec wait_until_zkapps_deployed ~ledger ~port
    ~(fee_payer_keypair : Signature_lib.Keypair.t) ~constraint_constants
    (keypairs : Signature_lib.Keypair.t list) =
  if all_zkapps_deployed ~ledger keypairs then return ()
  else
    let%bind () =
      deploy_test_zkapps ~ledger ~port ~fee_payer_keypair ~constraint_constants
        keypairs
    in
    let%bind () =
      Async.after
        (Time.Span.of_ms
           (Float.of_int (constraint_constants.block_window_duration_ms * 3)) )
    in
    let%bind ledger = get_ledger constraint_constants ~port in
    wait_until_zkapps_deployed ~ledger ~port ~fee_payer_keypair
      ~constraint_constants keypairs

let generate_random_zkapps ~ledger ~vk ~prover
    ({ zkapp_keypairs = kps
     ; transaction_count = num_of_parties
     ; max_parties_count = parties_size
     ; fee_payer_keypair
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
      flag "--parties-size" ~aliases:[ "parties-size" ]
        ~doc:"NUM maximum number of parties in 1 zkapp commands" (optional int)
    and fee_payer_privkey_path = Cli_lib.Flag.privkey_read_path
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
           (default: 10). Note: generating large parties transactions is slow"
        (optional_with_default 10 int)
    and _port = Cli_lib.Flag.Host_and_port.Client.daemon in
    ( keypair_path
    , fee_payer_privkey_path
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
             ~constraint_constants keypairs
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
             Core.printf "Generating %d parties transactions\n%!" batch ;
             let%bind parties_list, account_states' =
               generate_random_zkapps ~ledger ~vk ~prover
                 { zkapp_keypairs = keypairs
                 ; transaction_count = batch
                 ; max_parties_count = parties_size
                 ; fee_payer_keypair
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
