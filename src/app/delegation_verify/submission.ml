open Core
open Signature_lib

  type block_error =
    [ `Fail_to_load_block
    | `Fail_to_decode_block
    ]

module type S = sig
  type t

  val snark_work : t -> Uptime_service.Proof_data.t option

  val submitter : t -> Public_key.Compressed.t

  val block_hash : t -> string

  val block : t -> (Mina_block.t, block_error) Result.t
end


module JSON = struct

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

  type t =
    { snark_work : Uptime_service.Proof_data.t option
    ; submitter : Public_key.Compressed.t
    ; block_hash : string
    ; block_dir : string
    }

  let snark_work { snark_work; _ } = snark_work
  let submitter { submitter; _ } = submitter
  let block_hash { block_hash; _ } = block_hash

  let block { block_dir; block_hash; _ } =
    let open Result.Let_syntax in
    let block_path = Printf.sprintf "%s/%s.dat" block_dir block_hash in
    let%bind contents =
      try Ok (In_channel.read_all block_path) with
        _ -> Error `Fail_to_load_block
    in
    try Ok (Binable.of_string (module Mina_block.Stable.Latest) contents)
    with _ -> Error `Fail_to_decode_block

  let decode_snark_work str =
    match Base64.decode str with
    | Ok str -> (
      try Ok (Binable.of_string (module Uptime_service.Proof_data) str)
      with _ -> Error `Fail_to_decode_snark_work )
    | Error _ ->
       Error `Fail_to_decode_snark_work

  let load ~block_dir filename =
    let open Result.Let_syntax in
    let%bind contents =
      try Ok (In_channel.read_all filename) with _ -> Error `Fail_to_load_metadata
    in
    let%bind meta =
      match Yojson.Safe.from_string contents |> raw_of_yojson with
      | Ppx_deriving_yojson_runtime.Result.Ok a ->
         Ok a
      | Ppx_deriving_yojson_runtime.Result.Error e ->
         Error (`Fail_to_decode_metadata e)
    in
    let%bind.Result submitter =
      Result.map_error ~f:(fun e ->
          `Fail_to_decode_metadata (Error.to_string_hum e) )
      @@ Public_key.Compressed.of_base58_check meta.submitter
    in
    let%map snark_work =
        match meta.snark_work with
        | None -> Ok None
        | Some s ->
             let%map snark_work = decode_snark_work s in
             Some snark_work
    in
    { submitter; snark_work; block_hash = meta.block_hash; block_dir }
end
