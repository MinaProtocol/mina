open Core
open Async
open Pipe_lib
open Signature_lib
open Coda_numbers
open Coda_base
open Coda_transition
open Coda_state
open O1trace
module Graphql_cohttp_async =
  Graphql_cohttp.Make (Graphql_async.Schema) (Cohttp_async.Io)
    (Cohttp_async.Body)

module Make
    (Config_in : Coda_inputs.Config_intf)
    (Program : Coda_inputs.Main_intf) =
struct
  module Commands = Coda_commands.Make (Config_in) (Program)
  module Graphql = Graphql.Make (Commands)
  include Program
  open Inputs

  module For_tests = struct
    let ledger_proof t = staged_ledger_ledger_proof t
  end

  let snark_job_list_json t =
    let open Participating_state.Let_syntax in
    let%map sl = best_staged_ledger t in
    Staged_ledger.Scan_state.snark_job_list_json (Staged_ledger.scan_state sl)

  let get_lite_chain :
      (t -> Public_key.Compressed.t list -> Lite_base.Lite_chain.t) option =
    Option.map Consensus.Data.Consensus_state.to_lite
      ~f:(fun consensus_state_to_lite t pks ->
        let ledger = best_ledger t |> Participating_state.active_exn in
        let transition =
          With_hash.data
            (Transition_frontier.Breadcrumb.transition_with_hash
               (best_tip t |> Participating_state.active_exn))
        in
        let state = External_transition.Validated.protocol_state transition in
        let proof =
          External_transition.Validated.protocol_state_proof transition
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
                ( Protocol_state.previous_state_hash state
                  :> Snark_params.Tick.Pedersen.Digest.t )
          ; body=
              { blockchain_state=
                  Lite_compat.blockchain_state
                    (Protocol_state.blockchain_state state)
              ; consensus_state=
                  consensus_state_to_lite
                    (Protocol_state.consensus_state state) } }
        in
        let proof = Lite_compat.proof proof in
        {Lite_base.Lite_chain.proof; ledger; protocol_state} )

  let log_shutdown ~conf_dir:_ _t =
    (* [new] TODO: !important add visualization logging back in *)
    ()
    (*
    let logger =
      Logger.extend
        (Program.top_level_logger t)
        [("coda_run", `String "Logging state before program ends")]
    in
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
    *)

  (* TODO: handle participation_status more appropriately than doing participate_exn *)
  let setup_local_server ?(client_whitelist = []) ?rest_server_port ~coda
      ~client_port () =
    let client_whitelist =
      Unix.Inet_addr.Set.of_list (Unix.Inet_addr.localhost :: client_whitelist)
    in
    (* Setup RPC server for client interactions *)
    let implement rpc f =
      Rpc.Rpc.implement rpc (fun () input ->
          trace_recurring_task (Rpc.Rpc.name rpc) (fun () -> f () input) )
    in
    let implement_notrace = Rpc.Rpc.implement in
    let logger =
      Logger.extend
        (Program.top_level_logger coda)
        [("coda_run", `String "Setting up server logs")]
    in
    let client_impls =
      [ implement Daemon_rpcs.Send_user_command.rpc (fun () tx ->
            let%map result = Commands.send_user_command coda tx in
            result |> Participating_state.active_exn )
      ; implement Daemon_rpcs.Send_user_commands.rpc (fun () ts ->
            Commands.schedule_user_commands coda ts
            |> Participating_state.active_exn ;
            Deferred.unit )
      ; implement Daemon_rpcs.Get_balance.rpc (fun () pk ->
            return
              (Commands.get_balance coda pk |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Verify_proof.rpc (fun () (pk, tx, proof) ->
            return
              ( Commands.verify_payment coda pk tx proof
              |> Participating_state.active_exn ) )
      ; implement Daemon_rpcs.Prove_receipt.rpc
          (fun () (proving_receipt, pk) ->
            let open Deferred.Or_error.Let_syntax in
            let%bind account =
              Commands.get_account coda pk
              |> Participating_state.active_exn
              |> Result.of_option
                   ~error:
                     (Error.of_string
                        (sprintf
                           !"Could not find account of public key %{sexp: \
                             Public_key.Compressed.t}"
                           pk))
              |> Deferred.return
            in
            Commands.prove_receipt coda ~proving_receipt
              ~resulting_receipt:account.Account.Poly.receipt_chain_hash )
      ; implement Daemon_rpcs.Get_public_keys_with_balances.rpc (fun () () ->
            return
              ( Commands.get_keys_with_balances coda
              |> Participating_state.active_exn ) )
      ; implement Daemon_rpcs.Get_public_keys.rpc (fun () () ->
            return
              (Commands.get_public_keys coda |> Participating_state.active_exn)
        )
      ; implement Daemon_rpcs.Get_nonce.rpc (fun () pk ->
            return
              (Commands.get_nonce coda pk |> Participating_state.active_exn) )
      ; implement_notrace Daemon_rpcs.Get_status.rpc (fun () flag ->
            return (Commands.get_status ~flag coda) )
      ; implement Daemon_rpcs.Clear_hist_status.rpc (fun () flag ->
            return (Commands.clear_hist_status ~flag coda) )
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
                      ( Commands.get_status ~flag coda
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

  let create_snark_worker ~public_key ~client_port ~shutdown_on_disconnect =
    let open Snark_worker in
    let%map p =
      let our_binary = Sys.executable_name in
      Process.create_exn () ~prog:our_binary
        ~args:
          ( "internal" :: Snark_worker.Intf.command_name
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

  let run_snark_worker ?shutdown_on_disconnect:(s = true) ~client_port
      run_snark_worker =
    match run_snark_worker with
    | `Don't_run ->
        ()
    | `With_public_key public_key ->
        create_snark_worker ~shutdown_on_disconnect:s ~public_key ~client_port
        |> ignore

  let handle_shutdown ~monitor ~conf_dir t =
    Monitor.detach_and_iter_errors monitor ~f:(fun exn ->
        log_shutdown ~conf_dir t ; raise exn ) ;
    Async_unix.Signal.(
      handle terminating ~f:(fun signal ->
          log_shutdown ~conf_dir t ;
          let logger =
            Logger.extend
              (Program.top_level_logger t)
              [("coda_run", `String "Program got killed by signal")]
          in
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            !"Coda process got interrupted by signal %{sexp:t}"
            signal ))
end
