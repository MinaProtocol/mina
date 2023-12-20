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

  val is_cassandra : t -> bool
  
  val submitted_at : submission -> string

  val block_hash : submission -> string

  val snark_work : submission -> Uptime_service.Proof_data.t option

  val submitter : submission -> Public_key.Compressed.t

  val load_submissions : t -> submission list Deferred.Or_error.t

  val load_block : block_hash:string -> t -> string Deferred.Or_error.t
  
  val load_block_from_submission : submission -> string Deferred.Or_error.t

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
    { submitted_at : string
    ; snark_work : Uptime_service.Proof_data.t option
    ; submitter : Public_key.Compressed.t
    ; block_hash : string
    }

  type raw =
    { submitted_at : string
    ; peer_id : string
    ; snark_work : string option [@default None]
    ; remote_addr : string
    ; submitter : string
    ; block_hash : string
    ; graphql_control_port : int option [@default None]
    }
  [@@deriving yojson]

  let of_raw meta =
    let open Result.Let_syntax in
    let%bind.Result submitter =
      Public_key.Compressed.of_base58_check meta.submitter
    in
    let%map snark_work =
      match meta.snark_work with
      | None ->
          Ok None
      | Some s ->
          let%map snark_work = decode_snark_work s in
          Some snark_work
    in
    { submitter
    ; snark_work
    ; block_hash = meta.block_hash
    ; submitted_at = meta.submitted_at
    }

  let submitted_at ({ submitted_at; _ } : submission) = submitted_at

  let block_hash ({ block_hash; _ } : submission) = block_hash

  let snark_work ({ snark_work; _ } : submission) = snark_work

  let submitter ({ submitter; _ } : submission) = submitter

  let load_submissions { submission_paths; _ } =
    Deferred.create (fun ivar ->
        List.fold_right submission_paths ~init:(Ok []) ~f:(fun filename acc ->
            let open Result.Let_syntax in
            let%bind acc = acc in
            let%bind contents =
              try Ok (In_channel.read_all filename)
              with _ -> Error (Error.of_string "Fail to load metadata")
            in
            let%bind meta =
              match Yojson.Safe.from_string contents |> raw_of_yojson with
              | Ppx_deriving_yojson_runtime.Result.Ok a ->
                  Ok a
              | Ppx_deriving_yojson_runtime.Result.Error e ->
                  Error (Error.of_string e)
            in
            let%map t = of_raw meta in
            t :: acc )
        |> Ivar.fill ivar )

  let load_block ~block_hash { block_dir; _ } =
    Deferred.create (fun ivar ->
        let block_path = Printf.sprintf "%s/%s.dat" block_dir block_hash in
        ( try Ok (In_channel.read_all block_path)
          with _ -> Error (Error.of_string "Fail to load block") )
        |> Ivar.fill ivar )

  (* Dummy impl, not to be used in the context of Filesystem module. 
     It is only intended to fulfill the interface requirements of the 
     Data_source module signature for the Filesystem module *)
  let load_block_from_submission submission =
    let _ = submission in
    Deferred.Or_error.return "dummy block data"

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
    ; snark_work : Uptime_service.Proof_data.t option
    ; submitter : Public_key.Compressed.t
    ; block_hash : string
    ; submitted_at : string
    ; submitted_at_date : string
    ; raw_block : string option [@default None]
    }

  type raw =
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

  let of_raw meta =
    let open Result.Let_syntax in
    let%bind.Result submitter =
      Public_key.Compressed.of_base58_check meta.submitter
    in
    let%map snark_work =
      match meta.snark_work with
      | None ->
          Ok None
      | Some s ->
          let%map snark_work = decode_snark_work s in
          Some snark_work
    in
    ( { submitter
      ; snark_work
      ; block_hash = meta.block_hash
      ; created_at = meta.created_at
      ; submitted_at_date = meta.submitted_at_date
      ; submitted_at = meta.submitted_at
      ; raw_block = meta.raw_block
      }
      : submission )

  let submitted_at ({ submitted_at; _ } : submission) = submitted_at

  let block_hash ({ block_hash; _ } : submission) = block_hash

  let snark_work ({ snark_work; _ } : submission) = snark_work

  let submitter ({ submitter; _ } : submission) = submitter

  let load_submissions { conf; period_start; period_end } =
    let open Deferred.Or_error.Let_syntax in
    let start_day =
      Time.of_string period_start |> Time.to_date ~zone:Time.Zone.utc
    in
    let end_day =
      Time.of_string period_end |> Time.to_date ~zone:Time.Zone.utc
    in
    let partition_keys =
      Date.dates_between ~min:start_day ~max:end_day
      |> List.map ~f:(fun d -> Date.format d "%Y-%m-%d")
    in
    let partition =
      if List.length partition_keys = 1 then
        sprintf "submitted_at_date = '%s'" (List.hd_exn partition_keys)
      else
        sprintf "submitted_at_date IN (%s)"
          (String.concat ~sep:"," @@ List.map ~f:(sprintf "'%s'") partition_keys)
    in
    let%bind raw =
      Cassandra.select ~conf ~parse:raw_of_yojson
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
          (sprintf "%s AND submitted_at >= '%s' AND submitted_at < '%s'"
             partition period_start period_end )
        "submissions"
    in
    List.fold_right raw ~init:(Ok []) ~f:(fun sub acc ->
        let open Result.Let_syntax in
        let%bind l = acc in
        let snark_work =
          Option.map sub.snark_work ~f:(fun s ->
              String.chop_prefix_exn s ~prefix:"0x"
              |> Hex.Safe.of_hex |> Option.value_exn |> Base64.encode_string )
        in
        let%map s = of_raw { sub with snark_work } in
        s :: l )
    |> Deferred.return

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
    
  let load_block_from_submission (submission : submission) =
    let open Deferred.Or_error.Let_syntax in
    match submission.raw_block with
    | None ->
      (* If not found in Submission, try loading from S3 *)
      load_from_s3 ~block_hash:submission.block_hash
    | Some b ->
        String.chop_prefix_exn b ~prefix:"0x"
        |> Hex.Safe.of_hex |> Option.value_exn |> return 

  (* The 'blocks' table is no longer actively used in the Cassandra schema.
     However, 'load_block' is retained for reference purposes and in case of 
     schema rollbacks or data migration needs. *)
  let load_block ~block_hash { conf; _ } =
    let open Deferred.Or_error.Let_syntax in
    let%bind block_data =
      Cassandra.select ~conf ~parse:block_data_of_yojson ~fields:[ "raw_block" ]
        ~where:(sprintf "block_hash = '%s'" block_hash)
        "blocks"
    in
    match List.hd block_data with
    | None ->
        (* If not found in Cassandra, try loading from S3 *)
        load_from_s3 ~block_hash
    | Some b ->
        String.chop_prefix_exn b.raw_block ~prefix:"0x"
        |> Hex.Safe.of_hex |> Option.value_exn |> return

  let output { conf; _ } (submission : submission) = function
    | Ok payload ->
        Output.display payload ;
        Cassandra.update ~conf ~table:"submissions"
          ~where:
            (sprintf
               "submitted_at_date = '%s' and submitted_at = '%s' and submitter \
                = '%s'"
               (List.hd_exn @@ String.split ~on:' ' submission.submitted_at)
               submission.submitted_at
               (Public_key.Compressed.to_base58_check submission.submitter) )
          Output.(valid_payload_to_cassandra_updates payload)
    | Error e ->
        Output.display_error @@ Error.to_string_hum e ;
        Cassandra.update ~conf ~table:"submissions"
          ~where:
            (sprintf
               "submitted_at_date = '%s' and submitted_at = '%s' and submitter \
                = '%s'"
               (List.hd_exn @@ String.split ~on:' ' submission.submitted_at)
               submission.submitted_at
               (Public_key.Compressed.to_base58_check submission.submitter) )
          [ ("validation_error", sprintf "'%s'" (Error.to_string_hum e)) ]
end
