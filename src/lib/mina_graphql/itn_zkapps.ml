open Core
open Async
open Mina_base

let deploy_zkapps ~scheduler_tbl ~mina ~ledger ~deployment_fee ~max_cost
    ~init_balance ~(fee_payer_array : Signature_lib.Keypair.t Array.t)
    ~constraint_constants ~logger ~memo_prefix ~wait_span ~stop_signal
    ~stop_time ~uuid keypairs =
  O1trace.thread "itn_deploy_zkapps"
  @@ fun () ->
  let fee_payer_accounts =
    Array.map fee_payer_array ~f:(fun key -> Utils.account_of_kp key ledger)
  in
  let fee_payer_nonces =
    Array.map fee_payer_accounts ~f:(fun account -> ref account.nonce)
  in
  let num_fee_payers = Array.length fee_payer_array in
  let finished () =
    if Time.(now () >= stop_time) then (
      [%log info]
        "Scheduled zkapp commands with handle %s has expired, stop deployment \
         of zkapp accounts"
        (Uuid.to_string uuid) ;
      Uuid.Table.remove scheduler_tbl uuid ;
      true )
    else if Ivar.is_full stop_signal then (
      [%log info]
        "Scheduled zkapp commands with handle %s received stop signal, stop \
         deployment of zkapp accounts"
        (Uuid.to_string uuid) ;
      Uuid.Table.remove scheduler_tbl uuid ;
      true )
    else false
  in
  Deferred.List.iteri keypairs ~f:(fun i kp ->
      let ndx = i mod num_fee_payers in
      if finished () then Deferred.unit
      else
        let fee_payer_keypair = fee_payer_array.(ndx) in
        let memo = sprintf "%s-%d" memo_prefix i in
        let spec =
          { Transaction_snark.For_tests.Deploy_snapp_spec.sender =
              (fee_payer_keypair, !(fee_payer_nonces.(ndx)))
          ; fee = deployment_fee
          ; fee_payer = None
          ; amount = init_balance
          ; zkapp_account_keypairs = [ kp ]
          ; memo = Signed_command_memo.create_from_string_exn memo
          ; new_zkapp_account = true
          ; snapp_update = Account_update.Update.dummy
          ; preconditions = None
          ; authorization_kind = Account_update.Authorization_kind.Signature
          }
        in
        let zkapp_command =
          Transaction_snark.For_tests.deploy_snapp ~constraint_constants
            ~permissions:
              ( if max_cost then
                { Permissions.user_default with
                  set_verification_key =
                    (Permissions.Auth_required.Proof, Protocol_version.current)
                ; edit_state = Permissions.Auth_required.Proof
                ; edit_action_state = Proof
                }
              else Permissions.user_default )
            spec
        in
        let%bind () = after wait_span in
        Deferred.repeat_until_finished ()
        @@ fun () ->
        if finished () then Deferred.return (`Finished ())
        else
          match%bind Zkapps.send_zkapp_command mina zkapp_command with
          | Ok _ ->
              fee_payer_nonces.(ndx) :=
                Account.Nonce.succ !(fee_payer_nonces.(ndx)) ;
              [%log info]
                "Successfully submitted zkApp command that creates a zkApp \
                 account"
                ~metadata:
                  [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command) ] ;
              Deferred.return (`Finished ())
          | Error err ->
              [%log info] "Failed to setup a zkApp account, try again"
                ~metadata:
                  [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
                  ; ("error", `String err)
                  ] ;
              let%bind () = after wait_span in
              Deferred.return (`Repeat ()) )

let is_zkapp_deployed ledger kp =
  try Option.is_some (Utils.account_of_kp kp ledger).zkapp with _ -> false

let all_zkapps_deployed ~ledger (keypairs : Signature_lib.Keypair.t list) =
  List.map keypairs ~f:(is_zkapp_deployed ledger) |> List.for_all ~f:Fn.id

let rec wait_until_zkapps_deployed ?(deployed = false) ~scheduler_tbl ~mina
    ~ledger ~deployment_fee ~max_cost ~init_balance
    ~(fee_payer_array : Signature_lib.Keypair.t Array.t) ~constraint_constants
    ~logger ~uuid ~stop_signal ~stop_time ~memo_prefix ~wait_span
    (keypairs : Signature_lib.Keypair.t list) =
  if Time.( >= ) (Time.now ()) stop_time then (
    [%log info] "Scheduled zkApp commands with handle %s has expired"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    return None )
  else if Ivar.is_full stop_signal then (
    [%log info] "Stopping scheduled zkApp commands with handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    return None )
  else if all_zkapps_deployed ~ledger keypairs then (
    [%log info] "All zkApp accounts are deployed" ;
    return (Some ledger) )
  else
    let%bind () =
      if not deployed then (
        [%log info] "Start deploying zkApp accounts" ;
        deploy_zkapps ~scheduler_tbl ~mina ~ledger ~deployment_fee ~max_cost
          ~init_balance ~fee_payer_array ~constraint_constants ~logger
          ~memo_prefix ~wait_span ~stop_signal ~stop_time ~uuid keypairs )
      else return ()
    in
    [%log debug]
      "Some deployed zkApp accounts weren't found in the best tip ledger, \
       trying again" ;
    let%bind () =
      Async.after
        (Time.Span.of_ms
           (Float.of_int constraint_constants.block_window_duration_ms) )
    in
    let ledger =
      Utils.get_ledger_and_breadcrumb mina
      |> Option.value_map ~default:ledger ~f:(fun (new_ledger, _) ->
             new_ledger )
    in
    wait_until_zkapps_deployed ~scheduler_tbl ~deployed:true ~mina ~ledger
      ~deployment_fee ~max_cost ~init_balance ~fee_payer_array
      ~constraint_constants ~logger ~uuid ~stop_signal ~stop_time ~memo_prefix
      ~wait_span keypairs

let insert_account_queue ~account_queue ~account_queue_size ~account_state_tbl
    id =
  let a = Account_id.Table.find_and_remove account_state_tbl id in
  Queue.enqueue account_queue (Option.value_exn a) ;
  if Queue.length account_queue > account_queue_size then
    let a, role = Queue.dequeue_exn account_queue in
    Account_id.Table.add_exn account_state_tbl ~key:(Account.identifier a)
      ~data:(a, role)
  else ()

let send_zkapps ~fee_payer_array ~constraint_constants ~tm_end ~scheduler_tbl
    ~uuid ~keymap ~unused_pks ~stop_signal ~mina ~zkapp_command_details
    ~wait_span ~logger ~account_state_tbl init_tm_next init_counter =
  let wait_span_ms = Time.Span.to_ms wait_span |> int_of_float in
  let repeat tm_next counter =
    let%map () = Async_unix.at tm_next in
    let open Time in
    let next_tm_next = add tm_next wait_span in
    let now = now () in
    let next_tm_next =
      if next_tm_next <= now then
        (* This is done to ensure there is no effect of transactions coming out one by one,
           let there be some pause under any cricumstances *)
        let span = diff now next_tm_next |> Span.to_ms in
        let additive =
          wait_span_ms - (int_of_float span % wait_span_ms)
          |> float_of_int |> Span.of_ms
        in
        add now additive
      else next_tm_next
    in
    `Repeat (next_tm_next, counter + 1)
  in
  let `VK vk, `Prover prover =
    Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()
  in
  let account_queue = Queue.create () in
  let num_fee_payers = Array.length fee_payer_array in
  Deferred.repeat_until_finished (init_tm_next, init_counter)
  @@ fun (tm_next, counter) ->
  let ndx = counter mod num_fee_payers in
  if Time.( >= ) (Time.now ()) tm_end then (
    [%log info] "Scheduled zkApp commands with handle %s has expired"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else if Ivar.is_full stop_signal then (
    [%log info] "Stopping scheduled zkApp commands with handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else
    let fee_payer = fee_payer_array.(ndx) in
    let zkapp_dummy_opt_res =
      O1trace.sync_thread "itn_generate_dummy_zkapp"
      @@ fun () ->
      match Utils.get_ledger_and_breadcrumb mina with
      | None ->
          [%log info]
            "Failed to fetch the best tip ledger, skip this round, we will try \
             again at $time"
            ~metadata:
              [ ("time", `String (Time.to_string_fix_proto `Local tm_next)) ] ;
          Result.return None
      | Some (ledger, _) ->
          let number_of_accounts_generated =
            let f = function _, `New_account -> true | _ -> false in
            Account_id.Table.count ~f account_state_tbl
            + Queue.count ~f account_queue
          in
          let generate_new_accounts =
            number_of_accounts_generated
            < zkapp_command_details
                .Types.Input.Itn.ZkappCommandsDetails.num_new_accounts
          in
          let memo =
            sprintf "%s-%d" zkapp_command_details.memo_prefix counter
          in
          Result.try_with
          @@ fun () ->
          Option.some
          @@ Quickcheck.Generator.generate
               ( if zkapp_command_details.max_cost then
                 Mina_generators.Zkapp_command_generators
                 .gen_max_cost_zkapp_command_from ~fee_payer_keypair:fee_payer
                   ~account_state_tbl ~vk
                   ~genesis_constants:
                     (Mina_lib.config mina).precomputed_values.genesis_constants
               else
                 Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
                   ~memo
                   ~no_account_precondition:
                     zkapp_command_details.no_precondition
                   ~fee_range:
                     ( zkapp_command_details.min_fee
                     , zkapp_command_details.max_fee )
                   ~balance_change_range:
                     zkapp_command_details.balance_change_range
                   ~ignore_sequence_events_precond:true ~no_token_accounts:true
                   ~limited:true ~fee_payer_keypair:fee_payer ~keymap
                   ~account_state_tbl ~generate_new_accounts ~ledger ~vk
                   ~available_public_keys:unused_pks () )
               ~size:1
               ~random:(Splittable_random.State.create Random.State.default)
    in
    match zkapp_dummy_opt_res with
    | Error e ->
        [%log error]
          "Error $error creating zkapp transaction, stopping handle %s"
          (Uuid.to_string uuid)
          ~metadata:[ ("error", Error_json.error_to_yojson @@ Error.of_exn e) ] ;
        Deferred.return (`Finished ())
    | Ok None ->
        repeat tm_next counter
    | Ok (Some zkapp_dummy) ->
        let accounts = Zkapp_command.accounts_referenced zkapp_dummy in
        List.iter accounts
          ~f:
            (insert_account_queue ~account_queue
               ~account_queue_size:zkapp_command_details.account_queue_size
               ~account_state_tbl ) ;
        let%bind zkapp_command =
          O1trace.thread "itn_replace_zkapp_auth"
          @@ fun () ->
          Zkapp_command_builder.replace_authorizations ~prover ~keymap
            zkapp_dummy
        in
        let%bind () =
          O1trace.thread "itn_send_zkapp"
          @@ fun () ->
          match%map Zkapps.send_zkapp_command mina zkapp_command with
          | Ok _ ->
              [%log info] "Sent out zkApp with fee payer's summary $summary"
                ~metadata:
                  [ ( "summary"
                    , User_command.fee_payer_summary_json
                        (Zkapp_command zkapp_command) )
                  ]
          | Error e ->
              [%log info] "Failed to send out zkApp command, see $error"
                ~metadata:[ ("error", `String e) ]
        in
        repeat tm_next counter
