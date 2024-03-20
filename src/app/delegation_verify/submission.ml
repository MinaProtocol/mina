open Async
open Core
open Signature_lib

let decode_snark_work str =
  match Base64.decode str with
  | Ok str -> (
      try Ok (Binable.of_string (module Uptime_service.Proof_data) str)
      with _ -> Error (Error.of_string "Fail to decode snark work") )
  | Error _ ->
      Error (Error.of_string "Fail to decode snark work")

module type Data_source = sig
  type t

  type submission

  val submitted_at : submission -> string

  val block_hash : submission -> string

  val snark_work : submission -> Uptime_service.Proof_data.t option Or_error.t

  val submitter : submission -> Public_key.Compressed.t

  val load_submissions : t -> submission list Deferred.Or_error.t

  val load_block : submission -> t -> string Deferred.Or_error.t

  val verify_blockchain_snarks :
       (Mina_wire_types.Mina_state_protocol_state.Value.V2.t * Mina_base.Proof.t)
       list
    -> unit Async_kernel__Deferred_or_error.t

  val verify_transaction_snarks :
       (Ledger_proof.t * Mina_base.Sok_message.t) list
    -> (unit, Error.t) Deferred.Result.t

  val output :
    t -> submission -> Output.t Or_error.t -> unit Deferred.Or_error.t
end

module Filesystem = struct
  type t = { block_dir : string; submission_paths : string list }

  type submission =
    { created_at : string
    ; peer_id : string
    ; snark_work : string option [@default None]
    ; remote_addr : string
    ; submitter : string
    ; block_hash : string
    ; graphql_control_port : int option [@default None]
    }
  [@@deriving yojson]

  let submitted_at ({ created_at; _ } : submission) = created_at

  let block_hash ({ block_hash; _ } : submission) = block_hash

  let snark_work ({ snark_work; _ } : submission) =
    match snark_work with
    | None ->
        Ok None
    | Some s ->
        let open Result.Let_syntax in
        let%map snark_work = decode_snark_work s in
        Some snark_work

  let submitter ({ submitter; _ } : submission) =
    Public_key.Compressed.of_base58_check_exn submitter

  let load_submissions { submission_paths; _ } =
    Deferred.create (fun ivar ->
        List.fold_right submission_paths ~init:(Ok []) ~f:(fun filename acc ->
            let open Result.Let_syntax in
            let%bind acc = acc in
            let%bind contents =
              try Ok (In_channel.read_all filename)
              with _ -> Error (Error.of_string "Fail to load metadata")
            in
            let%map t =
              match
                Yojson.Safe.from_string contents |> submission_of_yojson
              with
              | Ppx_deriving_yojson_runtime.Result.Ok a ->
                  Ok a
              | Ppx_deriving_yojson_runtime.Result.Error e ->
                  Error (Error.of_string e)
            in
            t :: acc )
        |> Ivar.fill ivar )

  let load_block (submission : submission) { block_dir; _ } =
    Deferred.create (fun ivar ->
        let block_path =
          Printf.sprintf "%s/%s.dat" block_dir submission.block_hash
        in
        ( try Ok (In_channel.read_all block_path)
          with _ -> Error (Error.of_string "Fail to load block") )
        |> Ivar.fill ivar )

  let output _ (_submission : submission) = function
    | Ok payload ->
        Output.display payload ;
        Deferred.Or_error.return ()
    | Error e ->
        Output.display_error @@ Error.to_string_hum e ;
        Deferred.Or_error.return ()
end

module Cassandra = struct
  type t = { conf : Cassandra.conf; period_start : string; period_end : string }

  type block_data = { raw_block : string } [@@deriving yojson]

  type submission =
    { created_at : string
    ; peer_id : string
    ; snark_work : string option [@default None]
    ; remote_addr : string
    ; submitter : string
    ; block_hash : string
    ; graphql_control_port : int option [@default None]
    ; submitted_at : string
    ; submitted_at_date : string
    ; raw_block : string option [@default None]
    }
  [@@deriving yojson]

  let submitted_at ({ submitted_at; _ } : submission) = submitted_at

  let block_hash ({ block_hash; _ } : submission) = block_hash

  let snark_work ({ snark_work; _ } : submission) =
    match snark_work with
    | None ->
        Ok None
    | Some s ->
        let base64 =
          String.chop_prefix_exn s ~prefix:"0x"
          |> Hex.Safe.of_hex |> Option.value_exn |> Base64.encode_string
        in
        Result.map (decode_snark_work base64) ~f:Option.some

  let submitter ({ submitter; _ } : submission) =
    Public_key.Compressed.of_base58_check_exn submitter

  let zone = Lazy.force Time.Zone.local

  let shard t =
      let parts = Time.to_ofday t ~zone |> Time.Ofday.to_parts in
      (parts.hr * 3600 + parts.min * 60 + parts.sec) / 144

  let shards_range start_time end_time =
    if Time.Span.(Time.diff end_time start_time > of_day 1.0) then
      List.range ~stop:`inclusive 0 599
    else
      let first_shard = shard start_time in
      let last_shard = shard end_time in
      if first_shard > last_shard then
        (List.range ~stop:`inclusive first_shard 599)
        @ (List.range ~stop:`inclusive 0 last_shard)
      else
      List.range ~stop:`inclusive first_shard last_shard
  
  let comma_sep ~to_str l =
    List.map ~f:to_str l |> String.concat ~sep:", "

  let load_submissions { conf; period_start; period_end } =
    let start_time = Time.of_string period_start in
    let end_time = Time.of_string period_end in
    let start_day = Time.to_date ~zone start_time in
    let end_day = Time.to_date ~zone end_time in
    let partition_keys =
      Date.dates_between ~min:start_day ~max:end_day
      |> List.map ~f:(fun d -> Date.format d "%Y-%m-%d")
    in
    let shards = shards_range start_time end_time in
    let partition =
      if List.length partition_keys = 1 then
        sprintf "submitted_at_date = '%s' and shard in (%s)"
          (List.hd_exn partition_keys)
          (comma_sep ~to_str:Int.to_string shards)
      else
        sprintf "submitted_at_date IN (%s) and shard in (%s)"
          (comma_sep ~to_str:(sprintf "'%s'") partition_keys)
          (comma_sep ~to_str:Int.to_string shards)
    in
    Cassandra.select ~conf ~parse:submission_of_yojson
      ~fields:
        [ "created_at"
        ; "submitted_at_date"
        ; "submitted_at"
        ; "peer_id"
        ; "snark_work"
        ; "remote_addr"
        ; "submitter"
        ; "block_hash"
        ; "graphql_control_port"
        ; "raw_block"
        ]
      ~where:
        (sprintf "%s AND submitted_at >= '%s' AND submitted_at < '%s'" partition
           period_start period_end )
      "submissions"

  let load_from_s3 ~block_hash =
    let aws_cli = Option.value ~default:"/bin/aws" @@ Sys.getenv "AWS_CLI" in
    let s3_path =
      let open Or_error.Let_syntax in
      let%bind bucket =
        Or_error.try_with (fun () -> Sys.getenv_exn "AWS_S3_BUCKET")
      in
      let%map network =
        Or_error.try_with (fun () -> Sys.getenv_exn "NETWORK_NAME")
      in
      sprintf "s3://%s/%s/blocks/%s.dat" bucket network block_hash
    in
    Deferred.Or_error.bind (return s3_path) ~f:(fun s3_path ->
        Process.run ~prog:aws_cli ~args:[ "s3"; "cp"; s3_path; "-" ] () )

  let load_block (submission : submission) _ =
    let open Deferred.Or_error.Let_syntax in
    match submission.raw_block with
    | None ->
        (* If not found in Submission, try loading from S3 *)
        load_from_s3 ~block_hash:submission.block_hash
    | Some b ->
        String.chop_prefix_exn b ~prefix:"0x"
        |> Hex.Safe.of_hex |> Option.value_exn |> return

  let output { conf; _ } (submission : submission) = function
    | Ok payload ->
        Output.display payload ;
        Cassandra.update ~conf ~table:"submissions"
          ~where:
            (sprintf
               "submitted_at_date = '%s' and shard = %d and submitted_at = '%s' and submitter \
                = '%s'"
               (List.hd_exn @@ String.split ~on:' ' submission.submitted_at)
               (shard @@ Time.of_string submission.submitted_at)
               submission.submitted_at submission.submitter )
          Output.(valid_payload_to_cassandra_updates payload)
    | Error e ->
        Output.display_error @@ Error.to_string_hum e ;
        Cassandra.update ~conf ~table:"submissions"
          ~where:
            (sprintf
               "submitted_at_date = '%s' and shard = %d and submitted_at = '%s' and submitter \
                = '%s'"
               (List.hd_exn @@ String.split ~on:' ' submission.submitted_at)
               (shard @@ Time.of_string submission.submitted_at)
               submission.submitted_at submission.submitter )
          [ ("validation_error", sprintf "'%s'" (Error.to_string_hum e))
          ; ("raw_block", "NULL")
          ; ("snark_work", "NULL")
          ; ("verified", "true")
          ]
end

module Stdin = struct
  type t = unit

  (* The input contains irrelevant data, which we accept and return back unchanged
     for convenience. Therefore rather than parse it into a structure, we just
     extract relevant data, attach our output to the input and return it back to
     the caller. This also makes us resilient to immaterial changes to the input. *)
  type submission = Yojson.Safe.t

  let submitted_at json =
    Yojson.Safe.Util.(member "submitted_at" json |> to_string)

  let block_hash json = Yojson.Safe.Util.(member "block_hash" json |> to_string)

  let snark_work json =
    match
      Yojson.Safe.Util.(member "snark_work" json |> to_option to_string)
    with
    | None ->
        Ok None
    | Some s ->
        let open Result.Let_syntax in
        let%map prf = decode_snark_work s in
        Some prf

  let submitter json =
    Yojson.Safe.Util.(member "submitter" json |> to_string)
    |> Public_key.Compressed.of_base58_check_exn

  let load_block submission () =
    Yojson.Safe.Util.(member "raw_block" submission |> to_string)
    |> Base64.decode_exn |> Deferred.Or_error.return

  let load_submissions () =
    Yojson.Safe.from_channel In_channel.stdin
    |> Yojson.Safe.Util.to_list |> Deferred.Or_error.return

  (* It is requested that we return the whole input we got back with some extra data
     attached. So here we extract the data from the payload and combine it with the
     submission JSON. *)
  let output () submission output =
    let results =
      match output with
      | Ok (payload : Output.t) ->
          [ ( "state_hash"
            , `String (Mina_base.State_hash.to_base58_check payload.state_hash)
            )
          ; ( "parent"
            , `String (Mina_base.State_hash.to_base58_check payload.parent) )
          ; ("height", `Int (Unsigned.UInt32.to_int payload.height))
          ; ( "slot"
            , `Int (Mina_numbers.Global_slot_since_genesis.to_int payload.slot)
            )
          ; ("verified", `Bool true)
          ; ("validation_error", `Null)
          ]
      | Error e ->
          [ ("state_hash", `Null)
          ; ("parent", `Null)
          ; ("height", `Null)
          ; ("slot", `Null)
          ; ("verified", `Bool true)
          ; ("validation_error", `String (Error.to_string_hum e))
          ]
    in
    Json.json_update results submission
    |> Yojson.Safe.to_channel Out_channel.stdout ;
    Out_channel.newline stdout ;
    Deferred.Or_error.return ()
end
