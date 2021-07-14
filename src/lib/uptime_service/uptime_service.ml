(* uptime_service.ml -- proof of uptime for Mina delegation program *)

open Core_kernel
open Async
open Mina_base
open Mina_transition
open Pipe_lib
open Signature_lib

module Blake2 = Blake2.Make ()

type block_data =
  { block: string
  ; created_at: string
  ; peer_id: string
  ; snark_work: string option [@default None] }
[@@deriving to_yojson]

module Proof_data = struct
  (* NB: this type is unversioned, so the verifier on the backend
     will need to be using the same code
  *)
  type t =
    { proof: Ledger_proof.Stable.Latest.t
    ; proof_time: Core_kernel.Time.Span.t
    ; snark_work_fee: Currency.Fee.Stable.Latest.t }
  [@@deriving bin_io_unversioned]
end

let external_transition_of_breadcrumb breadcrumb =
  let {With_hash.data= external_transition; _}, _ =
    Transition_frontier.Breadcrumb.validated_transition breadcrumb
    |> External_transition.Validated.erase
  in
  external_transition

let get_rfc3339_time () =
  let tm = Unix.gettimeofday () in
  match Ptime.of_float_s tm with
  | None ->
      (* should never occur *)
      failwith "In uptime service, could not convert current time to Ptime.t"
  | Some ptime ->
      Ptime.to_rfc3339 ~tz_offset_s:0 ptime

let send_uptime_data ~logger ~interruptor ~(submitter_keypair : Keypair.t) ~url
    ~state_hash block_data =
  let open Interruptible.Let_syntax in
  let make_interruptible f = Interruptible.lift f interruptor in
  let block_data_json = block_data_to_yojson block_data in
  let block_data_string = Yojson.Safe.to_string block_data_json in
  let signature =
    String_sign.Schnorr.sign submitter_keypair.private_key block_data_string
  in
  let json =
    (* JSON structure in issue 9110 *)
    `Assoc
      [ ("data", block_data_json)
      ; ("signature", Signature.to_yojson signature)
      ; ("submitter", Public_key.to_yojson submitter_keypair.public_key) ]
  in
  let headers = Cohttp.Header.of_list [("Content-Type", "application/json")] in
  match%map
    make_interruptible
      (Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
           let interruptible =
             match%map
               make_interruptible
                 (Cohttp_async.Client.post ~headers
                    ~body:
                      ( Yojson.Safe.to_string json
                      |> Cohttp_async.Body.of_string )
                    url)
             with
             | {status; _}, body ->
                 if Cohttp.Code.code_of_status status = 200 then
                   [%log info]
                     "Sent block with state hash $state_hash to uptime \
                      service at URL $url"
                     ~metadata:
                       [ ("state_hash", State_hash.to_yojson state_hash)
                       ; ( "includes_snark_work"
                         , `Bool (Option.is_some block_data.snark_work) )
                       ; ("url", `String (Uri.to_string url)) ]
                 else
                   let base_metadata =
                     [ ("state_hash", State_hash.to_yojson state_hash)
                     ; ("url", `String (Uri.to_string url))
                     ; ("http_code", `Int (Cohttp.Code.code_of_status status))
                     ; ( "http_error"
                       , `String (Cohttp.Code.string_of_status status) )
                     ; ("payload", json) ]
                   in
                   let extra_metadata =
                     match body with
                     | `String s ->
                         [("error", `String s)]
                     | `Strings ss ->
                         [ ( "error"
                           , `List (List.map ss ~f:(fun s -> `String s)) ) ]
                     | `Empty | `Pipe _ ->
                         []
                   in
                   let metadata = base_metadata @ extra_metadata in
                   [%log error]
                     "Failure when sending block with state hash $state_hash \
                      to uptime service at URL $url"
                     ~metadata
           in
           match%map.Deferred.Let_syntax Interruptible.force interruptible with
           | Ok () ->
               ()
           | Error _ ->
               [%log error]
                 "In uptime service, POST of uptime data was interrupted" ))
  with
  | Ok () ->
      ()
  | Error exn ->
      [%log error]
        "Error when sending block with state hash $state_hash to uptime \
         service at URL $url"
        ~metadata:
          [ ("state_hash", State_hash.to_yojson state_hash)
          ; ("url", `String (Uri.to_string url))
          ; ("payload", json)
          ; ("error", `String (Exn.to_string exn)) ]

let block_base64_of_breadcrumb ~logger breadcrumb =
  let external_transition = external_transition_of_breadcrumb breadcrumb in
  let block_string =
    Binable.to_string
      (module External_transition.Stable.Latest)
      external_transition
  in
  let block_base64_result = Base64.encode block_string in
  match block_base64_result with
  | Ok block_base64 ->
      Some block_base64
  | Error (`Msg err) ->
      [%log error]
        "Could not Base64-encode block with state hash $state_hash for uptime \
         service"
        ~metadata:
          [ ( "state_hash"
            , State_hash.to_yojson
              @@ External_transition.state_hash external_transition )
          ; ("error", `String err) ] ;
      None

let send_produced_block_at ~logger ~interruptor ~url ~peer_id
    ~(submitter_keypair : Keypair.t) ~block_produced_bvar tm =
  let open Interruptible.Let_syntax in
  let make_interruptible f = Interruptible.lift f interruptor in
  let timeout_min = 4.0 in
  let%bind () = make_interruptible (at tm) in
  match%bind
    make_interruptible
      (with_timeout
         (Time.Span.of_min timeout_min)
         (Bvar.wait block_produced_bvar))
  with
  | `Timeout ->
      [%log error]
        "Uptime service did not get a produced block within %0.1f minutes \
         after scheduled time"
        timeout_min ;
      return ()
  | `Result breadcrumb -> (
    match block_base64_of_breadcrumb ~logger breadcrumb with
    | Some block_base64 ->
        let state_hash =
          Transition_frontier.Breadcrumb.state_hash breadcrumb
        in
        let block_data =
          { block= block_base64
          ; created_at= get_rfc3339_time ()
          ; peer_id
          ; snark_work= None }
        in
        send_uptime_data ~logger ~interruptor ~submitter_keypair ~url
          ~state_hash block_data
    | None ->
        return () )

let send_block_and_transaction_snark ~logger ~interruptor ~url
    ~transition_frontier ~peer_id ~(submitter_keypair : Keypair.t)
    ~snark_resource_pool ~snark_work_fee =
  match Broadcast_pipe.Reader.peek transition_frontier with
  | None ->
      [%log error]
        "Transition frontier not available to send a block to uptime service" ;
      Interruptible.return ()
  | Some tf -> (
      let make_interruptible f = Interruptible.lift f interruptor in
      let breadcrumb = Transition_frontier.best_tip tf in
      match block_base64_of_breadcrumb ~logger breadcrumb with
      | None ->
          [%log info]
            "Could not Base64-encode block, not sending block or SNARK work \
             to uptime service" ;
          Interruptible.return ()
      | Some block_base64 -> (
          let open Interruptible.Let_syntax in
          let message =
            Sok_message.create ~fee:snark_work_fee
              ~prover:(Public_key.compress submitter_keypair.public_key)
          in
          (* mimicking code from standalone snark worker *)
          let module Prod = Snark_worker__Prod.Inputs in
          let%bind (worker_state : Prod.Worker_state.t) =
            make_interruptible
              (Prod.Worker_state.create
                 ~constraint_constants:
                   Genesis_constants.Constraint_constants.compiled
                 ~proof_level:Full ())
          in
          let best_tip = Transition_frontier.best_tip tf in
          let external_transition =
            Transition_frontier.Breadcrumb.validated_transition best_tip
            |> External_transition.Validation.forget_validation
          in
          if
            List.is_empty
              (External_transition.transactions
                 ~constraint_constants:
                   Genesis_constants.Constraint_constants.compiled
                 external_transition)
          then (
            [%log info]
              "No transactions in block, sending block without SNARK work to \
               uptime service" ;
            let state_hash =
              Transition_frontier.Breadcrumb.state_hash best_tip
            in
            let block_data =
              { block= block_base64
              ; created_at= get_rfc3339_time ()
              ; peer_id
              ; snark_work= None }
            in
            send_uptime_data ~logger ~interruptor ~submitter_keypair ~url
              ~state_hash block_data )
          else
            let best_tip_staged_ledger =
              Transition_frontier.Breadcrumb.staged_ledger best_tip
            in
            match
              Staged_ledger.all_work_pairs best_tip_staged_ledger
                ~get_state:(fun state_hash ->
                  match
                    Transition_frontier.find_protocol_state tf state_hash
                  with
                  | None ->
                      Error
                        (Error.createf
                           "Could not find state_hash %s in transition \
                            frontier for uptime service"
                           (State_hash.to_base58_check state_hash))
                  | Some protocol_state ->
                      Ok protocol_state )
            with
            | Error e ->
                [%log error]
                  "Could not get SNARK work from best tip staged ledger for \
                   uptime service"
                  ~metadata:[("error", Error_json.error_to_yojson e)] ;
                Interruptible.return ()
            | Ok [] ->
                [%log info]
                  "No SNARK jobs available for uptime service, sending just \
                   the block" ;
                let state_hash =
                  Transition_frontier.Breadcrumb.state_hash best_tip
                in
                let block_data =
                  { block= block_base64
                  ; created_at= get_rfc3339_time ()
                  ; peer_id
                  ; snark_work= None }
                in
                send_uptime_data ~logger ~interruptor ~submitter_keypair ~url
                  ~state_hash block_data
            | Ok job_one_or_twos -> (
                let transitions =
                  List.concat_map job_one_or_twos ~f:One_or_two.to_list
                  |> List.filter ~f:(function
                       | Snark_work_lib.Work.Single.Spec.Transition _ ->
                           true
                       | Merge _ ->
                           false )
                in
                let staged_ledger_hash =
                  Transition_frontier.Breadcrumb.blockchain_state best_tip
                  |> Mina_state.Blockchain_state.staged_ledger_hash
                in
                match
                  List.find transitions ~f:(fun transition ->
                      match transition with
                      | Snark_work_lib.Work.Single.Spec.Transition
                          ({target; _}, _, _) ->
                          Marlin_plonk_bindings_pasta_fp.equal target
                            (Staged_ledger_hash.ledger_hash staged_ledger_hash)
                      | Merge _ ->
                          (* unreachable *)
                          failwith "Expected Transition work, not Merge" )
                with
                | None ->
                    [%log info]
                      "No transactions in block match staged ledger hash, \
                       sending block without SNARK work" ;
                    let state_hash =
                      Transition_frontier.Breadcrumb.state_hash best_tip
                    in
                    let block_data =
                      { block= block_base64
                      ; created_at= get_rfc3339_time ()
                      ; peer_id
                      ; snark_work= None }
                    in
                    send_uptime_data ~logger ~interruptor ~submitter_keypair
                      ~url ~state_hash block_data
                | Some single_spec -> (
                    match%bind
                      make_interruptible
                        (Prod.perform_single worker_state ~message single_spec)
                    with
                    | Error e ->
                        [%log error]
                          "Error when computing SNARK work for uptime service"
                          ~metadata:[("error", Error_json.error_to_yojson e)] ;
                        Interruptible.return ()
                    | Ok (proof, proof_time) -> (
                        let work =
                          `One
                            (Snark_work_lib.Work.Single.Spec.statement
                               single_spec)
                        in
                        let fee =
                          { Fee_with_prover.fee= snark_work_fee
                          ; prover=
                              submitter_keypair.public_key
                              |> Public_key.compress }
                        in
                        ( match
                            Network_pool.Snark_pool.Resource_pool.add_snark
                              snark_resource_pool ~is_local:true ~work
                              ~proof:(`One proof) ~fee
                          with
                        | `Added ->
                            [%log info]
                              "Added work created for uptime service to SNARK \
                               pool"
                        | `Statement_not_referenced ->
                            [%log error]
                              "Statement not referenced error when trying to \
                               add SNARK for uptime service to pool" ) ;
                        let proof_data : Proof_data.t =
                          {proof; proof_time; snark_work_fee}
                        in
                        let proof_string =
                          Binable.to_string (module Proof_data) proof_data
                        in
                        match Base64.encode proof_string with
                        | Error (`Msg err) ->
                            [%log error]
                              "Could not Base64-encode SNARK work for uptime \
                               service"
                              ~metadata:[("error", `String err)] ;
                            Interruptible.return ()
                        | Ok snark_work_base64 ->
                            let state_hash =
                              Transition_frontier.Breadcrumb.state_hash
                                best_tip
                            in
                            let block_data =
                              { block= block_base64
                              ; created_at= get_rfc3339_time ()
                              ; peer_id
                              ; snark_work= Some snark_work_base64 }
                            in
                            send_uptime_data ~logger ~interruptor
                              ~submitter_keypair ~url ~state_hash block_data )
                    ) ) ) )

let start (mina : Mina_lib.t) =
  let config = Mina_lib.config mina in
  let transition_frontier = Mina_lib.transition_frontier mina in
  match config.uptime_url with
  | None ->
      [%log' info config.logger] "Not running uptime service, no URL given" ;
      ()
  | Some url ->
      [%log' info config.logger] "Starting uptime service using URL $url"
        ~metadata:[("url", `String (Uri.to_string url))] ;
      let slot_duration_ms =
        Consensus.Configuration.t
          ~constraint_constants:Genesis_constants.Constraint_constants.compiled
          ~protocol_constants:Genesis_constants.compiled.protocol
        |> Consensus.Configuration.slot_duration |> Float.of_int
      in
      let five_slots_span = Time.Span.of_ms (slot_duration_ms *. 5.0) in
      let four_slots_span = Time.Span.of_ms (slot_duration_ms *. 4.0) in
      don't_wait_for
        (let next_slot_time =
           let block_time_ms_int64 =
             Block_time.now (Mina_lib.time_controller mina)
             |> Block_time.to_int64
           in
           let slot_duration_ms_int64 = Float.to_int64 slot_duration_ms in
           let next_slot_ms =
             if
               Int64.equal Int64.zero
                 (Int64.(rem) block_time_ms_int64 slot_duration_ms_int64)
             then block_time_ms_int64
             else
               let last_slot_no =
                 Int64.( / ) block_time_ms_int64 slot_duration_ms_int64
               in
               Int64.( * ) (Int64.succ last_slot_no) slot_duration_ms_int64
           in
           Block_time.of_int64 next_slot_ms |> Block_time.to_time
         in
         let register_iteration =
           let interrupt_ivar = ref (Ivar.create ()) in
           fun () ->
             (* terminate anything running from previous iteration *)
             Ivar.fill_if_empty !interrupt_ivar () ;
             Deferred.create (fun ivar -> interrupt_ivar := ivar)
         in
         [%log' trace config.logger]
           "Uptime service synchronizing to next slot boundary" ;
         let%map () = at next_slot_time in
         (* every 5 slots, check whether block will be produced *)
         Async.Clock.every' ~continue_on_error:true five_slots_span (fun () ->
             let interruptor = register_iteration () in
             [%log' trace config.logger]
               "Uptime service determining which action to take" ;
             (* see if block scheduled within 4 slots, allowing a full slot
                to produce the block within an iteration of the `every'`
             *)
             let four_slots_from_now =
               Time.add (Time.now ()) four_slots_span
             in
             let get_next_producer_time_opt () =
               match Mina_lib.next_producer_timing mina with
               | None ->
                   [%log' trace config.logger]
                     "Next producer timing not set for uptime service" ;
                   None
               | Some timing -> (
                   let open Daemon_rpcs.Types.Status.Next_producer_timing in
                   match timing.timing with
                   | Check_again _tm ->
                       [%log' trace config.logger]
                         "Next producer timing not available for uptime service" ;
                       None
                   | Produce prod_tm | Produce_now prod_tm ->
                       Some (Block_time.to_time prod_tm.time) )
             in
             match config.gossip_net_params.addrs_and_ports.peer with
             | None ->
                 [%log' warn config.logger]
                   "Daemon is not yet a peer in the gossip network, uptime \
                    service not sending a produced block" ;
                 Deferred.unit
             | Some {peer_id; _} ->
                 (* daemon startup checked that a keypair was given if URL given *)
                 let submitter_keypair =
                   Option.value_exn config.uptime_submitter_keypair
                 in
                 let block_produced_bvar = Mina_lib.block_produced_bvar mina in
                 let send_just_block next_producer_time =
                   [%log' info config.logger]
                     "Uptime service will attempt to send the next produced \
                      block" ;
                   send_produced_block_at ~logger:config.logger ~interruptor
                     ~url ~peer_id ~submitter_keypair ~block_produced_bvar
                     next_producer_time
                 in
                 let send_block_and_snark_work () =
                   [%log' info config.logger]
                     "Uptime service will attempt to send a block and SNARK \
                      work" ;
                   let snark_resource_pool =
                     Mina_lib.snark_pool mina
                     |> Network_pool.Snark_pool.resource_pool
                   in
                   let snark_work_fee = Mina_lib.snark_work_fee mina in
                   send_block_and_transaction_snark ~logger:config.logger
                     ~interruptor ~url ~transition_frontier ~peer_id
                     ~submitter_keypair ~snark_resource_pool ~snark_work_fee
                 in
                 Interruptible.don't_wait_for
                   ( match get_next_producer_time_opt () with
                   | None ->
                       send_block_and_snark_work ()
                   | Some next_producer_time ->
                       if Time.( <= ) next_producer_time four_slots_from_now
                       then send_just_block next_producer_time
                       else send_block_and_snark_work () ) ;
                 Deferred.unit ))
