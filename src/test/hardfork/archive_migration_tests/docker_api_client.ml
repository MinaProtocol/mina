open Core
open Integration_test_lib
open Async

module DokerApiClient = struct
  type t = { version : string; curl_app : string }

  let default = { version = "v1.40"; curl_app = "curl" }

  let post t ?(json = None) ~path =
    let post_data =
      match json with
      | Some json ->
          [ "-H"; "Content-Type: application/json"; "-d"; json ]
      | None ->
          []
    in
    Util.run_cmd_exn "." t.curl_app
      ( [ "--unix-socket"; "/var/run/docker.sock" ]
      @ post_data
      @ [ "-X"; "POST"; Printf.sprintf "http://localhost/%s/%s" t.version path ]
      )

  let get t ~path =
    Util.run_cmd_exn "." t.curl_app
      [ "--unix-socket"
      ; "/var/run/docker.sock"
      ; Printf.sprintf "http://localhost/%s/%s" t.version path
      ]

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
    Core_kernel.Printf.printf "%s" json ;
    let%bind output = post t ~json:(Some json) ~path:"containers/create" in
    Core_kernel.Printf.printf "%s" output ;
    Deferred.return
      ( output |> Yojson.Safe.from_string |> create_container_result_of_yojson
      |> Result.ok_or_failwith )

  let connect_container_to t ~id ~network =
    let json = `Assoc [ ("Container", `String id) ] in
    let json = Yojson.to_string json in
    post t ~json:(Some json)
      ~path:(Printf.sprintf "networks/%s/connect" network)
    >>| ignore

  type wait_container_status =
    { status_code : int [@key "StatusCode"]
    ; error : string option [@key "Error"] [@default None]
    }
  [@@deriving yojson]

  let start_container t ~id =
    let open Deferred.Let_syntax in
    post t ~json:None ~path:(Printf.sprintf "containers/%s/start" id) >>| ignore

  let pull_image t ~img =
    let open Deferred.Let_syntax in
    post t ~json:None ~path:(Printf.sprintf "images/create?fromImage=%s" img)
    >>| ignore

  let wait_for_container t ~id =
    let open Deferred.Let_syntax in
    let%bind output =
      post t ~json:None ~path:(Printf.sprintf "containers/%s/wait" id)
    in
    Core_kernel.Printf.printf "%s" output ;
    Deferred.return
      ( output |> Yojson.Safe.from_string |> wait_container_status_of_yojson
      |> Result.ok_or_failwith )

  let container_logs t ~id =
    get t ~path:(Printf.sprintf "containers/%s/logs?stdout=true" id)

  let run_cmd_in_image t ~image ~cmd ~workdir ~volume ~network =
    let open Deferred.Let_syntax in
    let%bind _ = pull_image t ~img:image in
    let%bind result =
      create_container t ~image ~cmd ~workdir ~volume ~network
    in
    let%bind _ = start_container t ~id:result.id in
    let%bind _ = wait_for_container t ~id:result.id in
    let%bind _ = container_logs t ~id:result.id in
    Deferred.unit
end
