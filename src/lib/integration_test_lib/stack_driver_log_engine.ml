open Async
open Core

(** This implements Log_engine_intf for stack driver logs for integration tests
    Assumptions:
      1. gcloud is installed and authorized to perform logging and pubsub related changes
      2. gcloud API key is set in the environment variable GCLOUD_API_KEY*)

(*Project Id is required for creating topic, sinks, and subscriptions*)
let project_id = "o1labs-192920"

let prog = "gcloud"

let load_config_json json_str =
  Or_error.try_with (fun () -> Yojson.Safe.from_string json_str)

module Subscription = struct
  type t = {name: string; topic: string; sink: string}

  (*Using the api endpoint to create a sink instead of the gcloud command
  because the cli doesn't allow setting the writerIdentity account for the sink
  and instead generates an account that doesn't have permissions to publish
  logs to the topic. The account needs to be given permissions explicitly and
  then there's this from the documentation:
    There is a delay between creating the sink and using the sink's new service
     account to authorize writing to the export destination. During the first 24
     hours after sink creation, you might see permission-related error messages
     from the sink on your project's Activity page; you can ignore them.
  *)
  let create_sink ~topic ~filter ~key ~logger name =
    let open Deferred.Or_error.Let_syntax in
    let url =
      "https://logging.googleapis.com/v2/projects/o1labs-192920/sinks?key="
      ^ key
    in
    let%bind authorization =
      let%map token =
        Process.run ~prog ~args:["auth"; "print-access-token"] ()
      in
      let token = String.strip token in
      String.concat ["Authorization: Bearer "; token]
    in
    let req_type = "Accept: application/json" in
    let content_type = "Content-Type: application/json" in
    let destination =
      String.concat ~sep:"/"
        ["pubsub.googleapis.com"; "projects"; project_id; "topics"; topic]
    in
    let header = "--header" in
    let data =
      `Assoc
        [ ("name", `String name)
        ; ("description", `String "Sink for tests")
        ; ("destination", `String destination)
        ; ("filter", `String filter) ]
      |> Yojson.Safe.to_string
    in
    let%bind response =
      Process.run ~prog:"curl"
        ~args:
          [ "--request"
          ; "POST"
          ; url
          ; header
          ; authorization
          ; header
          ; req_type
          ; header
          ; content_type
          ; "--data"
          ; data
          ; "--compressed" ]
        ()
    in
    let%bind response_json = Deferred.return @@ load_config_json response in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      "Create sink response: $response"
      ~metadata:[("response", response_json)] ;
    match
      Yojson.Safe.Util.(to_option Fn.id (member "error" response_json))
    with
    | Some _ ->
        Deferred.Or_error.errorf !"Error when creating sink: %s" response
    | None ->
        Deferred.Or_error.ok_unit

  let create ~name ~filter ~logger =
    let open Deferred.Or_error.Let_syntax in
    let uuid = Uuid_unix.create () in
    let name = name ^ "_" ^ Uuid.to_string uuid in
    let gcloud_key_file_env = "GCLOUD_API_KEY" in
    let%bind key =
      match Sys.getenv gcloud_key_file_env with
      | Some key ->
          return key
      | None ->
          Deferred.Or_error.errorf
            "Set environment variable %s with the service account key to use \
             Stackdriver logging"
            gcloud_key_file_env
    in
    let create_topic name =
      Process.run ~prog ~args:["pubsub"; "topics"; "create"; name] ()
    in
    let create_subscription name topic =
      Process.run ~prog
        ~args:
          [ "pubsub"
          ; "subscriptions"
          ; "create"
          ; name
          ; "--topic"
          ; topic
          ; "--topic-project"
          ; project_id ]
        ()
    in
    let topic = name ^ "_topic" in
    let sink = name ^ "_sink" in
    let%bind _ = create_topic topic in
    let%bind _ = create_sink ~topic ~filter ~key ~logger sink in
    let%map _ = create_subscription name topic in
    {name; topic; sink}

  let delete t =
    let delete_subscription () =
      Process.run ~prog
        ~args:
          ["pubsub"; "subscriptions"; "delete"; t.name; "--project"; project_id]
        ()
    in
    let delete_sink () =
      Process.run ~prog
        ~args:["logging"; "sinks"; "delete"; t.sink; "--project"; project_id]
        ()
    in
    let delete_topic () =
      Process.run ~prog
        ~args:["pubsub"; "topics"; "delete"; t.topic; "--project"; project_id]
        ()
    in
    Deferred.Or_error.combine_errors
      [delete_subscription (); delete_sink (); delete_topic ()]

  let pull t =
    let subscription_id =
      String.concat ~sep:"/" ["projects"; project_id; "subscriptions"; t.name]
    in
    (*By default limits to one log line per pull request*)
    Process.run ~prog
      ~args:
        [ "pubsub"
        ; "subscriptions"
        ; "pull"
        ; subscription_id
        ; "--format"
        ; "table(DATA)" ]
      ()
end

module Block_produced_query = struct
  module Result = struct
    module T = struct
      type t =
        { block_height: int
        ; epoch: int
        ; global_slot: int
        ; snarked_ledger_generated: bool }
    end

    include T

    let empty =
      { block_height= 0
      ; epoch= 0
      ; global_slot= 0
      ; snarked_ledger_generated= false }

    (*Aggregated values for determining timeout conditions. Note: Slots passed and epochs passed are only determined if we produce a block. Add a log for these events to calculate these independently?*)
    module Aggregated = struct
      type t =
        { last_seen_result: T.t
        ; blocks_generated: int
        ; slots_passed: int
        ; epochs_passed: int
        ; snarked_ledgers_generated: int }

      let empty =
        { last_seen_result= empty
        ; blocks_generated= 0
        ; slots_passed= 0
        ; epochs_passed= 0
        ; snarked_ledgers_generated= 0 }

      let init (result : T.t) =
        { last_seen_result= result
        ; blocks_generated= 1
        ; slots_passed= 1
        ; epochs_passed= 0
        ; snarked_ledgers_generated=
            (if result.snarked_ledger_generated then 1 else 0) }
    end

    (*Todo: Reorg will mess up the value of snarked_ledgers_generated*)
    let aggregate (aggregated : Aggregated.t) (result : t) : Aggregated.t =
      if result.block_height > aggregated.last_seen_result.block_height then
        { Aggregated.last_seen_result= result
        ; blocks_generated= aggregated.blocks_generated + 1
        ; slots_passed=
            aggregated.slots_passed
            + (result.global_slot - aggregated.last_seen_result.global_slot)
        ; epochs_passed=
            aggregated.epochs_passed
            + (result.epoch - aggregated.last_seen_result.epoch)
        ; snarked_ledgers_generated=
            ( if result.snarked_ledger_generated then
              aggregated.snarked_ledgers_generated + 1
            else aggregated.snarked_ledgers_generated ) }
      else aggregated
  end

  let filter testnet_log_filter =
    (*TODO: Structured logging: Block Produced*)
    String.concat ~sep:" "
      [ testnet_log_filter
      ; "resource.labels.project_id="
      ; project_id
      ; "resource.labels.pod_name:"
      ; "\"block-producer\""
      ; "resource.labels.container_name="
      ; "coda"
      ; "\"successfully produced a\"" ]

  (*Map of json associations flattened*)
  let rec json_field_map ~key (json : Yojson.Safe.t)
      (map : Yojson.Safe.t String.Map.t) =
    match json with
    | `String _ | `Int _ | `Null | `Bool _ | `Float _ | `Intlit _ ->
        Ok (Map.set map ~key ~data:json)
    | `Assoc assoc_list ->
        List.fold_until assoc_list ~init:(Ok map)
          ~f:(fun acc (key_nested, json) ->
            match acc with
            | Error e ->
                Stop (Error e)
            | Ok acc ->
                let key =
                  String.concat
                    [key; (if key = "" then "" else "."); key_nested]
                in
                Continue (json_field_map ~key json acc) )
          ~finish:Fn.id
    | `List lst ->
        (*TODO: expand this if needed, for example: "sub_window_densities":["0","20","20","20","20","20","20","20"]*)
        Ok (Map.set map ~key ~data:(`List lst))
    | _ ->
        Error
          (Error.of_string
             (sprintf "Invalid json object %s" (Yojson.Safe.to_string json)))

  (*TODO: Once we transition to structured events, this should call Structured_log_event.parse_exn and match on the structured events that it returns.*)
  let parse_log log =
    let open Or_error.Let_syntax in
    let%bind json = load_config_json log in
    let%bind json_map = json_field_map ~key:"" json String.Map.empty in
    let extract_int json =
      Or_error.try_with (fun _ ->
          Yojson.Safe.Util.to_string json |> Int.of_string )
    in
    let extract_bool json =
      Or_error.try_with (fun _ -> Yojson.Safe.Util.to_bool json)
    in
    let find_int json_field =
      Map.find_or_error json_map json_field >>= fun h -> extract_int h
    in
    let%bind block_height =
      find_int
        "jsonPayload.metadata.breadcrumb.validated_transition.data.protocol_state.body.consensus_state.blockchain_length"
    in
    let%bind global_slot =
      find_int
        "jsonPayload.metadata.breadcrumb.validated_transition.data.protocol_state.body.consensus_state.curr_global_slot.slot_number"
    in
    let%bind snarked_ledger_generated =
      Map.find_or_error json_map
        "jsonPayload.metadata.breadcrumb.just_emitted_a_proof"
      >>= fun h -> extract_bool h
    in
    let%map epoch =
      find_int
        "jsonPayload.metadata.breadcrumb.validated_transition.data.protocol_state.body.consensus_state.epoch_count"
    in
    Some {Result.block_height; global_slot; epoch; snarked_ledger_generated}

  let parse result =
    let open Or_error.Let_syntax in
    let%bind log_line =
      match String.split_lines result with
      | [] | ["DATA"] ->
          Ok None
      | ["DATA"; x] | [x] ->
          Ok (Some x)
      | _ ->
          Error
            (Error.of_string
               (sprintf "Invalid result from block-produced logs. %s" result))
    in
    match log_line with None -> Ok None | Some log_line -> parse_log log_line

  let%test_unit "parse json" =
    let log =
      {|{"insertId":"da1tjxlb148zg2r9m","jsonPayload":{"level":"Trace","message":"Successfully produced a new block: $breadcrumb","metadata":{"breadcrumb":{"just_emitted_a_proof":true,"staged_ledger":"<opaque>","validated_transition":{"data":{"current_protocol_version":"0.1.0","delta_transition_chain_proof":"<opaque>","proposed_protocol_version":"<None>","protocol_state":{"body":{"blockchain_state":{"snarked_ledger_hash":"4mKBT3x4peBudLp8p7ZV8D9qa4hXVu4Mtw8RnjnJUmuYVAmzuMB3qqG76WdN4o1bzBzkWGntjW3fskqGB7qEr14xEHGD23PqW53Pq4pac8vUBv9Wy9sYfNTXXQHUaTKs9Z3SZ4G683vWGiqrPD1CwNL1mfQcE1Y4rZs1PKXYr2Qxd1ysPSBzMdMhHRtCJ8yjL31gy8b5HLEB4TCnvmwcaFjrYqXmZ17iRTouYeAXTwiYa3QwwdLndAFS7Wf1YJwK2WavtqJjL3cHL37UP56bQdiUsDF33iRAX99LJGhFqDD4Ud765rcDrgM1yBdBkyJFAC","staged_ledger_hash":{"non_snark":{"aux_hash":"UDT5mwPQpaazURe2owQEkmhVzs89k5ZT4xiD4nShZ4qV6rPcdi","ledger_hash":"4mKBT3x7o11gxXfS2sukVKACTsUk5HsQUSWH48ycTzAymkW5G6BXLtSVfyFj7q8byjKy24VgLaEstVbke8WC8sQJPot5eBPi6BqTXQn83u2HsrFoYTrRfuC5uExzkvuEHWfg6mFCpsGntcNVvZHBZmCxckP37Ao2X29kWuhvRUjCnJ4zyEGY8Byu7Q5nzf13XXd2uzTwntQFkEUqZ5rVyVdB6KYW14E3vLjZdUF8ijbXkqGHVyLfogfdfBHauiCDsdEKMiQVCQpwVQSmonKxAV14Qvg2yUsCbSru7uLZjLz4rCeZ3A18D8TvUMKqooVEX1","pending_coinbase_aux":"WewbKnjz78S5g6GMgtv5AkaR54HuGAfAX7YHkoMxzZji8dDm82"},"pending_coinbase_hash":"A2UdxEssLAf7MRyLNuccHWj4J9Bsu1XpPVLsenZcQkHto6RkgLBg3kMZemKEaafH4E36sdzvTWQujcADhdMFHMTy2YqFrGWTVzjcQZApLCE91PyFo3Lup5tf3wa7aBTD7x2bSmCRudM93ieGXdASVHDtinSaLAcGMfaA7ioSJEH3nkkXd3zUafThJMcnQvpVR4oHeuYNbAF8dPpKhk3ZGaL6v6FmbyTKVExj3xDx8dr1P3QsAPPrVqhDCM6AU3EpLtvmrLXrzkjh2dvB8TaLgZwg85atjKhbHAX5RUR7395RvMuTLq4ae4gCPJSRhTwuS8"},"timestamp":"1593049680000"},"consensus_state":{"blockchain_length":"3005","curr_global_slot":{"slot_number":"7806","slots_per_epoch":"480"},"epoch_count":"16","has_ancestor_in_same_checkpoint_window":true,"last_vrf_output":"<opaque>","min_window_density":"160","next_epoch_data":{"epoch_length":"38","ledger":{"hash":"4mKBT3x4nFWDa4A67jeH71Jv5UY7xMdekTspnP4AF4rkhxtybgKjrb9dKkYMein6CUBcWTskzZJnZ9RN3HEod9JTWAqwk5CDCBYTVDfUpJRqHsuBZ8ezpCb9oHQfu7eFeGFjY9ijwAZqEwp3gNhNwgS31ed9TcQgEpEPGqRDRYmyCwSTvZHKG2iFqbzzPnkF8ob12R69zYnMcRZmmhpwKeoEHVU23brJmoBTCguZWPKgk7T66kTqB4wiCbrFgb1S8jJtjQynaeocXhV3mqi91hD8fdX6TikxT3YutFBGW92Bn1HfVNYDRybpnrSwH4jEUk","total_currency":"22961500002389927"},"lock_checkpoint":"3j7Fqw9d9wLyNdjTPBSVH3yPDPWMtqUC22L1JSeqnpYMBfHTK7UmtDbYbnCL9mYDccjspNy8vJEnmXMA72qgswFdMocqYWprdWRYCUmhZx2jBKQcjXMjyUm8yFFBU8HfbSHSWfWmFVEXLw15rTR5ELjFy5xQMpgaWWMELu4ArxRc4DBbDebX2ezU4AhXULwsRhgbXw3n8gf6Tfi8GFTMQ8aTfuwmGeLmDAzXY4UvaEFuzcZ4ZFrFHrLZhKXYTbYyKebTBbcYqZScQcBNp1CC76tMP6NJkAaANYMGnRC1atoBwxBx6iCAb8osx12mCYgi9","seed":"3DUfsm6DRo8H9B9evJWxP72s18BAmWbFPMjr1EphFQFF7Fjjas1H8Y3UHGLTCocUKga4Yzh9izSHTvPn7UXN8x87c6soskzRtxjzatt2nPVK7jJ3xB2jMQFKfkmXLh4baiuQkDogz8nzirjbrUDnPsGi85efffcdEdCfV9AazPpZSbJKdvxMY4KZYXmdmtASzyQxeDhfpfCgfuUwfKCdPWi2biXxTrX9GkKLVcJFVCgY1ZggSFGiMn6kB3zxtKqUEJ1KvXnfdsyLsRrQwDKGGfqGSaS2b5baosyBnML27GJUGUDhP7vNipc5EVu1BZUEL","start_checkpoint":"D2rcXVQYc5LPJkNGqsxFSD17vt9o3AkQz3zLhA4mH56MQd1mkbiyMWohyYF6XkraCxLLfrf4G28pkeM2CYCN6Xwu4Sec9jeLigUC25VYZq2N9nLDPtSR9Xrk7SfAVzjpckU9MsYoGXkzzXG6fSKC4DakPFkPy53U2uYhYR963Kypcpjg5qdzu86TzmribmSvf3QEBaxs6svLEodZesaUff8qb2xCswAoZS4FU32kn6ANqXLHZWJZbPomnav9Msmh38rC5o1CGMoYvoEEdkB1qz4PpDLCGxDyNbkJFMC75WVQXbZSMayQ6i6V1hUAsHa9fU"},"staking_epoch_data":{"epoch_length":"184","ledger":{"hash":"4mKBT3x3Jm4wrsafPgLndLRTUBPGStpddFUdyKwKSHLBQh4HfdVon9NsrTbtQBiRLbhyH3uEKgkMbVGTneBSRH1Ub6Rm17FG2JpRHmTEEjaTDFJqk3sfzSzeMA1xxz35gg2czw8Q8SUknoatQ843gkPuEyTiSBXbJTQbXgDmuJXmXSNQ4Xvy5enmAMZfX1Es7wSzjpETmpgSD7sGQXi6yv3F6DsLcHLnHrqoYiipvNvDLM7cr5axY2inWiQboPd2T3rZi2PK2jdJvFu1XRWA5sNMKSciUddq6fn62CzrCTszGm2qdnPWpCrsRLE85heDyz","total_currency":"22924300002389927"},"lock_checkpoint":"D2rcXVQbcpJXNSkH4PtMigWYCwgohjjvR5SzxQ1BXC8TB7aNi722Vd2Rzj4tUWAiZhtzVn4y35R7fJ86XSWign7Nk7uoQAstAuKT9rVsPzWC8tvaWtY21uHVWSFfN6FERmWbR8ESVYcFbMNKeXGeFEXBgiWX7qEQVReqVuapdR72YBitw3Yuh3zHy3TEhRPWecdGYELDXoqGv3H1C8MaWRTUZkXn6TddEfVdtD7SuoH3zQVTcKADBGK7BfJcrd6pU3ScgWBUoaCYND5teWD2fCHGxmjWHiLmgUbqpCaEXYjh6DrwMKdxek2T6XdBpi89Xh","seed":"3DUfsm6FqFmgdfqmKUJbZVWFE1vB3HZQithYfWitucdN24MVAATs2WkmuyLnRmmhAi2Mn7DeqARTCEZz4ZUSK8zP3uvzULWFqxyTR1AeuNwGEReySyDA2KPrTHZiSE6DFBPkxYVhTAxzCxr2s8Hg7DL4VGV36RHJqqzCJuNiur9XTt38zi2T8GEdrowfRgL7e2cKapivbCiVVE1X4XaoKZUHqEbht4YNFTCK6AndB27EvgFHZV3KoR1Ai8DYFasj1YoMw7LxRFn7DqnXnDkgyX3aKNdG2wKJKddB93pWNwgFXg1LnEMvVxjtJmBegyCvk","start_checkpoint":"D2rcXVQd7gciXqjsZrMyQVr2n5AG9vDzQnJMZxb5L8ijvX4iCVggYaaEUVdPALEaxY6uaXT9Jire3qPBb84QBfX8vQX6kV4ojvqxcTqt7gLi2GyupXS2p1u2JN6PMdciLCfmeogLSR2EaH3UdsS1TMoK72UBfFYsD6jvkFSyfNyMMHLJCjNWSwVo6apRtsG1GK7bn4g63zrvn16ezGbmgh8mCFqBzv3KM4c17QZHHEbLS2ya7U6SvtCMDwDaHPgE8Dg2QS1mEqG2DuJ2V9VNnYZshtQUPTLw4fRy4N9fDPLo73LFC1d7y3gMqEoqV2MYFa"},"sub_window_densities":["0","20","20","20","20","20","20","20"],"total_currency":"22969100.002389927"},"constants":{"delta":"3","genesis_state_timestamp":"1591644600000","k":"20"},"genesis_state_hash":"D2rcXVQa8eS14d6EWdpMVoys5aeqjiwJppFQRrdoZLpbsDUoq1a9AVYb1VQtqxPhxT87sQWHWwL7c1z7qWmC72GdedUy7RaqanKpJzCk5B4fMnxDTKFDVc53gZF3Z95pMauhWi12vAvuCK5bstGcAh3ZUJveK6RVmnN6aM2tHjTgcp1uvMfzXTjwBuxX6gGpsFKWZw5gDguQpDqhbMiYJw44Mc2ggKthUnfP2NsxJTkNzfJGknYaarK7wRZNEjHeNtrVfyxZDKyTGg6ZisfPemCYPTyXsvs9MmfmAtNhBAAUFuA1NuxnpfAjbdJ3RacHPW"},"previous_state_hash":"D2rcXVQa7HFVLxWV7V5mktEdnxK22Jp3bhfPtzaGcCmvkiFnxAtUtnfyY3CS1U4Z2qSmW7oNT3jBzGta2mTfGEALMA4NifmmoBJTWeFX1tN2FekYbjpiggBgQuGehoTtnN12w1kNRwm9KsRtqUojCsh4vWxJBk8fedsgvLKhJ8uyUybM3fqN748BTipGSrWZJg1KUgXUWXKK1QZN5xNT2CzgtN1bcDizQQMP16UUCZVgH5zY28RpzBsJYXFZbJK6pShYtiBqfMUTyY3ww2qPUBZAr7AA9buMrBCUXwT1etC5rsNp3iwpDB1feVWDAQgUvx"},"protocol_state_proof":"<opaque>","staged_ledger_diff":"<opaque>"},"hash":"D2rcXVQbc96heSMf2WYXidFqRWbQ1ktQhcjNRV86qm1YQmYGgkd3uSpgrGRb8XAT5JPiR2DdXrnkiYU9t9zpGx77mbe9G8ZW2ABi4X344R68kMamFB6fbnwMoQieVTyXLqXvFqck2cGXQcZYko8gBdusNELVyZxsgRw2pJAiAePADfy2zkxudo4P1iTaDySykXvrSNF8oekts6FcQp6fwCeePGcUm3ktomEjYWTfTwU2YCRgfx5Zn8jADmCbtAhkrX1LAM21EEbygrp2LW12QaZDUE98199UCsyVbJTG4GWswYZbbwR99twkZ3BkjbR98B"}},"host":"35.185.73.134","peer_id":"12D3KooWNqFYDkAseDUAhvTdt73iqex7ooQPKTmRByGiCBgbJvVq","pid":10,"port":10003},"source":{"location":"File \"src/lib/block_producer/block_producer.ml\", line 512, characters 44-51","module":"Block_producer"},"timestamp":"2020-06-25 01:58:02.803079Z"},"labels":{"k8s-pod/app":"whale-block-producer-3","k8s-pod/class":"whale","k8s-pod/pod-template-hash":"6cdf6f4b44","k8s-pod/role":"block-producer","k8s-pod/testnet":"joyous-occasion","k8s-pod/version":"0.0.12-beta-feature-bump-genesis-timestamp-3e9b174"},"logName":"projects/o1labs-192920/logs/stdout","receiveTimestamp":"2020-06-25T01:58:09.007727607Z","resource":{"labels":{"cluster_name":"coda-infra-east","container_name":"coda","location":"us-east1","namespace_name":"joyous-occasion","pod_name":"whale-block-producer-3-6cdf6f4b44-2nlkz","project_id":"o1labs-192920"},"type":"k8s_container"},"severity":"INFO","timestamp":"2020-06-25T01:58:03.766838494Z"}|}
    in
    let _ = parse_log log |> Or_error.ok_exn in
    ()
end

module Make (Testnet : Test_intf.Testnet_intf) :
  Test_intf.Log_engine_intf with type testnet := Testnet.t = struct
  type subscriptions = {blocks_produced: Subscription.t}

  type t =
    {testnet_log_filter: string; subscriptions: subscriptions; logger: Logger.t}

  let subscription_list ~logger testnet_log_filter :
      subscriptions Deferred.Or_error.t =
    (*create one subscription per query*)
    let open Deferred.Or_error.Let_syntax in
    let%map blocks_produced =
      Subscription.create ~logger ~name:"blocks_produced"
        ~filter:(Block_produced_query.filter testnet_log_filter)
    in
    {blocks_produced}

  let delete_subscriptions subscriptions =
    Subscription.delete subscriptions.blocks_produced

  let create ~logger (testnet : Testnet.t) =
    match%map subscription_list ~logger testnet.testnet_log_filter with
    | Ok subscriptions ->
        Ok
          { testnet_log_filter= testnet.testnet_log_filter
          ; subscriptions
          ; logger }
    | Error e ->
        Error e

  let delete t : unit Deferred.Or_error.t =
    match%map delete_subscriptions t.subscriptions with
    | Ok _ ->
        Ok ()
    | Error e' ->
        Logger.fatal t.logger ~module_:__MODULE__ ~location:__LOC__
          "Error deleting subscriptions: $error"
          ~metadata:[("error", `String (Error.to_string_hum e'))] ;
        Error e'

  (*TODO: Node status. Should that be a part of a node query instead? or we need a new log that has status info and some node identifier*)
  let wait_for' :
         blocks:int
      -> epoch_reached:int
      -> timeout:[ `Slots of int
                 | `Epochs of int
                 | `Snarked_ledgers_generated of int
                 | `Milliseconds of int64 ]
      -> t
      -> unit Deferred.Or_error.t =
   fun ~blocks ~epoch_reached ~timeout t ->
    if blocks = 0 && epoch_reached = 0 && timeout = `Milliseconds 0L then
      Deferred.Or_error.return ()
    else
      let now = Time.now () in
      let timeout_safety =
        (*Don't wait for more than an hour in any case. TODO: make this an argument or compute using the query timeout*)
        Time.add now (Time.Span.of_ms (Int64.to_float 300000L))
      in
      let query_timeout_ms =
        match timeout with
        | `Milliseconds x ->
            Some (Time.add now (Time.Span.of_ms (Int64.to_float x)))
        | _ ->
            None
      in
      let timed_out (res : Block_produced_query.Result.Aggregated.t) =
        match timeout with
        | `Slots x ->
            res.slots_passed >= x
        | `Epochs x ->
            res.epochs_passed >= x
        | `Snarked_ledgers_generated x ->
            res.snarked_ledgers_generated >= x
        | `Milliseconds _ ->
            Time.( > ) (Time.now ()) (Option.value_exn query_timeout_ms)
      in
      let conditions_passed (res : Block_produced_query.Result.t) =
        res.block_height >= blocks && res.epoch >= epoch_reached
      in
      (*TODO: this should be block window duration once the constraint constants are added to runtime config*)
      let block_window_duration =
        Genesis_constants.Constraint_constants.compiled
          .block_window_duration_ms
      in
      let open Deferred.Or_error.Let_syntax in
      let rec go aggregated_res : unit Deferred.Or_error.t =
        if Time.( > ) (Time.now ()) timeout_safety then
          Deferred.Or_error.error_string "wait_for took too long to complete"
        else if timed_out aggregated_res then Deferred.Or_error.ok_unit
        else
          let%bind pull_result =
            Subscription.pull t.subscriptions.blocks_produced
          in
          match Block_produced_query.parse pull_result with
          | Error e ->
              Deferred.return (Error e)
          | Ok None ->
              Deferred.bind
                (Async.after
                   (Time.Span.of_ms (Int.to_float block_window_duration)))
                ~f:(fun () -> go aggregated_res)
          | Ok (Some res) ->
              if conditions_passed res then Deferred.Or_error.ok_unit
              else
                go (Block_produced_query.Result.aggregate aggregated_res res)
      in
      go Block_produced_query.Result.Aggregated.empty

  let wait_for :
         ?blocks:int
      -> ?epoch_reached:int
      -> ?timeout:[ `Slots of int
                  | `Epochs of int
                  | `Snarked_ledgers_generated of int
                  | `Milliseconds of int64 ]
      -> t
      -> unit Deferred.Or_error.t =
   fun ?(blocks = 0) ?(epoch_reached = 0) ?(timeout = `Milliseconds 300000L) t ->
    match%bind wait_for' ~blocks ~epoch_reached ~timeout t with
    | Ok _ ->
        Deferred.Or_error.ok_unit
    | Error e ->
        Logger.fatal t.logger ~module_:__MODULE__ ~location:__LOC__
          "wait_for failed with error: $error"
          ~metadata:[("error", `String (Error.to_string_hum e))] ;
        let%map res = delete t in
        Or_error.combine_errors_unit [Error e; res]
end

(*TODO: unit tests without conencting to gcloud. The following test connects to joyous-occasion*)
(*let%test_module "Log tests" =
  ( module struct
    module Node : Test_intf.Node_intf = struct
      type t = unit

      let start _t = Deferred.unit

      let stop _t = Deferred.unit

      let send_payment _t _input =
        Deferred.Or_error.error_string "Not implemented"
    end

    module Testnet = struct
      type node = Node.t

      type t =
        { block_producers: Node.t list
        ; snark_coordinators: Node.t list
        ; archive_nodes: Node.t list
        ; testnet_log_filter: string }
    end

    include Make (Testnet)

    let logger = Logger.create ()

    let testnet : Testnet.t =
      let k8 = "k8s_container" in
      let location = "us-east1" in
      let cluster_name = "coda-infra-east" in
      let testnet_name = "joyous-occasion" in
      { block_producers= []
      ; snark_coordinators= []
      ; archive_nodes= []
      ; testnet_log_filter=
          String.concat ~sep:" "
            [ "resource.type="
            ; k8
            ; "resource.labels.location="
            ; location
            ; "resource.labels.cluster_name="
            ; cluster_name
            ; "resource.labels.namespace_name="
            ; testnet_name ] }

    let wait_for_block_height () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~blocks:2500 log_engine in
      delete log_engine

    let wait_for_slot_timeout () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~timeout:(`Slots 2) log_engine in
      delete log_engine

    let wait_for_epoch () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~epoch_reached:16 log_engine in
      delete log_engine

    let test_exn f () =
      let%map res = f () in
      Or_error.ok_exn res

    let%test_unit "joyous-occasion - wait_for_block_height" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_block_height)

    let%test_unit "joyous-occasion - wait_for_slot_timeout" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_slot_timeout)

    let%test_unit "joyous-occasion - wait_for_epoch" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_epoch)
  end )*)
