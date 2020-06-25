open Async
open Core

let project_id = "o1labs-192920"

(*Env variable, for the keyfile as well and then gcloud auth activate-service-account account --key-file *)

let prog = "gcloud"

(*install gcloud in the contianer this service will be running and set up the authorization *)

(*module Authentication = struct
  let auth () = 
    (*gcloud iam service-accounts keys create ./SERVICE_ACC_KEYS --iam-account=log-engine-integration-tests@o1labs-192920.iam.gserviceaccount.com
    gcloud auth activate-service-account log-engine-integration-tests@o1labs-192920.iam.gserviceaccount.com --key-file=./SERVICE_ACC_KEYS
   *)
    let service_key_dir = Unix.mkdtemp "/tmp/service_keys"
    in
    let%bind _ = Process.run_exn ~prog ~args:["config"; "set"; "account"; service_account] ()
    in
    (*download service account key*)
    let%bind _ = Process.run_exn ~prog ~args:["iam"; "service-accounts"; "keys"; "create"; service_key_dir^/"service_key"; "--iam-account"; service_account] () in
    (*authenticate*)
    Process.run_exn ~prog ~args:["auth"; "activate-service-account"; service_account; "--key-file"; service_key_dir^/"service_key"] ()

  end*)

let load_config_json json_str =
  Or_error.try_with (fun () -> Yojson.Safe.from_string json_str)

module Subscription = struct
  type t = {name: string; topic: string; sink: string}

  let create_sink ~name ~topic ~filter ~key =
    (* curl -i --request POST https://logging.googleapis.com/v2/projects/o1labs-192920/sinks?key=d296f21253733bd391f9816bb141967def3356be   --header 'Authorization: Bearer ya29.c.KpQB0AdI0EiZVmuvQpb6l6JCaye_tKONbmXgYdWoalUcxcYYOezYec-34BRX5a0yIBoC4wgEUhEn8wwttcZGE7i7hKgIxaIh4GoeKRV_XWRhwQGIFVXUsN3dytiWISGniG5ZiWNwws8IOgXz4fIogaX_ncL3630XtycALh1jTFLIynp_hgwHCSx3eDIcEjqSCm4Dr5UUPA'   --header 'Accept: application/json'   --header 'Content-Type: application/json'   --data '{"name":"sink-using-curl-dfndjf","destination":"pubsub.googleapis.com/projects/o1labs-192920/topics/blocks_produced_4030e2ab-73e6-3d5e-37ca-d60f373fdf70_topic","filter":"resource.type= k8s_container resource.labels.project_id= o1labs-192920 resource.labels.location= us-east1 resource.labels.cluster_name= coda-infra-east resource.labels.namespace_name= joyous-occasion resource.labels.pod_name: \"block-producer\" resource.labels.container_name= coda \"successfully produced a\""}' --compressed

*)
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
    Core.printf "Curl command: \\\" %s"
      (String.concat ~sep:" "
         [ "curl"
         ; "--request"
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
         ; "--compressed" ]) ;
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
    Core.printf "Response %s" response ;
    let%map response_json = Deferred.return @@ load_config_json response in
    match
      Yojson.Safe.Util.(to_option Fn.id (member "error" response_json))
    with
    | Some _ ->
        failwith response
    | None ->
        ()

  let create ~name ~filter =
    let open Deferred.Or_error.Let_syntax in
    let uuid = Uuid_unix.create () in
    let name = name ^ "_" ^ Uuid.to_string uuid in
    let gcloud_key_file_env = "GCLOUD_API_KEY" in
    let%bind key =
      ( match Sys.getenv gcloud_key_file_env with
      | Some key ->
          Ok key
      | None ->
          Error
            (Error.of_string
               (sprintf
                  "Set environment variable %s with the service account key \
                   to use Stackdriver logging"
                  gcloud_key_file_env)) )
      |> Deferred.return
    in
    let create_topic name =
      Process.run ~prog ~args:["pubsub"; "topics"; "create"; name] ()
    in
    (*let create_sink name topic filter =
      let destination = String.concat ~sep:"/" ["pubsub.googleapis.com";"projects"; project_id; "topics"; topic]
      in
      Process.run_exn ~prog ~args:["logging"; "sinks"; "create"; name; destination; "--log-filter"; filter; "--project"; project_id] ()
    in*)
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
    let%bind _ = create_sink ~name:sink ~topic ~filter ~key in
    let%map _ = create_subscription name topic in
    {name; topic; sink}

  let delete t =
    let open Deferred.Let_syntax in
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
    let%map lst =
      Deferred.all [delete_subscription (); delete_sink (); delete_topic ()]
    in
    Or_error.combine_errors lst

  let pull t =
    (* gcloud pubsub subscriptions pull projects/o1labs-192920/subscriptions/block_production_test --auto-ack --format="table(DATA)" --limit=5*)
    let subscription_id =
      String.concat ~sep:"/" ["projects"; project_id; "subscriptions"; t.name]
    in
    (*By default limits to one log line per pull request*)
    Process.run_exn ~prog
      ~args:
        [ "pubsub"
        ; "subscriptions"
        ; "pull"
        ; subscription_id
        ; "--format"
        ; "table(DATA)" ]
      ()
end

module Block_produced_filter = struct
  (*Assumption: The json is a tree of `Assoc objects as seen in the example log line. Duplicates keys will have the latest seen value*)
  let rec json_flat_map ~key (json : Yojson.Safe.t)
      (map : Yojson.Safe.t String.Map.t) =
    match json with
    | `String _ | `Int _ | `Null | `Bool _ | `Float _ | `Intlit _ ->
        Ok (Map.update map key ~f:(fun _ -> json))
    | `Assoc assoc_list ->
        List.fold_until assoc_list ~init:(Ok map)
          ~f:(fun acc (key, json) ->
            match acc with
            | Error e ->
                Stop (Error e)
            | Ok acc ->
                Continue (json_flat_map ~key json acc) )
          ~finish:Fn.id
    | `List lst ->
        (*TODO: expand this if needed*)
        Ok (Map.update map key ~f:(fun _ -> `List lst))
    | _ ->
        Error
          (Error.of_string
             (sprintf "Invalid json object %s" (Yojson.Safe.to_string json)))

  type t = {block_height: int; epoch: int; global_slot: int}

  (*
{"insertId":"8blazmpgqb2usa3ik",
 "jsonPayload":
    {"level":"Trace","message":"Successfully produced a new block: $breadcrumb", "metadata":
        {"breadcrumb":
            {"just_emitted_a_proof":false,
             "staged_ledger":"<opaque>",
             "validated_transition":
                {"data":
                    {"current_protocol_version":"0.1.0",
                     "delta_transition_chain_proof":"<opaque>",
                     "proposed_protocol_version":"<None>",
                     "protocol_state":
                        {"body":
                            {"blockchain_state":    
                                {"snarked_ledger_hash":"4mKBT3x3GiDcYTsjkQttqmdZNyY39Xm7ioVCS6JAgMqVvoDXmroyt9sgDWDavNV5p4yoi4K8WzWR4FDxXUSHHb3n2VWHs75fQKnBU72krVMPvQ2Fmw36wiJAiBSsBJqgb8ogWn64JhvbVwhk66U9YiSusfeMVMoWWhgFFp5UqKQmsu1jEspCfGpQaN1JT6T68pKcioNRs9JWY2HZ7DkN18AeiyC6i6V6eX37YUy6ctGTHFj9yT7KFMTJRjBdDVc3RbAzjpsQgy3q4hjPKm5yuM6F86pLYtFNT8ts7X2h95SUSJchck9YhtsgikYVH6pKs5",
                                "staged_ledger_hash":
                                    {"non_snark":   
                                        {"aux_hash":"UHisJuuSRjBAJvdtNEnXajfBKPxUvxU6ShjpMMpZSRyRwJXqH9",
                                        "ledger_hash":"4mKBT3x6KrR4FBtziNTLF49pbjhzFAYjARZoJzL2R1hgG8xBcPg6pBLb7ryrexXersh1mUkbayhvL4nZ9y5FgNgxPNweGuzav3DahkQChXexsyG56Q5755UhpFbzb57R4m7hsLZHyEJpUmBUN5XM8hrVYYtaCoNei127oavjCVKpdgSsPHyFc4rrRuLQXtYzjrXGBhFZEtJniP2mMSHkTVBiaszJYZ8GGw8v1xrGnWW8FipEDDoJj9VAgKwcTvAauKun4PsGqLMJPFjsXNLd4pzADferNvr5q2LdZdMwxAxWitJbtfKmhDkqej5VuTW82v",
                                        "pending_coinbase_aux":"WewbKnjz78S5g6GMgtv5AkaR54HuGAfAX7YHkoMxzZji8dDm82"},"pending_coinbase_hash":"A2UdxEstp1EeKLQwd7DERaAQN9RyJsy2Z8Q3WBh7omHYzDZmh4AkfHz2W9uAMnDBKJkNNJ4uYqRnT5prhxdCkcAVxj1ZSqwThhpAygwwNFBGYbkLbxh3eLx9rg9GNFqH8GP1LiMojbmtXbRtzCjEo2gUBVXqJSNwcmsg77sRYmUgHfv1dytMrckXZRZxq7indUttMBsjCZjG9no1syU7ccmh8CCgwzUFsPkmfjAEPxeUvRqM18KLm3UYYJKmxub2EFV44h32yGmybVedM7AfuxKrYit6fZqqTQnGWSQdQvNeaxbsgDQRaw8vKy2WaPcR9Y"},
                                "timestamp":"1593038880000"},
                            "consensus_state":
                                {"blockchain_length":"1870",
                                 "curr_global_slot":
                                    {"slot_number":"7746","slots_per_epoch":"480"},
                                 "epoch_count":"16",
                                 "has_ancestor_in_same_checkpoint_window":true,
                                 "last_vrf_output":"<opaque>",
                                 "min_window_density":"160",
                                 "next_epoch_data":
                                    {"epoch_length":"12",
                                     "ledger":
                                        {"hash":"4mKBT3x3GiDcYTsjkQttqmdZNyY39Xm7ioVCS6JAgMqVvoDXmroyt9sgDWDavNV5p4yoi4K8WzWR4FDxXUSHHb3n2VWHs75fQKnBU72krVMPvQ2Fmw36wiJAiBSsBJqgb8ogWn64JhvbVwhk66U9YiSusfeMVMoWWhgFFp5UqKQmsu1jEspCfGpQaN1JT6T68pKcioNRs9JWY2HZ7DkN18AeiyC6i6V6eX37YUy6ctGTHFj9yT7KFMTJRjBdDVc3RbAzjpsQgy3q4hjPKm5yuM6F86pLYtFNT8ts7X2h95SUSJchck9YhtsgikYVH6pKs5",
                                        "total_currency":"22694300002389927"},
                                        "lock_checkpoint":"3j7Fqw9d9wLyNdjTPBSVH3yPDPWMtqUC22L1JSeqnpYMBfHTK7UmtDbYbnCL9mYDccjspNy8vJEnmXMA72qgswFdMocqYWprdWRYCUmhZx2jBKQcjXMjyUm8yFFBU8HfbSHSWfWmFVEXLw15rTR5ELjFy5xQMpgaWWMELu4ArxRc4DBbDebX2ezU4AhXULwsRhgbXw3n8gf6Tfi8GFTMQ8aTfuwmGeLmDAzXY4UvaEFuzcZ4ZFrFHrLZhKXYTbYyKebTBbcYqZScQcBNp1CC76tMP6NJkAaANYMGnRC1atoBwxBx6iCAb8osx12mCYgi9",
                                        "seed":"3DUfsm6DRo8H9B9evJWxP72s18BAmWbFPMjr1EphFQFF7Fjjas1H8Y3UHGLTCocUKga4Yzh9izSHTvPn7UXN8x87c6soskzRtxjzatt2nPVK7jJ3xB2jMQFKfkmXLh4baiuQkDogz8nzirjbrUDnPsGi85efffcdEdCfV9AazPpZSbJKdvxMY4KZYXmdmtASzyQxeDhfpfCgfuUwfKCdPWi2biXxTrX9GkKLVcJFVCgY1ZggSFGiMn6kB3zxtKqUEJ1KvXnfdsyLsRrQwDKGGfqGSaS2b5baosyBnML27GJUGUDhP7vNipc5EVu1BZUEL",
                                        "start_checkpoint":"D2rcXVQYai5JsZ4jvdbKYrN91pgcdB5M8dgRqrq5ZQqZs4QBZEfFouryedSLCMyXLHJkz4mLyZm7Q17yj6258a3fGMD6BuC7VviLGcDJA8BjXvpc9jyQ1JssbbLCF3kroYFduktekUhi2FkxCDZA4gsuXP56msQYwYwsCoKRoUr3HWHs2hdsYytLV2vTg695RbtTGeGVWKk4ihRM78JVypL2iWN2L6ghWpydfBVieqY7Kf6MVWvG7EHpf1Wpg3P1L67wkakWX8BAq9FXJVRd3uTkQM4RffsUuvhtTDDXXhaoAXjGeP669RGgwuUivKUkz4"},
                                        "staking_epoch_data":   
                                            {"epoch_length":"30",
                                             "ledger":   
                                                {"hash":"4mKBT3x3GiDcYTsjkQttqmdZNyY39Xm7ioVCS6JAgMqVvoDXmroyt9sgDWDavNV5p4yoi4K8WzWR4FDxXUSHHb3n2VWHs75fQKnBU72krVMPvQ2Fmw36wiJAiBSsBJqgb8ogWn64JhvbVwhk66U9YiSusfeMVMoWWhgFFp5UqKQmsu1jEspCfGpQaN1JT6T68pKcioNRs9JWY2HZ7DkN18AeiyC6i6V6eX37YUy6ctGTHFj9yT7KFMTJRjBdDVc3RbAzjpsQgy3q4hjPKm5yuM6F86pLYtFNT8ts7X2h95SUSJchck9YhtsgikYVH6pKs5",
                                                "total_currency":"22694300002389927"},
                                             "lock_checkpoint":"D2rcXVQa7xzkV8oPav5NMR2mmSbGDzzi4Cdz9UbjqvYA5Wb515gWEWWEvZbFQqS5tvig9BrfhaVwCiCd3tX3d1Jv3AmH1ijFtcu3DEp5gc6n2Kktx35sX9ZyKV4nhzuxh5DouzUeaULFV8yZ6AbQSF9FZExZ6HFUMPCA81QtzLwT1ZCsUYSyS4p5oJ6HYusYPawjBfCUf8QAx3AozWKBs98nTmBQUQCSgdZkjGkMB6pxcQqG11gnNPCCFDWYTsn2LYKz69Z1vGNL3g8kcTY4yBpxAejewwR5a4vu9qvKo8MokVDGGxhBmAEWptmF9jxpMW",
                                             "seed":"3DUfsm6E7rP2B1dzUTDBa7oqdLPm48NPTZxzupoFjCAX8nfpBSbGfpWr7uHhcgpwHDnVjzfstD1Srzi3coatywp1vFwXMkPQ6ZkkD3WVMWxrRiXfyUt3q33RXnN6sPCw1RoBFDyp9R5vemXcvZ7jCHqCqx2kuZTJFVzgZjBPhFTNpWJnnX2o4yMSKVYhduRi7M3zVZ5LPyYo3WhngEvdFFnQwpUUaFN2PrsKru7Kp6UEz4qRpDV3LBoLuid8p88Qyk3EiRcHsq9D6zspSAA7MvFhjB7j85FUPcrBHNUBeshujzPcoMWJD5aiQY2UyYP1c",
                                             "start_checkpoint":"D2rcXVQa6wLcxA31rbiCfMuA7kPpem4bb3jopQyE8EAKKCQVA7Pt6oP8VznuhebhUq2ebh2WdP75wynUHje5yjpzdmmdWa5FaTUdHtWz7SkLmAHt87CxCjGNHo6EjWQzv71fSq9ebgkfoBWW9yJPndoD7UggNR2KYZDNhGPwTggoNdcgiLnmZ5kYF9PEn8eaCx7Barv9K3rWjWDUJocySfeJfdLUeAPsNxYcRzFGaPE86MXB1aqExNb2rJUxyTJbx2zfzuQb746ENfAmfkSdSpSY8Ke1FFs8Ebx7A7tTSbB9Wy13yfuuhL1HRnf2UHhu1L"},
                                        "sub_window_densities":["0","20","20","20","20","20","20","20"],
                                        "total_currency":"22694300.002389927"},
                            "constants":
                                {"delta":"3",
                                 "genesis_state_timestamp":"1591644600000",
                                 "k":"20"},
                                 "genesis_state_hash":"D2rcXVQa8eS14d6EWdpMVoys5aeqjiwJppFQRrdoZLpbsDUoq1a9AVYb1VQtqxPhxT87sQWHWwL7c1z7qWmC72GdedUy7RaqanKpJzCk5B4fMnxDTKFDVc53gZF3Z95pMauhWi12vAvuCK5bstGcAh3ZUJveK6RVmnN6aM2tHjTgcp1uvMfzXTjwBuxX6gGpsFKWZw5gDguQpDqhbMiYJw44Mc2ggKthUnfP2NsxJTkNzfJGknYaarK7wRZNEjHeNtrVfyxZDKyTGg6ZisfPemCYPTyXsvs9MmfmAtNhBAAUFuA1NuxnpfAjbdJ3RacHPW"},"previous_state_hash":"D2rcXVQd7LYsuiTTVhhxhw6naMDWGduxFPa7i1TTcsxzX6fFeQeYUbbnE5WJQQdPWJQTB2HwTFWj6MdMi7LiiNQMbnehsx1197WHin8ZYRrgppJVLCEPUQ9gMw4GGphMLYoH4trpd7GLt4dye3Yr2RQVkiq1LAgADfBTbGSF5yKnos4Dv4ZyNwVQbU4KebsjUQkuPyt18jJgFN7X2mCXUHJuYFTmc2pMoCLsyrqsZaaks9kog6YmUDops2Ag91f4CezppMUpPbuckwcsHc6WTk82Eo1qGfn88CdhnK8PdWrkw6eP2w9PjYKon4wg4SjbJu"},
                        "protocol_state_proof":"<opaque>",
                        "staged_ledger_diff":"<opaque>"},
                    "hash":"D2rcXVQYbPbBERbK3Ak5FtDVz77pe95Wei3814txvVgzejFn9JegrDFkv8h3JEKytabDQuJys9533w8RjUaBhGeETL4nSBt4SpJSdS4zDicj4bLVcUW3Gr5ef7mttXpuYiuBB4nTq3pphiU3DDJnuSEustZBpExRd6Bs67SovSd1C4nSwms9HuMB64VXCF7d3ZKHhHDJh4iBNFwUVabT8CnBZVxYsVMiXkvpSLFuvDF1ark1NvvN64box6s4pzdsnskyMyz8Y4s78jzH9MP5oUmBEHRmRwg88mVLGJNYotvo4g2PmRpz2WFXFXXUyqzwfo"}},"host":"35.196.202.161",
                    "peer_id":"12D3KooWF44GaTczmyEhWbv3p4onjfp3DDC2fJGckhaECza1bbr6",
                    "pid":10,
                    "port":10005},
            "source":
                {"location":"File \"src/lib/block_producer/block_producer.ml\", line 512, characters 44-51",
                "module":"Block_producer"},
            "timestamp":"2020-06-24 23:28:47.264783Z"},
    "labels":
        {"k8s-pod/app":"whale-block-producer-5",
         "k8s-pod/class":"whale",
         "k8s-pod/pod-template-hash":"9f8895cb9",
         "k8s-pod/role":"block-producer",
         "k8s-pod/testnet":"joyous-occasion",
         "k8s-pod/version":"0.0.12-beta-feature-bump-genesis-timestamp-3e9b174"}
    ,"logName":"projects/o1labs-192920/logs/stdout",
    "receiveTimestamp":"2020-06-24T23:28:48.891183134Z",
    "resource":
        {"labels":
            {"cluster_name":"coda-infra-east",
             "container_name":"coda",
             "location":"us-east1",
             "namespace_name":"joyous-occasion","pod_name":"whale-block-producer-5-9f8895cb9-59p8h","project_id":"o1labs-192920"},
         "type":"k8s_container"},
    "severity":"INFO",
    "timestamp":"2020-06-24T23:28:47.957899176Z"}
    *)

  let filter testnet_log_filter =
    (*replace most of this with log_filter*)
    String.concat ~sep:" "
      [ testnet_log_filter
      ; "resource.labels.project_id="
      ; project_id
      ; "resource.labels.pod_name:"
      ; "\"block-producer\""
      ; "resource.labels.container_name="
      ; "coda"
      ; "\"successfully produced a\"" ]

  (*TODO: Block Produced*)

  let parse_log log =
    let open Or_error.Let_syntax in
    let%bind json = load_config_json log in
    let%bind json_map = json_flat_map ~key:"" json String.Map.empty in
    let extract_int json =
      Or_error.try_with (fun _ ->
          Yojson.Safe.Util.to_string json |> Int.of_string )
    in
    let%bind block_height =
      Map.find_or_error json_map "blockchain_length" >>= fun h -> extract_int h
    in
    let%bind global_slot =
      Map.find_or_error json_map "slot_number" >>= fun h -> extract_int h
    in
    let%map epoch =
      Map.find_or_error json_map "epoch_count" >>= fun h -> extract_int h
    in
    Some {block_height; global_slot; epoch}

  let parse result =
    let open Or_error.Let_syntax in
    let%bind log_line =
      match String.split_lines result with
      | [] | ["DATA"] ->
          Core.printf !"No log line yet :(\n%!" ;
          Ok None
      | ["DATA"; x] | [x] ->
          Core.printf !"Got log line!\n%s%!" x ;
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

  type t = {testnet_log_filter: string; subscriptions: subscriptions}

  let subscription_list testnet_log_filter : subscriptions Deferred.Or_error.t
      =
    (*create one subscription per query*)
    let open Deferred.Or_error.Let_syntax in
    let%map blocks_produced =
      Subscription.create ~name:"blocks_produced"
        ~filter:(Block_produced_filter.filter testnet_log_filter)
    in
    {blocks_produced}

  let delete_subscriptions subscriptions =
    Subscription.delete subscriptions.blocks_produced

  let create (testnet : Testnet.t) =
    match%map subscription_list "joyous-occasion" with
    | Ok subscriptions ->
        {testnet_log_filter= testnet.testnet_log_filter; subscriptions}
    | Error e ->
        failwith (Error.to_string_hum e)

  let cleanup t =
    match%map delete_subscriptions t.subscriptions with
    | Ok _ ->
        None
    | Error e' ->
        (*TODO: Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__ "Error deleting subscriptions: $error" ~metadata:[("error", `String (Error.to_string_hum e'))];*)
        Some (Error.to_string_hum e')

  let delete t =
    match%map cleanup t with None -> () | Some err_str -> failwith err_str

  let wait_for' :
         blocks:int
      -> epoch_reached:int
      -> timeout:[`Slots of int | `Epochs of int | `Milliseconds of int64]
      -> t
      -> unit Deferred.t =
   fun ~blocks ~epoch_reached ~timeout t ->
    if blocks = 0 && epoch_reached = 0 && timeout = `Milliseconds 0L then
      Deferred.unit
    else
      let timeout_ms =
        let now = Time.now () in
        match timeout with
        | `Milliseconds x ->
            Time.add now (Time.Span.of_ms (Int64.to_float x))
        | _ ->
            (*Don't wait for more than an hour in any case*)
            Time.add now (Time.Span.of_ms (Int64.to_float 3600000L))
      in
      let timed_out (res : Block_produced_filter.t option) =
        match (timeout, res) with
        | `Slots x, Some res' ->
            res'.global_slot >= x
        | `Epochs x, Some res' ->
            res'.epoch >= x
        | _, _ ->
            Time.( > ) (Time.now ()) timeout_ms
      in
      (*TODO: this should be block window duration once the constraint constants are added to runtime config*)
      let block_window_duration =
        Genesis_constants.Constraint_constants.compiled
          .block_window_duration_ms
      in
      let rec go res =
        (*TODO: Error if timedout before the conditions are met?*)
        if timed_out res then Deferred.unit
        else
          let%bind pull_result =
            Subscription.pull t.subscriptions.blocks_produced
          in
          match Block_produced_filter.parse pull_result |> Or_error.ok_exn with
          | None ->
              Async.after
                (Time.Span.of_ms (Int.to_float block_window_duration))
              >>= fun _ -> go None
          | Some res ->
              if res.block_height >= blocks && res.epoch >= epoch_reached then (
                Core.printf !"Condition met]\n%!" ;
                Deferred.unit )
              else go (Some res)
      in
      go None

  let wait_for :
         ?blocks:int
      -> ?epoch_reached:int
      -> ?timeout:[`Slots of int | `Epochs of int | `Milliseconds of int64]
      -> t
      -> unit Deferred.t =
   fun ?(blocks = 0) ?(epoch_reached = 0) ?(timeout = `Milliseconds 300000L) t ->
    match%bind
      Deferred.Or_error.try_with (fun _ ->
          wait_for' ~blocks ~epoch_reached ~timeout t )
    with
    | Ok _ ->
        Deferred.unit
    | Error e -> (
        (*TODO: Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__ "wait_for failed with error: $error" ~metadata:[("error", `String (Error.to_string_hum e))];*)
        match%map cleanup t with
        | None ->
            failwith (Error.to_string_hum e)
        | Some err_str ->
            failwith
              (String.concat ~sep:" and " [Error.to_string_hum e; err_str]) )
end

let%test_module "Log tests" =
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
      let%bind log_engine = create testnet in
      let%bind _ = wait_for ~blocks:2500 log_engine in
      delete log_engine

    let wait_for_slot_timeout () =
      let%bind log_engine = create testnet in
      let%bind _ = wait_for ~timeout:(`Slots 7500) log_engine in
      delete log_engine

    let wait_for_epoch () =
      let%bind log_engine = create testnet in
      let%bind _ = wait_for ~epoch_reached:16 log_engine in
      delete log_engine

    let%test_unit "joyous-occasion - wait_for_block_height" =
      Async.Thread_safe.block_on_async_exn wait_for_block_height

    let%test_unit "joyous-occasion - wait_for_slot_timeout" =
      Async.Thread_safe.block_on_async_exn wait_for_slot_timeout

    let%test_unit "joyous-occasion - wait_for_epoch" =
      Async.Thread_safe.block_on_async_exn wait_for_epoch
  end )
