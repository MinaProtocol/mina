open Core
open Async
open Network_peer

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { secret : string; public : string; peer_id : Peer.Id.Stable.V1.t }

    let to_latest = Fn.id
  end
end]

let secret { secret; _ } = secret

let generate_random helper =
  match%map
    Libp2p_helper.do_rpc helper
      (module Libp2p_ipc.Rpcs.GenerateKeypair)
      (Libp2p_ipc.Rpcs.GenerateKeypair.create_request ())
  with
  | Ok response ->
      let open Libp2p_ipc.Reader in
      let keypair =
        Libp2pHelperInterface.GenerateKeypair.Response.result_get response
      in
      let peer_id =
        keypair |> Libp2pKeypair.peer_id_get |> PeerId.id_get
        |> Peer.Id.unsafe_of_string
      in
      let secret = Libp2pKeypair.private_key_get keypair in
      let public = Libp2pKeypair.public_key_get keypair in
      { secret; public; peer_id }
  | Error e ->
      Error.tag e ~tag:"Other RPC error generateKeypair" |> Error.raise

let of_b64_data s =
  match Base64.decode s with
  | Ok result ->
      Ok result
  | Error (`Msg s) ->
      Or_error.error_string ("invalid base64: " ^ s)

let to_b64_data (s : string) = Base64.encode_string ~pad:true s

let to_string ({ secret; public; peer_id } : t) =
  String.concat ~sep:","
    [ to_b64_data secret; to_b64_data public; Peer.Id.to_string peer_id ]

let of_string s =
  let parse_with_sep sep =
    match String.split s ~on:sep with
    | [ secret_b64; public_b64; peer_id ] ->
        let open Or_error.Let_syntax in
        let%map secret = of_b64_data secret_b64
        and public = of_b64_data public_b64 in
        ({ secret; public; peer_id = Peer.Id.unsafe_of_string peer_id } : t)
    | _ ->
        Or_error.errorf "%s is not a valid Keypair.to_string output" s
  in
  let with_semicolon = parse_with_sep ';' in
  let with_comma = parse_with_sep ',' in
  if Or_error.is_error with_semicolon then with_comma else with_semicolon

let to_peer_id ({ peer_id; _ } : t) = peer_id
