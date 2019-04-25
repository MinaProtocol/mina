open Core
open Async
open Pipe_lib
open Signature_lib
open Coda_numbers
open Coda_base
open O1trace
module Graphql_cohttp_async =
  Graphql_cohttp.Make (Graphql_async.Schema) (Cohttp_async.Io)
    (Cohttp_async.Body)

module Make
    (Config_in : Coda_inputs.Config_intf)
    (Program : Coda_inputs.Main_intf) =
struct
  include Program
  open Inputs
  module Graphql = Graphql.Make (Config_in) (Program)

  module For_tests = struct
    let ledger_proof t = staged_ledger_ledger_proof t
  end

  module Lite_compat = Lite_compat.Make (Consensus.Blockchain_state)

  let get_account t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.location_of_key ledger addr |> Option.bind ~f:(Ledger.get ledger)

  let get_balance t (addr : Public_key.Compressed.t) =
    let open Participating_state.Option.Let_syntax in
    let%map account = get_account t addr in
    account.Account.Poly.balance

  let get_accounts t =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    Ledger.to_list ledger

  let string_of_public_key =
    Fn.compose Public_key.Compressed.to_base64 Account.public_key

  let get_public_keys t =
    let open Participating_state.Let_syntax in
    let%map account = get_accounts t in
    List.map account ~f:string_of_public_key

  let get_keys_with_balances t =
    let open Participating_state.Let_syntax in
    let%map accounts = get_accounts t in
    List.map accounts ~f:(fun account ->
        ( string_of_public_key account
        , account.Account.Poly.balance |> Currency.Balance.to_int ) )

  let is_valid_payment t (txn : User_command.t) account_opt =
    let remainder =
      let open Option.Let_syntax in
      let%bind account = account_opt
      and cost =
        let fee = txn.payload.common.fee in
        match txn.payload.body with
        | Stake_delegation (Set_delegate _) ->
            Some (Currency.Amount.of_fee fee)
        | Payment {amount; _} ->
            Currency.Amount.add_fee amount fee
      in
      Currency.Balance.sub_amount account.Account.Poly.balance cost
    in
    Option.is_some remainder

  (** For status *)
  let txn_count = ref 0

  let record_payment ~logger t (txn : User_command.t) account =
    let previous = account.Account.Poly.receipt_chain_hash in
    let receipt_chain_database = receipt_chain_database t in
    match Receipt_chain_database.add receipt_chain_database ~previous txn with
    | `Ok hash ->
        Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("user_command", User_command.to_yojson txn)
            ; ("receipt_chain_hash", Receipt.Chain_hash.to_yojson hash) ]
          "Added  payment $user_command into receipt_chain database. You \
           should wait for a bit to see your account's receipt chain hash \
           update as $receipt_chain_hash" ;
        hash
    | `Duplicate hash ->
        Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("user_command", User_command.to_yojson txn)]
          "Already sent transaction $user_command" ;
        hash
    | `Error_multiple_previous_receipts parent_hash ->
        Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ( "parent_receipt_chain_hash"
              , Receipt.Chain_hash.to_yojson parent_hash )
            ; ( "previous_receipt_chain_hash"
              , Receipt.Chain_hash.to_yojson previous ) ]
          "A payment is derived from two different blockchain states \
           ($parent_receipt_chain_hash, $previous_receipt_chain_hash). \
           Receipt.Chain_hash is supposed to be collision resistant. This \
           collision should not happen." ;
        Core.exit 1

  module Receipt_chain_hash = struct
    (* Receipt.Chain_hash does not have bin_io *)
    include Receipt.Chain_hash.Stable.V1

    let cons, empty = Receipt.Chain_hash.(cons, empty)
  end

  module Payment_verifier =
    Receipt_chain_database_lib.Verifier.Make
      (User_command)
      (Receipt_chain_hash)

  let verify_payment t log (addr : Public_key.Compressed.Stable.Latest.t)
      (verifying_txn : User_command.t) proof =
    let open Participating_state.Let_syntax in
    let%map account = get_account t addr in
    let account = Option.value_exn account in
    let resulting_receipt = account.Account.Poly.receipt_chain_hash in
    let open Or_error.Let_syntax in
    let%bind () = Payment_verifier.verify ~resulting_receipt proof in
    if
      List.exists (Payment_proof.payments proof) ~f:(fun txn ->
          User_command.equal verifying_txn txn )
    then Ok ()
    else
      Or_error.errorf
        !"Merkle list proof does not contain payment %{sexp:User_command.t}"
        verifying_txn

  let schedule_payment log t (txn : User_command.t) account_opt =
    if not (is_valid_payment t txn account_opt) then
      Or_error.error_string "Invalid payment: account balance is too low"
    else
      let txn_pool = transaction_pool t in
      don't_wait_for (Transaction_pool.add txn_pool txn) ;
      Logger.info log ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("user_command", User_command.to_yojson txn)]
        "Added payment $user_command to pool successfully" ;
      txn_count := !txn_count + 1 ;
      Or_error.return ()

  let send_payment logger t (txn : User_command.t) =
    Deferred.return
    @@
    let public_key = Public_key.compress txn.sender in
    let open Participating_state.Let_syntax in
    let%map account_opt = get_account t public_key in
    let open Or_error.Let_syntax in
    let%map () = schedule_payment logger t txn account_opt in
    record_payment ~logger t txn (Option.value_exn account_opt)

  (* TODO: Properly record receipt_chain_hash for multiple transactions. See #1143 *)
  let schedule_payments logger t txns =
    List.map txns ~f:(fun (txn : User_command.t) ->
        let public_key = Public_key.compress txn.sender in
        let open Participating_state.Let_syntax in
        let%map account_opt = get_account t public_key in
        match schedule_payment logger t txn account_opt with
        | Ok () ->
            ()
        | Error err ->
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:[("error", `String (Error.to_string_hum err))]
              "Failure in schedule_payments: $error. This is not yet reported \
               to the client, see #1143" )
    |> Participating_state.sequence
    |> Participating_state.map ~f:ignore

  let prove_receipt t ~proving_receipt ~resulting_receipt :
      Payment_proof.t Deferred.Or_error.t =
    let receipt_chain_database = receipt_chain_database t in
    (* TODO: since we are making so many reads to `receipt_chain_database`,
       reads should be async to not get IO-blocked. See #1125 *)
    let result =
      Receipt_chain_database.prove receipt_chain_database ~proving_receipt
        ~resulting_receipt
    in
    Deferred.return result

  let get_nonce t (addr : Public_key.Compressed.t) =
    let open Participating_state.Let_syntax in
    let%map ledger = best_ledger t in
    let open Option.Let_syntax in
    let%bind location = Ledger.location_of_key ledger addr in
    let%map account = Ledger.get ledger location in
    account.Account.Poly.nonce

  let start_time = Time_ns.now ()

  let snark_job_list_json t =
    let open Participating_state.Let_syntax in
    let%map sl = best_staged_ledger t in
    Staged_ledger.Scan_state.snark_job_list_json (Staged_ledger.scan_state sl)

  type active_state_fields =
    { num_accounts: int option
    ; block_count: int option
    ; ledger_merkle_root: string option
    ; staged_ledger_hash: string option
    ; state_hash: string option
    ; consensus_time_best_tip: string option }

  let get_status ~flag t =
    let uptime_secs =
      Time_ns.diff (Time_ns.now ()) start_time
      |> Time_ns.Span.to_sec |> Int.of_float
    in
    let commit_id = Config_in.commit_id in
    let conf_dir = Config_in.conf_dir in
    let peers =
      List.map (peers t) ~f:(fun peer ->
          Network_peer.Peer.to_discovery_host_and_port peer
          |> Host_and_port.to_string )
    in
    let user_commands_sent = !txn_count in
    let run_snark_worker = snark_worker_key t <> None in
    let propose_pubkey =
      Option.map ~f:(fun kp -> kp.public_key) (propose_keypair t)
    in
    let consensus_mechanism = Consensus.name in
    let consensus_time_now = Consensus.time_hum (Core_kernel.Time.now ()) in
    let consensus_configuration = Consensus.Configuration.t in
    let r = Perf_histograms.report in
    let histograms =
      match flag with
      | `Performance ->
          let rpc_timings =
            let open Daemon_rpcs.Types.Status.Rpc_timings in
            { get_staged_ledger_aux=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_get_staged_ledger_aux"
                ; impl= r ~name:"rpc_impl_get_staged_ledger_aux" }
            ; answer_sync_ledger_query=
                { Rpc_pair.dispatch=
                    r ~name:"rpc_dispatch_answer_sync_ledger_query"
                ; impl= r ~name:"rpc_impl_answer_sync_ledger_query" }
            ; get_ancestry=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_ancestry"
                ; impl= r ~name:"rpc_impl_get_ancestry" }
            ; transition_catchup=
                { Rpc_pair.dispatch= r ~name:"rpc_dispatch_transition_catchup"
                ; impl= r ~name:"rpc_impl_transition_catchup" } }
          in
          Some
            { Daemon_rpcs.Types.Status.Histograms.rpc_timings
            ; external_transition_latency=
                r ~name:"external_transition_latency"
            ; accepted_transition_local_latency=
                r ~name:"accepted_transition_local_latency"
            ; accepted_transition_remote_latency=
                r ~name:"accepted_transition_remote_latency"
            ; snark_worker_transition_time=
                r ~name:"snark_worker_transition_time"
            ; snark_worker_merge_time= r ~name:"snark_worker_merge_time" }
      | `None ->
          None
    in
    let active_status () =
      let open Participating_state.Let_syntax in
      let%bind ledger = best_ledger t in
      let ledger_merkle_root =
        Ledger.merkle_root ledger |> [%sexp_of: Ledger_hash.t]
        |> Sexp.to_string
      in
      let num_accounts = Ledger.num_accounts ledger in
      let%bind state = best_protocol_state t in
      let state_hash =
        Consensus.Protocol_state.hash state
        |> [%sexp_of: State_hash.t] |> Sexp.to_string
      in
      let consensus_state =
        state |> Consensus.Protocol_state.consensus_state
      in
      let block_count =
        Length.to_int @@ Consensus.Consensus_state.length consensus_state
      in
      let%bind sync_status =
        Incr_status.stabilize () ;
        match Incr_status.Observer.value_exn @@ sync_status t with
        | `Bootstrap ->
            `Bootstrapping
        | `Offline ->
            `Active `Offline
        | `Synced ->
            `Active `Synced
      in
      let%map staged_ledger = best_staged_ledger t in
      let staged_ledger_hash =
        staged_ledger |> Staged_ledger.hash |> Staged_ledger_hash.sexp_of_t
        |> Sexp.to_string
      in
      let consensus_time_best_tip =
        Consensus.Consensus_state.time_hum consensus_state
      in
      ( sync_status
      , { num_accounts= Some num_accounts
        ; block_count= Some block_count
        ; ledger_merkle_root= Some ledger_merkle_root
        ; staged_ledger_hash= Some staged_ledger_hash
        ; state_hash= Some state_hash
        ; consensus_time_best_tip= Some consensus_time_best_tip } )
    in
    let ( sync_status
        , { num_accounts
          ; block_count
          ; ledger_merkle_root
          ; staged_ledger_hash
          ; state_hash
          ; consensus_time_best_tip } ) =
      match active_status () with
      | `Active result ->
          result
      | `Bootstrapping ->
          ( `Bootstrap
          , { num_accounts= None
            ; block_count= None
            ; ledger_merkle_root= None
            ; staged_ledger_hash= None
            ; state_hash= None
            ; consensus_time_best_tip= None } )
    in
    { Daemon_rpcs.Types.Status.num_accounts
    ; sync_status
    ; block_count
    ; uptime_secs
    ; ledger_merkle_root
    ; staged_ledger_hash
    ; state_hash
    ; consensus_time_best_tip
    ; commit_id
    ; conf_dir
    ; peers
    ; user_commands_sent
    ; run_snark_worker
    ; propose_pubkey
    ; histograms
    ; consensus_time_now
    ; consensus_mechanism
    ; consensus_configuration }

  let get_lite_chain :
      (t -> Public_key.Compressed.t list -> Lite_base.Lite_chain.t) option =
    Option.map Consensus.Consensus_state.to_lite
      ~f:(fun consensus_state_to_lite t pks ->
        let ledger = best_ledger t |> Participating_state.active_exn in
        let transition =
          With_hash.data
            (Transition_frontier.Breadcrumb.transition_with_hash
               (best_tip t |> Participating_state.active_exn))
        in
        let state = External_transition.Verified.protocol_state transition in
        let proof =
          External_transition.Verified.protocol_state_proof transition
        in
        let ledger =
          List.fold pks
            ~f:(fun acc key ->
              let loc = Option.value_exn (Ledger.location_of_key ledger key) in
              Lite_lib.Sparse_ledger.add_path acc
                (Lite_compat.merkle_path (Ledger.merkle_path ledger loc))
                (Lite_compat.public_key key)
                (Lite_compat.account (Option.value_exn (Ledger.get ledger loc)))
              )
            ~init:
              (Lite_lib.Sparse_ledger.of_hash ~depth:Ledger.depth
                 (Lite_compat.digest
                    ( Ledger.merkle_root ledger
                      :> Snark_params.Tick.Pedersen.Digest.t )))
        in
        let protocol_state : Lite_base.Protocol_state.t =
          { previous_state_hash=
              Lite_compat.digest
                ( Consensus.Protocol_state.previous_state_hash state
                  :> Snark_params.Tick.Pedersen.Digest.t )
          ; body=
              { blockchain_state=
                  Lite_compat.blockchain_state
                    (Consensus.Protocol_state.blockchain_state state)
              ; consensus_state=
                  consensus_state_to_lite
                    (Consensus.Protocol_state.consensus_state state) } }
        in
        let proof = Lite_compat.proof proof in
        {Lite_base.Lite_chain.proof; ledger; protocol_state} )

  let clear_hist_status ~flag t = Perf_histograms.wipe () ; get_status ~flag t

  let log_shutdown ~conf_dir ~logger t =
    let frontier_file = conf_dir ^/ "frontier.dot" in
    let mask_file = conf_dir ^/ "registered_masks.dot" in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
      (Visualization_message.success "registered masks" mask_file) ;
    Coda_base.Ledger.Debug.visualize ~filename:mask_file ;
    match visualize_frontier ~filename:frontier_file t with
    | `Active () ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          (Visualization_message.success "transition frontier" frontier_file)
    | `Bootstrapping ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          (Visualization_message.bootstrap "transition frontier")

  (* TODO: handle participation_status more appropriately than doing participate_exn *)
  let setup_local_server ?(client_whitelist = []) ?rest_server_port ~coda
      ~logger ~client_port () =
    let client_whitelist =
      Unix.Inet_addr.Set.of_list (Unix.Inet_addr.localhost :: client_whitelist)
    in
    (* Setup RPC server for client interactions *)
    let implement rpc f =
      Rpc.Rpc.implement rpc (fun () input ->
          trace_recurring_task (Rpc.Rpc.name rpc) (fun () -> f () input) )
    in
    let client_impls =
      [ implement Daemon_rpcs.Send_user_command.rpc (fun () tx ->
            let%map result = send_payment logger coda tx in
            result |> Participating_state.active_exn )
      ; implement Daemon_rpcs.Send_user_commands.rpc (fun () ts ->
            schedule_payments logger coda ts |> Participating_state.active_exn ;
            Deferred.unit )
      ; implement Daemon_rpcs.Get_balance.rpc (fun () pk ->
            return (get_balance coda pk |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Verify_proof.rpc (fun () (pk, tx, proof) ->
            return
              ( verify_payment coda logger pk tx proof
              |> Participating_state.active_exn ) )
      ; implement Daemon_rpcs.Prove_receipt.rpc
          (fun () (proving_receipt, pk) ->
            let open Deferred.Or_error.Let_syntax in
            let%bind account =
              get_account coda pk |> Participating_state.active_exn
              |> Result.of_option
                   ~error:
                     (Error.of_string
                        (sprintf
                           !"Could not find account of public key %{sexp: \
                             Public_key.Compressed.t}"
                           pk))
              |> Deferred.return
            in
            prove_receipt coda ~proving_receipt
              ~resulting_receipt:account.Account.Poly.receipt_chain_hash )
      ; implement Daemon_rpcs.Get_public_keys_with_balances.rpc (fun () () ->
            return
              (get_keys_with_balances coda |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Get_public_keys.rpc (fun () () ->
            return (get_public_keys coda |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Get_nonce.rpc (fun () pk ->
            return (get_nonce coda pk |> Participating_state.active_exn) )
      ; implement Daemon_rpcs.Get_status.rpc (fun () flag ->
            return (get_status ~flag coda) )
      ; implement Daemon_rpcs.Clear_hist_status.rpc (fun () flag ->
            return (clear_hist_status ~flag coda) )
      ; implement Daemon_rpcs.Get_ledger.rpc (fun () lh -> get_ledger coda lh)
      ; implement Daemon_rpcs.Stop_daemon.rpc (fun () () ->
            Scheduler.yield () >>= (fun () -> exit 0) |> don't_wait_for ;
            Deferred.unit )
      ; implement Daemon_rpcs.Snark_job_list.rpc (fun () () ->
            return (snark_job_list_json coda |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Start_tracing.rpc (fun () () ->
            Coda_tracing.start Config_in.conf_dir )
      ; implement Daemon_rpcs.Stop_tracing.rpc (fun () () ->
            Coda_tracing.stop () ; Deferred.unit )
      ; implement Daemon_rpcs.Visualization.Frontier.rpc (fun () filename ->
            return (visualize_frontier ~filename coda) )
      ; implement Daemon_rpcs.Visualization.Registered_masks.rpc
          (fun () filename ->
            return (Coda_base.Ledger.Debug.visualize ~filename) ) ]
    in
    let snark_worker_impls =
      [ implement Snark_worker.Rpcs.Get_work.Latest.rpc (fun () () ->
            let r = request_work coda in
            Option.iter r ~f:(fun r ->
                Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                  !"Get_work: %{sexp:Snark_worker.Work.Spec.t}"
                  r ) ;
            return r )
      ; implement Snark_worker.Rpcs.Submit_work.Latest.rpc
          (fun () (work : Snark_worker.Work.Result.t) ->
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
              !"Submit_work: %{sexp:Snark_worker.Work.Spec.t}"
              work.spec ;
            List.iter work.metrics ~f:(fun (total, tag) ->
                match tag with
                | `Merge ->
                    Perf_histograms.add_span ~name:"snark_worker_merge_time"
                      total
                | `Transition ->
                    Perf_histograms.add_span
                      ~name:"snark_worker_transition_time" total ) ;
            Snark_pool.add_completed_work (snark_pool coda) work ) ]
    in
    Option.iter rest_server_port ~f:(fun rest_server_port ->
        trace_task "REST server" (fun () ->
            let graphql_callback =
              Graphql_cohttp_async.make_callback
                (fun _req -> coda)
                Graphql.schema
            in
            Cohttp_async.(
              Server.create_expert
                ~on_handler_error:
                  (`Call
                    (fun net exn ->
                      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                        "%s" (Exn.to_string_mach exn) ))
                (Tcp.Where_to_listen.bind_to Localhost
                   (On_port rest_server_port))
                (fun ~body _sock req ->
                  let uri = Cohttp.Request.uri req in
                  let status flag =
                    Server.respond_string
                      ( get_status ~flag coda
                      |> Daemon_rpcs.Types.Status.to_yojson
                      |> Yojson.Safe.pretty_to_string )
                  in
                  let lift x = `Response x in
                  match Uri.path uri with
                  | "/graphql" ->
                      graphql_callback () req body
                  | "/status" ->
                      status `None >>| lift
                  | "/status/performance" ->
                      status `Performance >>| lift
                  | _ ->
                      Server.respond_string ~status:`Not_found
                        "Route not found"
                      >>| lift )) )
        |> ignore ) ;
    let where_to_listen =
      Tcp.Where_to_listen.bind_to All_addresses (On_port client_port)
    in
    trace_task "client RPC handling" (fun () ->
        Tcp.Server.create
          ~on_handler_error:
            (`Call
              (fun net exn ->
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s"
                  (Exn.to_string_mach exn) ))
          where_to_listen
          (fun address reader writer ->
            let address = Socket.Address.Inet.addr address in
            if not (Set.mem client_whitelist address) then (
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                !"Rejecting client connection from \
                  %{sexp:Unix.Inet_addr.Blocking_sexp.t}"
                address ;
              Deferred.unit )
            else
              Rpc.Connection.server_with_close reader writer
                ~implementations:
                  (Rpc.Implementations.create_exn
                     ~implementations:(client_impls @ snark_worker_impls)
                     ~on_unknown_rpc:`Raise)
                ~connection_state:(fun _ -> ())
                ~on_handshake_error:
                  (`Call
                    (fun exn ->
                      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                        "%s" (Exn.to_string_mach exn) ;
                      Deferred.unit )) ) )
    |> ignore

  let create_snark_worker ~logger ~public_key ~client_port
      ~shutdown_on_disconnect =
    let open Snark_worker_lib in
    let%map p =
      let our_binary = Sys.executable_name in
      Process.create_exn () ~prog:our_binary
        ~args:
          ( "internal" :: Snark_worker_lib.Intf.command_name
          :: Snark_worker.arguments ~public_key
               ~daemon_address:
                 (Host_and_port.create ~host:"127.0.0.1" ~port:client_port)
               ~shutdown_on_disconnect )
    in
    (* We want these to be printfs so we don't double encode our logs here *)
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stdout p))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    Pipe.iter_without_pushback
      (Reader.pipe (Process.stderr p))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    Deferred.unit

  let run_snark_worker ?shutdown_on_disconnect:(s = true) ~logger ~client_port
      run_snark_worker =
    match run_snark_worker with
    | `Don't_run ->
        ()
    | `With_public_key public_key ->
        create_snark_worker ~shutdown_on_disconnect:s ~logger ~public_key
          ~client_port
        |> ignore

  let handle_shutdown ~monitor ~conf_dir ~logger t =
    Monitor.detach_and_iter_errors monitor ~f:(fun exn ->
        log_shutdown ~conf_dir ~logger t ;
        raise exn ) ;
    Async_unix.Signal.(
      handle terminating ~f:(fun signal ->
          log_shutdown ~conf_dir ~logger t ;
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            !"Coda process got interrupted by signal %{sexp:t}"
            signal ))
end
