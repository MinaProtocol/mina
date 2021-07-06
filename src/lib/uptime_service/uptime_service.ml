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

type proof_data =
  (Ledger_proof.Stable.Latest.t * Core_kernel.Time.Span.t)
  One_or_two.Stable.Latest.t
[@@deriving bin_io_unversioned]

(* TODO: what's the max size of a serialized block? *)
let block_buf = Bin_prot.Common.create_buf 12_000_000

(* TODO: what the size of a serialized proof? *)
let proof_buf = Bin_prot.Common.create_buf 500_000

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

let send_uptime_data ~logger ~(submitter_keypair : Keypair.t) ~url ~state_hash
    block_data =
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
    Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
        match%map
          Cohttp_async.Client.post ~headers
            ~body:(Yojson.Safe.to_string json |> Cohttp_async.Body.of_string)
            url
        with
        | {status; _}, _body ->
            if Cohttp.Code.code_of_status status = 200 then
              [%log info]
                "Sent block with state hash $state_hash to uptime server at \
                 URL $url"
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson state_hash)
                  ; ( "includes_snark_work"
                    , `Bool (Option.is_some block_data.snark_work) )
                  ; ("url", `String (Uri.to_string url)) ]
            else
              [%log error]
                "Failure when sending block with state hash $state_hash to \
                 uptime server at URL $url"
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson state_hash)
                  ; ("url", `String (Uri.to_string url))
                  ; ("http_code", `Int (Cohttp.Code.code_of_status status))
                  ; ( "http_error"
                    , `String (Cohttp.Code.string_of_status status) ) ] )
  with
  | Ok () ->
      ()
  | Error exn ->
      [%log error]
        "Error when sending block with state hash $state_hash to uptime \
         server at URL $url"
        ~metadata:
          [ ("state_hash", State_hash.to_yojson state_hash)
          ; ("url", `String (Uri.to_string url))
          ; ("error", `String (Exn.to_string exn)) ]

let block_base64_of_breadcrumb ~logger breadcrumb =
  let external_transition = external_transition_of_breadcrumb breadcrumb in
  let block_len =
    External_transition.Stable.Latest.bin_write_t block_buf ~pos:0
      external_transition
  in
  let block_string = String.init block_len ~f:(fun ndx -> block_buf.{ndx}) in
  let block_base64_result = Base64.encode block_string in
  match block_base64_result with
  | Ok block_base64 ->
      Some block_base64
  | Error (`Msg err) ->
      [%log error] "Could not Base64-encode block with state hash $state_hash"
        ~metadata:
          [ ( "state_hash"
            , State_hash.to_yojson
              @@ External_transition.state_hash external_transition )
          ; ("error", `String err) ] ;
      None

let send_produced_block_at ~logger ~url ~transition_frontier ~peer_id
    ~(submitter_keypair : Keypair.t) tm =
  (* give block production some time *)
  let%bind () = at (Time.add tm Time.Span.minute) in
  match Block_producer.last_block_produced_opt () with
  | None ->
      [%log error] "State hash of last block produced unavailable"
        ~metadata:
          [ ( "expected_block_production_time"
            , `String (Time.to_string_abs ~zone:Time.Zone.utc tm) ) ] ;
      return ()
  | Some state_hash -> (
    match Broadcast_pipe.Reader.peek transition_frontier with
    | None ->
        [%log error]
          "Transition frontier not available to obtain produced block with \
           state hash $state_hash"
          ~metadata:[("state_hash", State_hash.to_yojson state_hash)] ;
        return ()
    | Some tf -> (
      match Transition_frontier.find tf state_hash with
      | None ->
          [%log error]
            "Produced block with state hash $state_hash not found in \
             transition frontier"
            ~metadata:[("state_hash", State_hash.to_yojson state_hash)] ;
          return ()
      | Some breadcrumb -> (
        match block_base64_of_breadcrumb ~logger breadcrumb with
        | Some block_base64 ->
            let block_data =
              { block= block_base64
              ; created_at= get_rfc3339_time ()
              ; peer_id
              ; snark_work= None }
            in
            send_uptime_data ~logger ~submitter_keypair ~url ~state_hash
              block_data
        | None ->
            return () ) ) )

let send_block_and_transaction_snark ~logger ~url ~transition_frontier ~peer_id
    ~(submitter_keypair : Keypair.t) =
  match Broadcast_pipe.Reader.peek transition_frontier with
  | None ->
      [%log error]
        "Transition frontier not available to send a block to uptime service" ;
      return ()
  | Some tf -> (
      let breadcrumb = Transition_frontier.best_tip tf in
      match block_base64_of_breadcrumb ~logger breadcrumb with
      | None ->
          [%log info]
            "Could not Base64-encode block, not performing SNARK work" ;
          return ()
      | Some block_base64 -> (
          let message =
            Sok_message.create ~fee:Currency.Fee.zero
              ~prover:(Public_key.compress submitter_keypair.public_key)
          in
          (* mimicking code from standalone snark worker *)
          let module Prod = Snark_worker__Prod.Inputs in
          let%bind ({m; _} as worker_state : Prod.Worker_state.t) =
            Prod.Worker_state.create
              ~constraint_constants:
                Genesis_constants.Constraint_constants.compiled
              ~proof_level:Full ()
          in
          let (module M : Transaction_snark.S) = Option.value_exn m in
          let best_tip = Transition_frontier.best_tip tf in
          let best_tip_staged_ledger =
            Transition_frontier.Breadcrumb.staged_ledger best_tip
          in
          match
            Staged_ledger.all_work_pairs best_tip_staged_ledger
              ~get_state:(fun state_hash ->
                match Transition_frontier.find tf state_hash with
                | None ->
                    Error
                      (Error.createf
                         "Could not find state_hash %s in transition frontier \
                          for uptime service"
                         (State_hash.to_base58_check state_hash))
                | Some breadcrumb ->
                    Ok
                      (Transition_frontier.Breadcrumb.protocol_state breadcrumb)
            )
          with
          | Error e ->
              [%log error]
                "Could not get SNARK work from best tip staged ledger for \
                 uptime service"
                ~metadata:[("error", Error_json.error_to_yojson e)] ;
              return ()
          | Ok [] ->
              [%log info] "No SNARK jobs available for uptime service" ;
              return ()
          | Ok jobs -> (
              let last_job = List.last_exn jobs in
              match%bind
                One_or_two.Deferred_result.map last_job ~f:(fun single_spec ->
                    Prod.perform_single worker_state ~message single_spec )
              with
              | Error e ->
                  [%log error]
                    "Error when computing SNARK work for uptime service"
                    ~metadata:[("error", Error_json.error_to_yojson e)] ;
                  return ()
              | Ok proofs -> (
                  let proof_len =
                    bin_write_proof_data proof_buf ~pos:0 proofs
                  in
                  let proof_string =
                    String.init proof_len ~f:(fun ndx -> proof_buf.{ndx})
                  in
                  match Base64.encode proof_string with
                  | Error (`Msg err) ->
                      [%log error]
                        "Could not Base64-encode SNARK work for uptime service"
                        ~metadata:[("error", `String err)] ;
                      return ()
                  | Ok snark_work_base64 ->
                      let state_hash =
                        Transition_frontier.Breadcrumb.state_hash best_tip
                      in
                      let block_data =
                        { block= block_base64
                        ; created_at= get_rfc3339_time ()
                        ; peer_id
                        ; snark_work= Some snark_work_base64 }
                      in
                      send_uptime_data ~logger ~submitter_keypair ~url
                        ~state_hash block_data ) ) ) )

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
      (* every 5 slots, check whether block will be produced *)
      Async.Clock.every' ~continue_on_error:true five_slots_span (fun () ->
          [%log' trace config.logger]
            "Uptime service determining which action to take" ;
          let now = Time.now () in
          let five_slots_from_now = Time.add now five_slots_span in
          let get_next_producer_time_opt () =
            match Mina_lib.next_producer_timing mina with
            | None ->
                [%log' trace config.logger]
                  "Next producer timing not set for uptime service" ;
                return None
            | Some timing -> (
                let open Daemon_rpcs.Types.Status.Next_producer_timing in
                match timing.timing with
                | Check_again _tm ->
                    [%log' trace config.logger]
                      "Next producer timing not available for uptime service" ;
                    return None
                | Produce prod_tm | Produce_now prod_tm ->
                    return (Some (Block_time.to_time prod_tm.time)) )
          in
          match
            ( config.gossip_net_params.addrs_and_ports.peer
            , config.uptime_submitter_keypair )
          with
          | None, _ ->
              [%log' warn config.logger]
                "Daemon is not yet a peer in the gossip network, uptime \
                 service not sending a produced block" ;
              return ()
          | Some _, None ->
              (* should be unreachable *)
              failwith
                "No uptime submitter keypair, though a submitter URL was given"
          | Some {peer_id; _}, Some submitter_keypair -> (
              let send_just_block next_producer_time =
                [%log' info config.logger]
                  "Uptime service will attempt to send the next produced block" ;
                send_produced_block_at ~logger:config.logger ~url
                  ~transition_frontier ~peer_id ~submitter_keypair
                  next_producer_time
              in
              let send_block_and_snark_work () =
                [%log' info config.logger]
                  "Uptime service will attempt to send a block and SNARK work" ;
                send_block_and_transaction_snark ~logger:config.logger ~url
                  ~transition_frontier ~peer_id ~submitter_keypair
              in
              match%bind get_next_producer_time_opt () with
              | None ->
                  send_block_and_snark_work ()
              | Some next_producer_time ->
                  if Time.( <= ) next_producer_time five_slots_from_now then
                    send_just_block next_producer_time
                  else send_block_and_snark_work () ) )
