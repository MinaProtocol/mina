open Async
open Core
open Signature_lib

type t =
  { snark_work : Uptime_service.Proof_data.t option
  ; submitter : Public_key.Compressed.t
  ; block_hash : string
  }

type submission = t

type raw =
  { created_at : string
  ; peer_id : string
  ; snark_work : string option [@default None]
  ; remote_addr : string
  ; submitter : string
  ; block_hash : string
  ; graphql_control_port : int option [@default None]
  }
[@@deriving yojson]

module type Data_source = sig
  type t

  val load_submissions : t -> submission list Deferred.Or_error.t

  val load_block : block_hash:string -> t -> string Deferred.Or_error.t

  val verify_blockchain_snarks :
       (Mina_wire_types.Mina_state_protocol_state.Value.V2.t * Mina_base.Proof.t)
       list
    -> unit Async_kernel__Deferred_or_error.t

  val verify_transaction_snarks :
       (Ledger_proof.t * Mina_base.Sok_message.t) list
    -> (unit, Error.t) Deferred.Result.t
end

module Filesystem = struct
  type t = { block_dir : string; submission_paths : string list }

  let decode_snark_work str =
    match Base64.decode str with
    | Ok str -> (
        try Ok (Binable.of_string (module Uptime_service.Proof_data) str)
        with _ -> Error (Error.of_string "Fail to decode snark work") )
    | Error _ ->
        Error (Error.of_string "Fail to decode snark work")

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
            { submitter; snark_work; block_hash = meta.block_hash } :: acc )
        |> Ivar.fill ivar )

  let load_block ~block_hash { block_dir; _ } =
    Deferred.create (fun ivar ->
        let block_path = Printf.sprintf "%s/%s.dat" block_dir block_hash in
        ( try Ok (In_channel.read_all block_path)
          with _ -> Error (Error.of_string "Fail to load block") )
        |> Ivar.fill ivar )
end
