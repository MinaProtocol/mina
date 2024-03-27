open Core
open Integration_test_lib
open Async
open Printf

module HttpPath = struct
  type t = { host : string; version : string }

  let default = { host = "localhost"; version = "v1.40" }

  let with_base t path =
    String.concat ~sep:"/" [ sprintf "http://%s/%s" t.host t.version; path ]

  let container_create t = with_base t "containers/create"

  let container_start t ~id = with_base t (sprintf "containers/%s/start" id)

  let container_wait t ~id = with_base t (sprintf "containers/%s/wait" id)

  let container_logs t ~id =
    with_base t (sprintf "containers/%s/logs?stdout=true" id)

  let network_connect t ~network =
    with_base t (sprintf "networks/%s/connect" network)

  let image_create t ~img =
    with_base t (sprintf "images/create?fromImage=%s" img)
end

module Requests = struct
  type t = { unix_socket : string; curl_app : string }

  let default = { unix_socket = "/var/run/docker.sock"; curl_app = "curl" }

  let post t ~json ~path =
    Util.run_cmd_exn "." t.curl_app
      [ "--unix-socket"
      ; t.unix_socket
      ; "-H"
      ; "Content-Type: application/json"
      ; "-d"
      ; json
      ; "-X"
      ; "POST"
      ; path
      ]

  let post_no_data t ~path =
    Util.run_cmd_exn "." t.curl_app
      [ "--unix-socket"; t.unix_socket; "-X"; "POST"; path ]

  let get t ~path =
    Util.run_cmd_exn "." t.curl_app
      [ "--unix-socket"; t.unix_socket; Printf.sprintf path ]
end

module Client = struct
  type t = { http_path : HttpPath.t; requests : Requests.t }

  let default = { http_path = HttpPath.default; requests = Requests.default }

  type create_container_result =
    { id : string [@key "Id"]; warnings : string list [@key "Warnings"] }
  [@@deriving yojson]

  let create_container t ~image ~cmd ~workdir ~volume ~network =
    let open Deferred.Let_syntax in
    let json =
      `Assoc
        [ ("Image", `String image)
        ; ("Cmd", `List (List.map cmd ~f:(fun x -> `String x)))
        ; ("WorkingDir", `String workdir)
        ; ( "HostConfig"
          , `Assoc
              [ ("Binds", `List [ `String volume ])
              ; ("NetworkMode", `String network)
              ] )
        ]
    in
    let json = Yojson.to_string json in
    let path = HttpPath.container_create t.http_path in
    let%bind output = Requests.post t.requests ~json ~path in
    Deferred.return
      ( output |> Yojson.Safe.from_string |> create_container_result_of_yojson
      |> Result.ok_or_failwith )

  let connect_container_to t ~id ~network =
    let json = `Assoc [ ("Container", `String id) ] in
    let json = Yojson.to_string json in
    let path = HttpPath.network_connect t.http_path ~network in
    Requests.post t.requests ~json ~path >>| ignore

  type wait_container_status =
    { status_code : int [@key "StatusCode"]
    ; error : string option [@key "Error"] [@default None]
    }
  [@@deriving yojson]

  let start_container t ~id =
    let open Deferred.Let_syntax in
    let path = HttpPath.container_start t.http_path ~id in
    Requests.post_no_data t.requests ~path >>| ignore

  let pull_image t ~img =
    let open Deferred.Let_syntax in
    let path = HttpPath.image_create t.http_path ~img in
    Requests.post_no_data t.requests ~path >>| ignore

  let wait_for_container t ~id =
    let open Deferred.Let_syntax in
    let path = HttpPath.container_wait t.http_path ~id in
    let%bind output = Requests.post_no_data t.requests ~path in
    Deferred.return
      ( output |> Yojson.Safe.from_string |> wait_container_status_of_yojson
      |> Result.ok_or_failwith )

  let container_logs t ~id =
    let path = HttpPath.container_logs t.http_path ~id in
    Requests.post_no_data t.requests ~path

  let run_cmd_in_image t ~image ~cmd ~workdir ~volume ~network =
    let open Deferred.Let_syntax in
    let%bind _ = pull_image t ~img:image in
    let%bind result =
      create_container t ~image ~cmd ~workdir ~volume ~network
    in
    let%bind _ = start_container t ~id:result.id in
    let%bind _ = wait_for_container t ~id:result.id in
    container_logs t ~id:result.id
end
