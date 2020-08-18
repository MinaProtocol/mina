open Async
open Core
module Timeout = Timeout_lib.Core_time

(** This implements Log_engine_intf for stack driver logs for integration tests
    Assumptions:
      1. gcloud is installed and authorized to perform logging and pubsub related changes
      2. gcloud API key is set in the environment variable GCLOUD_API_KEY*)

(*Project Id is required for creating topic, sinks, and subscriptions*)
let project_id = "o1labs-192920"

let prog = "gcloud"

let load_config_json json_str =
  Or_error.try_with (fun () -> Yojson.Safe.from_string json_str)

let rec or_error_list_iter ls ~f =
  let open Or_error.Let_syntax in
  match ls with
  | [] ->
      return ()
  | h :: t ->
      let%bind () = f h in
      or_error_list_iter t ~f

let rec or_error_list_map ls ~f =
  let open Or_error.Let_syntax in
  match ls with
  | [] ->
      return []
  | h :: t ->
      let%bind h' = f h in
      let%map t' = or_error_list_map t ~f in
      h' :: t'

let rec or_error_list_fold_left_while ls ~init ~f =
  let open Or_error.Let_syntax in
  match ls with
  | [] ->
      return init
  | h :: t -> (
      match%bind f init h with
      | `Stop init' ->
          return init'
      | `Continue init' ->
          or_error_list_fold_left_while t ~init:init' ~f )

let or_error_of_option opt msg =
  Option.value_map opt
    ~default:(Error (Error.of_string msg))
    ~f:Or_error.return

let coda_container_filter = "resource.labels.container_name=\"coda\""

let block_producer_filter = "resource.labels.pod_name:\"block-producer\""

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
    [%log' debug logger] "Create sink response: $response"
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
    let open Deferred.Or_error.Let_syntax in
    let subscription_id =
      String.concat ~sep:"/" ["projects"; project_id; "subscriptions"; t.name]
    in
    (* The limit for messages we pull on each interval is currently not configurable. For now, it's set to 5 (which will hopefully be a sane for a while). *)
    let%bind result =
      Process.run ~prog
        ~args:
          [ "pubsub"
          ; "subscriptions"
          ; "pull"
          ; subscription_id
          ; "--auto-ack"
          ; "--limit"
          ; string_of_int 5
          ; "--format"
          ; "table(DATA)" ]
        ()
    in
    match String.split_lines result with
    | [] | ["DATA"] ->
        return []
    | "DATA" :: data ->
        Deferred.return (or_error_list_map data ~f:load_config_json)
    | _ ->
        Deferred.return
          (Error
             (Error.of_string
                (sprintf "Invalid subscription pull result: %s" result)))
end

module Json_parsing = struct
  open Yojson.Safe.Util

  type 'a parser = Yojson.Safe.t -> 'a

  let bool : bool parser = to_bool

  let string : string parser = to_string

  let int : int parser =
   fun x -> try to_int x with Type_error _ -> int_of_string (to_string x)

  let float : float parser =
   fun x -> try to_float x with Type_error _ -> float_of_string (to_string x)

  let rec find (parser : 'a parser) (json : Yojson.Safe.t) (path : string list)
      : 'a Or_error.t =
    let open Or_error.Let_syntax in
    match (path, json) with
    | [], _ -> (
      try Ok (parser json)
      with exn ->
        Error
          (Error.of_string
             (Printf.sprintf "failed to parse json value: %s"
                (Exn.to_string exn))) )
    | key :: path', `Assoc assoc ->
        let%bind entry =
          or_error_of_option
            (List.Assoc.find assoc key ~equal:String.equal)
            "failed to find path in json object"
        in
        find parser entry path'
    | _ ->
        Error (Error.of_string "expected json object when searching for path")
end

module Initialization_query = struct
  module Result = struct
    type t = {pod_id: string}
  end

  (* TODO: this is technically the participation query right now; this can retrigger if bootstrap is toggled *)
  let filter testnet_log_filter =
    (*TODO: Structured logging: Block Produced*)
    String.concat ~sep:"\n"
      [ testnet_log_filter
      ; coda_container_filter
      ; "\"Starting Transition Frontier Controller phase\"" ]

  let parse log =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%map pod_id = find string log ["labels"; "k8s-pod/app"] in
    {Result.pod_id}
end

module Block_produced_query = struct
  module Result = struct
    module T = struct
      type t =
        { block_height: int
        ; epoch: int
        ; global_slot: int
        ; snarked_ledger_generated: bool }
      [@@deriving to_yojson]
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
    String.concat ~sep:"\n"
      [ testnet_log_filter
      ; block_producer_filter
      ; coda_container_filter
      ; "\"Successfully produced a new block\"" ]

  (*TODO: Once we transition to structured events, this should call Structured_log_event.parse_exn and match on the structured events that it returns.*)
  let parse json =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let breadcrumb = ["jsonPayload"; "metadata"; "breadcrumb"] in
    let breadcrumb_consensus_state =
      breadcrumb
      @ [ "validated_transition"
        ; "data"
        ; "protocol_state"
        ; "body"
        ; "consensus_state" ]
    in
    let%bind snarked_ledger_generated =
      find bool json (breadcrumb @ ["just_emitted_a_proof"])
    in
    let%bind block_height =
      find int json (breadcrumb_consensus_state @ ["blockchain_length"])
    in
    let%bind global_slot =
      find int json
        (breadcrumb_consensus_state @ ["curr_global_slot"; "slot_number"])
    in
    let%map epoch =
      find int json (breadcrumb_consensus_state @ ["epoch_count"])
    in
    {Result.block_height; global_slot; epoch; snarked_ledger_generated}

  let%test_unit "parse json" =
    (* TODO: paste me back (I was breaking Nathan's syntax highlighting) *)
    (* TODO: the structured log message doesn't contain $breadcrumb *)
    let log =
      Yojson.Safe.from_string
        {|{"insertId":"da1tjxlb148zg2r9m","jsonPayload":{"level":"Trace","message":"Successfully produced a new block: $breadcrumb","metadata":{"breadcrumb":{"just_emitted_a_proof":true,"staged_ledger":"<opaque>","validated_transition":{"data":{"current_protocol_version":"0.1.0","delta_transition_chain_proof":"<opaque>","proposed_protocol_version":"<None>","protocol_state":{"body":{"blockchain_state":{"snarked_ledger_hash":"4mKBT3x4peBudLp8p7ZV8D9qa4hXVu4Mtw8RnjnJUmuYVAmzuMB3qqG76WdN4o1bzBzkWGntjW3fskqGB7qEr14xEHGD23PqW53Pq4pac8vUBv9Wy9sYfNTXXQHUaTKs9Z3SZ4G683vWGiqrPD1CwNL1mfQcE1Y4rZs1PKXYr2Qxd1ysPSBzMdMhHRtCJ8yjL31gy8b5HLEB4TCnvmwcaFjrYqXmZ17iRTouYeAXTwiYa3QwwdLndAFS7Wf1YJwK2WavtqJjL3cHL37UP56bQdiUsDF33iRAX99LJGhFqDD4Ud765rcDrgM1yBdBkyJFAC","staged_ledger_hash":{"non_snark":{"aux_hash":"UDT5mwPQpaazURe2owQEkmhVzs89k5ZT4xiD4nShZ4qV6rPcdi","ledger_hash":"4mKBT3x7o11gxXfS2sukVKACTsUk5HsQUSWH48ycTzAymkW5G6BXLtSVfyFj7q8byjKy24VgLaEstVbke8WC8sQJPot5eBPi6BqTXQn83u2HsrFoYTrRfuC5uExzkvuEHWfg6mFCpsGntcNVvZHBZmCxckP37Ao2X29kWuhvRUjCnJ4zyEGY8Byu7Q5nzf13XXd2uzTwntQFkEUqZ5rVyVdB6KYW14E3vLjZdUF8ijbXkqGHVyLfogfdfBHauiCDsdEKMiQVCQpwVQSmonKxAV14Qvg2yUsCbSru7uLZjLz4rCeZ3A18D8TvUMKqooVEX1","pending_coinbase_aux":"WewbKnjz78S5g6GMgtv5AkaR54HuGAfAX7YHkoMxzZji8dDm82"},"pending_coinbase_hash":"A2UdxEssLAf7MRyLNuccHWj4J9Bsu1XpPVLsenZcQkHto6RkgLBg3kMZemKEaafH4E36sdzvTWQujcADhdMFHMTy2YqFrGWTVzjcQZApLCE91PyFo3Lup5tf3wa7aBTD7x2bSmCRudM93ieGXdASVHDtinSaLAcGMfaA7ioSJEH3nkkXd3zUafThJMcnQvpVR4oHeuYNbAF8dPpKhk3ZGaL6v6FmbyTKVExj3xDx8dr1P3QsAPPrVqhDCM6AU3EpLtvmrLXrzkjh2dvB8TaLgZwg85atjKhbHAX5RUR7395RvMuTLq4ae4gCPJSRhTwuS8"},"timestamp":"1593049680000"},"consensus_state":{"blockchain_length":"3005","curr_global_slot":{"slot_number":"7806","slots_per_epoch":"480"},"epoch_count":"16","has_ancestor_in_same_checkpoint_window":true,"last_vrf_output":"<opaque>","min_window_density":"160","next_epoch_data":{"epoch_length":"38","ledger":{"hash":"4mKBT3x4nFWDa4A67jeH71Jv5UY7xMdekTspnP4AF4rkhxtybgKjrb9dKkYMein6CUBcWTskzZJnZ9RN3HEod9JTWAqwk5CDCBYTVDfUpJRqHsuBZ8ezpCb9oHQfu7eFeGFjY9ijwAZqEwp3gNhNwgS31ed9TcQgEpEPGqRDRYmyCwSTvZHKG2iFqbzzPnkF8ob12R69zYnMcRZmmhpwKeoEHVU23brJmoBTCguZWPKgk7T66kTqB4wiCbrFgb1S8jJtjQynaeocXhV3mqi91hD8fdX6TikxT3YutFBGW92Bn1HfVNYDRybpnrSwH4jEUk","total_currency":"22961500002389927"},"lock_checkpoint":"3j7Fqw9d9wLyNdjTPBSVH3yPDPWMtqUC22L1JSeqnpYMBfHTK7UmtDbYbnCL9mYDccjspNy8vJEnmXMA72qgswFdMocqYWprdWRYCUmhZx2jBKQcjXMjyUm8yFFBU8HfbSHSWfWmFVEXLw15rTR5ELjFy5xQMpgaWWMELu4ArxRc4DBbDebX2ezU4AhXULwsRhgbXw3n8gf6Tfi8GFTMQ8aTfuwmGeLmDAzXY4UvaEFuzcZ4ZFrFHrLZhKXYTbYyKebTBbcYqZScQcBNp1CC76tMP6NJkAaANYMGnRC1atoBwxBx6iCAb8osx12mCYgi9","seed":"3DUfsm6DRo8H9B9evJWxP72s18BAmWbFPMjr1EphFQFF7Fjjas1H8Y3UHGLTCocUKga4Yzh9izSHTvPn7UXN8x87c6soskzRtxjzatt2nPVK7jJ3xB2jMQFKfkmXLh4baiuQkDogz8nzirjbrUDnPsGi85efffcdEdCfV9AazPpZSbJKdvxMY4KZYXmdmtASzyQxeDhfpfCgfuUwfKCdPWi2biXxTrX9GkKLVcJFVCgY1ZggSFGiMn6kB3zxtKqUEJ1KvXnfdsyLsRrQwDKGGfqGSaS2b5baosyBnML27GJUGUDhP7vNipc5EVu1BZUEL","start_checkpoint":"D2rcXVQYc5LPJkNGqsxFSD17vt9o3AkQz3zLhA4mH56MQd1mkbiyMWohyYF6XkraCxLLfrf4G28pkeM2CYCN6Xwu4Sec9jeLigUC25VYZq2N9nLDPtSR9Xrk7SfAVzjpckU9MsYoGXkzzXG6fSKC4DakPFkPy53U2uYhYR963Kypcpjg5qdzu86TzmribmSvf3QEBaxs6svLEodZesaUff8qb2xCswAoZS4FU32kn6ANqXLHZWJZbPomnav9Msmh38rC5o1CGMoYvoEEdkB1qz4PpDLCGxDyNbkJFMC75WVQXbZSMayQ6i6V1hUAsHa9fU"},"staking_epoch_data":{"epoch_length":"184","ledger":{"hash":"4mKBT3x3Jm4wrsafPgLndLRTUBPGStpddFUdyKwKSHLBQh4HfdVon9NsrTbtQBiRLbhyH3uEKgkMbVGTneBSRH1Ub6Rm17FG2JpRHmTEEjaTDFJqk3sfzSzeMA1xxz35gg2czw8Q8SUknoatQ843gkPuEyTiSBXbJTQbXgDmuJXmXSNQ4Xvy5enmAMZfX1Es7wSzjpETmpgSD7sGQXi6yv3F6DsLcHLnHrqoYiipvNvDLM7cr5axY2inWiQboPd2T3rZi2PK2jdJvFu1XRWA5sNMKSciUddq6fn62CzrCTszGm2qdnPWpCrsRLE85heDyz","total_currency":"22924300002389927"},"lock_checkpoint":"D2rcXVQbcpJXNSkH4PtMigWYCwgohjjvR5SzxQ1BXC8TB7aNi722Vd2Rzj4tUWAiZhtzVn4y35R7fJ86XSWign7Nk7uoQAstAuKT9rVsPzWC8tvaWtY21uHVWSFfN6FERmWbR8ESVYcFbMNKeXGeFEXBgiWX7qEQVReqVuapdR72YBitw3Yuh3zHy3TEhRPWecdGYELDXoqGv3H1C8MaWRTUZkXn6TddEfVdtD7SuoH3zQVTcKADBGK7BfJcrd6pU3ScgWBUoaCYND5teWD2fCHGxmjWHiLmgUbqpCaEXYjh6DrwMKdxek2T6XdBpi89Xh","seed":"3DUfsm6FqFmgdfqmKUJbZVWFE1vB3HZQithYfWitucdN24MVAATs2WkmuyLnRmmhAi2Mn7DeqARTCEZz4ZUSK8zP3uvzULWFqxyTR1AeuNwGEReySyDA2KPrTHZiSE6DFBPkxYVhTAxzCxr2s8Hg7DL4VGV36RHJqqzCJuNiur9XTt38zi2T8GEdrowfRgL7e2cKapivbCiVVE1X4XaoKZUHqEbht4YNFTCK6AndB27EvgFHZV3KoR1Ai8DYFasj1YoMw7LxRFn7DqnXnDkgyX3aKNdG2wKJKddB93pWNwgFXg1LnEMvVxjtJmBegyCvk","start_checkpoint":"D2rcXVQd7gciXqjsZrMyQVr2n5AG9vDzQnJMZxb5L8ijvX4iCVggYaaEUVdPALEaxY6uaXT9Jire3qPBb84QBfX8vQX6kV4ojvqxcTqt7gLi2GyupXS2p1u2JN6PMdciLCfmeogLSR2EaH3UdsS1TMoK72UBfFYsD6jvkFSyfNyMMHLJCjNWSwVo6apRtsG1GK7bn4g63zrvn16ezGbmgh8mCFqBzv3KM4c17QZHHEbLS2ya7U6SvtCMDwDaHPgE8Dg2QS1mEqG2DuJ2V9VNnYZshtQUPTLw4fRy4N9fDPLo73LFC1d7y3gMqEoqV2MYFa"},"sub_window_densities":["0","20","20","20","20","20","20","20"],"total_currency":"22969100.002389927"},"constants":{"delta":"3","genesis_state_timestamp":"1591644600000","k":"20"},"genesis_state_hash":"D2rcXVQa8eS14d6EWdpMVoys5aeqjiwJppFQRrdoZLpbsDUoq1a9AVYb1VQtqxPhxT87sQWHWwL7c1z7qWmC72GdedUy7RaqanKpJzCk5B4fMnxDTKFDVc53gZF3Z95pMauhWi12vAvuCK5bstGcAh3ZUJveK6RVmnN6aM2tHjTgcp1uvMfzXTjwBuxX6gGpsFKWZw5gDguQpDqhbMiYJw44Mc2ggKthUnfP2NsxJTkNzfJGknYaarK7wRZNEjHeNtrVfyxZDKyTGg6ZisfPemCYPTyXsvs9MmfmAtNhBAAUFuA1NuxnpfAjbdJ3RacHPW"},"previous_state_hash":"D2rcXVQa7HFVLxWV7V5mktEdnxK22Jp3bhfPtzaGcCmvkiFnxAtUtnfyY3CS1U4Z2qSmW7oNT3jBzGta2mTfGEALMA4NifmmoBJTWeFX1tN2FekYbjpiggBgQuGehoTtnN12w1kNRwm9KsRtqUojCsh4vWxJBk8fedsgvLKhJ8uyUybM3fqN748BTipGSrWZJg1KUgXUWXKK1QZN5xNT2CzgtN1bcDizQQMP16UUCZVgH5zY28RpzBsJYXFZbJK6pShYtiBqfMUTyY3ww2qPUBZAr7AA9buMrBCUXwT1etC5rsNp3iwpDB1feVWDAQgUvx"},"protocol_state_proof":"<opaque>","staged_ledger_diff":"<opaque>"},"hash":"D2rcXVQbc96heSMf2WYXidFqRWbQ1ktQhcjNRV86qm1YQmYGgkd3uSpgrGRb8XAT5JPiR2DdXrnkiYU9t9zpGx77mbe9G8ZW2ABi4X344R68kMamFB6fbnwMoQieVTyXLqXvFqck2cGXQcZYko8gBdusNELVyZxsgRw2pJAiAePADfy2zkxudo4P1iTaDySykXvrSNF8oekts6FcQp6fwCeePGcUm3ktomEjYWTfTwU2YCRgfx5Zn8jADmCbtAhkrX1LAM21EEbygrp2LW12QaZDUE98199UCsyVbJTG4GWswYZbbwR99twkZ3BkjbR98B"}},"host":"35.185.73.134","peer_id":"12D3KooWNqFYDkAseDUAhvTdt73iqex7ooQPKTmRByGiCBgbJvVq","pid":10,"port":10003},"source":{"location":"File \"src/lib/block_producer/block_producer.ml\", line 512, characters 44-51","module":"Block_producer"},"timestamp":"2020-06-25 01:58:02.803079Z"},"labels":{"k8s-pod/app":"whale-block-producer-3","k8s-pod/class":"whale","k8s-pod/pod-template-hash":"6cdf6f4b44","k8s-pod/role":"block-producer","k8s-pod/testnet":"joyous-occasion","k8s-pod/version":"0.0.12-beta-feature-bump-genesis-timestamp-3e9b174"},"logName":"projects/o1labs-192920/logs/stdout","receiveTimestamp":"2020-06-25T01:58:09.007727607Z","resource":{"labels":{"cluster_name":"coda-infra-east","container_name":"coda","location":"us-east1","namespace_name":"joyous-occasion","pod_name":"whale-block-producer-3-6cdf6f4b44-2nlkz","project_id":"o1labs-192920"},"type":"k8s_container"},"severity":"INFO","timestamp":"2020-06-25T01:58:03.766838494Z"}|}
    in
    let _ = parse log |> Or_error.ok_exn in
    ()
end

module Breadcrumb_added_query = struct
  open Coda_base

  module Result = struct
    type t = {user_commands: User_command.t With_status.t list}
  end

  let filter testnet_log_filter =
    String.concat ~sep:"\n"
      [ testnet_log_filter
      ; coda_container_filter
      ; "\"Added breadcrumb user commands\"" ]

  let parse json : Result.t Or_error.t =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    (* JSON path to metadata entry *)
    let path = ["jsonPayload"; "metadata"; "user_commands"] in
    let parser json =
      match json with
      | `List cmds ->
          let cmd_or_errors =
            List.map cmds ~f:(With_status.of_yojson User_command.of_yojson)
          in
          List.fold cmd_or_errors ~init:[] ~f:(fun accum cmd_or_err ->
              match (accum, cmd_or_err) with
              | _, Error _ ->
                  failwith
                    "Breadcrumb_added_query: unable to parse JSON for user \
                     command"
              | cmds, Ok cmd ->
                  cmd :: cmds )
      | _ ->
          failwith "Breadcrumb_added_query: expected `List"
    in
    let%map user_commands = find parser json path in
    Result.{user_commands}
end

module Graphql_ready_query = struct
  module Result = struct
    type t = {pod_name: string; host: Core.Unix.Inet_addr.t; peer_id: string}
  end

  let filter testnet_log_filter =
    (*TODO: Structured logging ? *)
    String.concat ~sep:"\n"
      [testnet_log_filter; coda_container_filter; "\"Created GraphQL server\""]

  let parse log =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind pod_name = find string log ["resource"; "labels"; "pod_name"] in
    let%bind host_string =
      find string log ["jsonPayload"; "metadata"; "host"]
    in
    let host = Core.Unix.Inet_addr.of_string host_string in
    let%map peer_id = find string log ["jsonPayload"; "metadata"; "peer_id"] in
    Result.{pod_name; host; peer_id}
end

type subscriptions =
  { initialization: Subscription.t
  ; graphql_ready: Subscription.t
  ; blocks_produced: Subscription.t
  ; breadcrumb_added: Subscription.t }

type constants =
  { constraints: Genesis_constants.Constraint_constants.t
  ; genesis: Genesis_constants.t }

type t =
  { testnet_log_filter: string
  ; constants: constants
  ; subscriptions: subscriptions
  ; initialization: unit Ivar.t String.Map.t
  ; cancel_initialization_task: unit Ivar.t
  ; logger: Logger.t }

let subscription_list ~logger testnet_log_filter :
    subscriptions Deferred.Or_error.t =
  (*create one subscription per query*)
  let open Deferred.Or_error.Let_syntax in
  let%bind initialization =
    Subscription.create ~logger ~name:"initialization"
      ~filter:(Initialization_query.filter testnet_log_filter)
  in
  let%bind graphql_ready =
    Subscription.create ~logger ~name:"graphql_ready"
      ~filter:(Graphql_ready_query.filter testnet_log_filter)
  in
  let%bind blocks_produced =
    Subscription.create ~logger ~name:"blocks_produced"
      ~filter:(Block_produced_query.filter testnet_log_filter)
  in
  let%map breadcrumb_added =
    Subscription.create ~logger ~name:"breadcrumb_added"
      ~filter:(Breadcrumb_added_query.filter testnet_log_filter)
  in
  {initialization; graphql_ready; blocks_produced; breadcrumb_added}

let delete_subscriptions
    {initialization; graphql_ready; blocks_produced; breadcrumb_added} =
  Deferred.Or_error.combine_errors
  @@ List.map
       [initialization; graphql_ready; blocks_produced; breadcrumb_added]
       ~f:Subscription.delete

let rec watch_for_initialization ~logger initialization_table
    initialization_subscription =
  let open Interruptible in
  let open Interruptible.Let_syntax in
  let handle_result result =
    let open Initialization_query.Result in
    let open Or_error.Let_syntax in
    [%log' info logger] "Handling initialization log for \"%s\"" result.pod_id ;
    let%bind ivar =
      or_error_of_option
        (String.Map.find initialization_table result.pod_id)
        (Printf.sprintf "node not found in initialization table: %s"
           result.pod_id)
    in
    if Ivar.is_empty ivar then ( Ivar.fill ivar () ; return () )
    else
      Error
        (Error.of_string
           "received initialization for node that has already initialized")
  in
  [%log' info logger] "Pulling initialization subscription" ;
  let%bind results =
    uninterruptible
      (let open Deferred.Or_error.Let_syntax in
      let%bind logs = Subscription.pull initialization_subscription in
      Deferred.return (or_error_list_map logs ~f:Initialization_query.parse))
  in
  ( match results with
  | Error err ->
      Error.raise err
  | Ok res ->
      List.iter res ~f:(Fn.compose Or_error.ok_exn handle_result) ) ;
  let%bind () = uninterruptible (after (Time.Span.of_ms 10000.0)) in
  watch_for_initialization ~logger initialization_table
    initialization_subscription

let create ~logger (network : Kubernetes_network.t) =
  let initialization =
    Kubernetes_network.all_nodes network
    |> List.map ~f:(fun node -> (node, Ivar.create ()))
    |> String.Map.of_alist_exn
  in
  match%map subscription_list ~logger network.testnet_log_filter with
  | Ok subscriptions ->
      let cancel_initialization_task = Ivar.create () in
      Interruptible.don't_wait_for
        (let open Interruptible.Let_syntax in
        let%bind () =
          Interruptible.lift (Deferred.return ())
            (Ivar.read cancel_initialization_task)
        in
        watch_for_initialization ~logger initialization
          subscriptions.initialization) ;
      Ok
        { testnet_log_filter= network.testnet_log_filter
        ; constants=
            { constraints= network.constraint_constants
            ; genesis= network.genesis_constants }
        ; subscriptions
        ; initialization
        ; cancel_initialization_task
        ; logger }
  | Error e ->
      Error e

let delete t : unit Deferred.Or_error.t =
  Ivar.fill t.cancel_initialization_task () ;
  match%map delete_subscriptions t.subscriptions with
  | Ok _ ->
      Ok ()
  | Error e' ->
      [%log' fatal t.logger] "Error deleting subscriptions: $error"
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
      let ( ! ) = Int64.of_int in
      let ( * ) = Int64.( * ) in
      let estimated_time =
        match timeout with
        | `Slots n ->
            !n * !(t.constants.constraints.block_window_duration_ms)
        | `Epochs n ->
            !n * 3L
            * !(t.constants.genesis.protocol.k)
            * !(t.constants.constraints.c)
            * !(t.constants.constraints.block_window_duration_ms)
        | `Snarked_ledgers_generated n ->
            (* TODO *)
            !n * 2L * 3L
            * !(t.constants.genesis.protocol.k)
            * !(t.constants.constraints.c)
            * !(t.constants.constraints.block_window_duration_ms)
        | `Milliseconds n ->
            n
      in
      let hard_timeout = estimated_time * 2L in
      Time.add now (Time.Span.of_ms (Int64.to_float hard_timeout))
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
      [%log' info t.logger]
        ~metadata:
          [ ("result", Block_produced_query.Result.to_yojson res)
          ; ("blocks", `Int blocks)
          ; ("epoch_reached", `Int epoch_reached) ]
        "Checking if conditions passed for $result [blocks=$blocks, \
         epoch_reached=$epoch_reached]" ;
      res.block_height >= blocks && res.epoch >= epoch_reached
    in
    (*TODO: this should be block window duration once the constraint constants are added to runtime config*)
    let open Deferred.Or_error.Let_syntax in
    let rec go aggregated_res : unit Deferred.Or_error.t =
      if Time.( > ) (Time.now ()) timeout_safety then
        Deferred.Or_error.error_string "wait_for took too long to complete"
      else if timed_out aggregated_res then Deferred.Or_error.ok_unit
      else (
        [%log' info t.logger] "Pulling blocks produced subscription" ;
        let%bind logs = Subscription.pull t.subscriptions.blocks_produced in
        [%log' info t.logger]
          ~metadata:[("n", `Int (List.length logs)); ("logs", `List logs)]
          "Pulled $n logs for blocks produced: $logs" ;
        let%bind finished, aggregated_res' =
          Deferred.return
            (or_error_list_fold_left_while logs ~init:(false, aggregated_res)
               ~f:(fun (_, acc) log ->
                 let open Or_error.Let_syntax in
                 let%map result = Block_produced_query.parse log in
                 if conditions_passed result then `Stop (true, acc)
                 else
                   `Continue
                     (false, Block_produced_query.Result.aggregate acc result)
             ))
        in
        if not finished then
          let%bind () =
            Deferred.map
              (Async.after
                 (Time.Span.of_ms
                    ( Int.to_float
                        t.constants.constraints.block_window_duration_ms
                    /. 2.0 )))
              ~f:Or_error.return
          in
          go aggregated_res'
        else Deferred.Or_error.return () )
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
  [%log' info t.logger]
    ~metadata:
      [ ("blocks", `Int blocks)
      ; ("epoch", `Int epoch_reached)
      ; ( "timeout"
        , `String
            ( match timeout with
            | `Slots n ->
                Printf.sprintf "%d slots" n
            | `Epochs n ->
                Printf.sprintf "%d epochs" n
            | `Snarked_ledgers_generated n ->
                Printf.sprintf "%d snarked ledgers emitted" n
            | `Milliseconds n ->
                Printf.sprintf "%Ld ms" n ) ) ]
    "Waiting for $blocks blocks, $epoch epoch, with timeout $timeout" ;
  match%bind wait_for' ~blocks ~epoch_reached ~timeout t with
  | Ok _ ->
      Deferred.Or_error.ok_unit
  | Error e ->
      [%log' fatal t.logger] "wait_for failed with error: $error"
        ~metadata:[("error", `String (Error.to_string_hum e))] ;
      let%map res = delete t in
      Or_error.combine_errors_unit [Error e; res]

let wait_for_graphql ~node t =
  [%log' info t.logger] "Waiting for GraphQL server on pod matching $node"
    ~metadata:[("node", `String node)] ;
  let retry_delay_sec = 20.0 in
  let rec go () : unit Deferred.Or_error.t =
    match%bind Subscription.pull t.subscriptions.graphql_ready with
    | Ok [] ->
        [%log' info t.logger] "wait_for_graphql, got empty list, trying again" ;
        let%bind () = after (Time.Span.of_sec retry_delay_sec) in
        go ()
    | Ok jsons ->
        (* we may see GraphQL servers started from multiple pods *)
        let found_match =
          List.fold jsons ~init:false ~f:(fun acc json ->
              match Graphql_ready_query.parse json with
              | Ok {pod_name; host; peer_id}
                when String.is_prefix pod_name ~prefix:node ->
                  [%log' info t.logger]
                    "wait_for_graphql, got $host, $peer_id, $pod_name, which \
                     matches expected node $node"
                    ~metadata:
                      [ ("host", `String (Core.Unix.Inet_addr.to_string host))
                      ; ("peer_id", `String peer_id)
                      ; ("pod_name", `String pod_name)
                      ; ("node", `String node) ] ;
                  true
              | Ok {pod_name; host; peer_id} ->
                  (* don't examine entry if we've found what we're looking for *)
                  acc
                  ||
                  ( [%log' info t.logger]
                      "wait_for_graphql, got $host, $peer_id, $pod_name, \
                       which does not match expected node $node"
                      ~metadata:
                        [ ("host", `String (Core.Unix.Inet_addr.to_string host))
                        ; ("peer_id", `String peer_id)
                        ; ("pod_name", `String pod_name)
                        ; ("node", `String node) ] ;
                    false )
              | Error err ->
                  (* don't fail if we have a matching entry *)
                  acc
                  ||
                  ( [%log' error t.logger]
                      "wait_for_graphql, failed with parse error: $error"
                      ~metadata:[("error", `String (Error.to_string_hum err))] ;
                    false ) )
        in
        if found_match then return (Ok ()) else go ()
    | Error err ->
        [%log' fatal t.logger]
          "wait_for_graphql failed with subscription pull error: $error"
          ~metadata:[("error", `String (Error.to_string_hum err))] ;
        return (Error err)
  in
  go ()

let wait_for_payment ?(num_tries = 30) t ~logger ~sender ~receiver ~amount () =
  let retry_delay_sec = 30.0 in
  let rec go n =
    if n <= 0 then
      return
        (Error
           (Error.of_string
              (sprintf
                 "wait_for_payment: did not find matching payment after %d \
                  trie(s)"
                 num_tries)))
    else
      let%bind results =
        let open Deferred.Or_error.Let_syntax in
        let%bind user_cmds_json =
          Subscription.pull t.subscriptions.breadcrumb_added
        in
        Deferred.return
          (or_error_list_map user_cmds_json ~f:Breadcrumb_added_query.parse)
      in
      match results with
      | Error err ->
          Error.raise err
      | Ok [] ->
          [%log info] "wait_for_payment: no added breadcrumbs, trying again" ;
          let%bind () = after Time.Span.(of_sec retry_delay_sec) in
          go (n - 1)
      | Ok res ->
          let open Coda_base in
          let open Signature_lib in
          (* res is a list of Breadcrumb_added_query.Result.t
           each of those contains a list of user commands
           fold over the fold of each list
           as soon as we find a matching payment, don't
            check any other commands
        *)
          let found =
            List.fold res ~init:false ~f:(fun found_outer {user_commands} ->
                if found_outer then true
                else
                  List.fold user_commands ~init:false
                    ~f:(fun found_inner cmd_with_status ->
                      if found_inner then true
                      else
                        (* N.B.: we're not checking fee, nonce or memo *)
                        let cmd = cmd_with_status.With_status.data in
                        match
                          User_command.payload cmd |> User_command_payload.body
                        with
                        | Payment
                            { source_pk
                            ; receiver_pk
                            ; amount= paid_amt
                            ; token_id= _ } ->
                            Public_key.Compressed.equal source_pk sender
                            && Public_key.Compressed.equal receiver_pk receiver
                            && Currency.Amount.equal paid_amt amount
                        | _ ->
                            false ) )
          in
          if found then (
            [%log info] "wait_for_payment: found matching payment"
              ~metadata:
                [ ("sender", `String (Public_key.Compressed.to_string sender))
                ; ( "receiver"
                  , `String (Public_key.Compressed.to_string receiver) )
                ; ("amount", `String (Currency.Amount.to_string amount)) ] ;
            return (Ok ()) )
          else (
            [%log info]
              "wait_for_payment: found added breadcrumbs, but did not find \
               matching payment" ;
            let%bind () = after Time.Span.(of_sec retry_delay_sec) in
            go (n - 1) )
  in
  go num_tries

let wait_for_init (node : Kubernetes_network.Node.t) t =
  let open Deferred.Or_error.Let_syntax in
  [%log' info t.logger]
    ~metadata:[("node", `String node)]
    "Waiting for $node to initialize" ;
  let%bind init =
    Deferred.return
      (or_error_of_option
         (String.Map.find t.initialization node)
         "failed to find node in initialization table")
  in
  if Ivar.is_full init then return ()
  else
    (* TODO: make configurable (or ideally) compute dynamically from network configuration *)
    Timeout.await_exn ()
      (Deferred.map (Ivar.read init) ~f:Or_error.return)
      ~timeout_duration:(Time.Span.of_ms (15.0 *. 60.0 *. 1000.0))

(*TODO: unit tests without conencting to gcloud. The following test connects to joyous-occasion*)
(*let%test_module "Log tests" =
  ( module struct
    let logger = Logger.create ()

    let testnet : Kubernetes_network.t =
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
